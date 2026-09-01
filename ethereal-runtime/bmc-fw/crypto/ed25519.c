/* SPDX-License-Identifier: MIT */
/*
 * ed25519.c — Ed25519 signature verification (RFC 8032 §5.1.7), verify-only.
 *
 * In-house implementation from the spec. Freestanding C99: no libc, no dynamic
 * memory (G1). NOT constant-time (verify is public-input on the BMC); the goal
 * is simplicity + provable correctness against KATs / PyCA cross-vectors.
 *
 * Field GF(2^255-19): 8 x 32-bit limbs, canonical (< p) after every op.
 * Points: extended twisted-Edwards coordinates (X:Y:Z:T), complete formulas.
 * Checks enforced: canonical field encodings (y < p), S < L, small-order A
 * rejected via [8]A == identity, decode failures rejected.
 *
 * Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md (E1-RUN2 daemon
 *           verify path); ethereal-tools/tools/ethimg.py §signature.
 */
#include "ed25519.h"
#include "sha512.h"
/* Optional op-counter for footprint estimation (host profiling builds only;
 * zero cost in normal builds). */
#ifdef ETH_ED25519_PROFILE
unsigned long eth_prof_fe_mul_calls;
#define PROF_FE_MUL() (eth_prof_fe_mul_calls++)
#else
#define PROF_FE_MUL() ((void)0)
#endif

/* ------------------------------------------------------------------ */
/* tiny byte helpers (no libc)                                        */
/* ------------------------------------------------------------------ */

/* ------------------------------------------------------------------ */
/* GF(2^255-19) — 8 x 32-bit little-endian limbs, always < p          */
/* ------------------------------------------------------------------ */

typedef struct {
    uint32_t v[8];
} fe;

/* p = 2^255 - 19 */
static const fe FE_P = { { 0xffffffedu, 0xffffffffu, 0xffffffffu, 0xffffffffu,
                           0xffffffffu, 0xffffffffu, 0xffffffffu, 0x7fffffffu } };

/* d = -121665/121666 mod p */
static const fe FE_D = { { 0x135978a3u, 0x75eb4dcau, 0x4141d8abu, 0x00700a4du,
                           0x7779e898u, 0x8cc74079u, 0x2b6ffe73u, 0x52036ceeu } };

/* sqrt(-1) = 2^((p-1)/4) mod p */
static const fe FE_SQRTM1 = { { 0x4a0ea0b0u, 0xc4ee1b27u, 0xad2fe478u, 0x2f431806u,
                                0x3dfbd7a7u, 0x2b4d0099u, 0x4fc1df0bu, 0x2b832480u } };

/* (p-5)/8 = 2^252 - 3, exponent for the sqrt-ratio trick */
static const uint32_t PM5D8[8] = { 0xfffffffdu, 0xffffffffu, 0xffffffffu, 0xffffffffu,
                                   0xffffffffu, 0xffffffffu, 0xffffffffu, 0x0fffffffu };

/* group order L = 2^252 + 27742317777372353535851937790883648493 */
static const uint32_t SCALAR_L[8] = { 0x5cf5d3edu, 0x5812631au, 0xa2f79cd6u, 0x14def9deu,
                                      0x00000000u, 0x00000000u, 0x00000000u, 0x10000000u };

static void fe_zero(fe *r)
{
    for (int i = 0; i < 8; i++) {
        r->v[i] = 0;
    }
}

static void fe_one(fe *r)
{
    fe_zero(r);
    r->v[0] = 1;
}

static void fe_copy(fe *r, const fe *a)
{
    for (int i = 0; i < 8; i++) {
        r->v[i] = a->v[i];
    }
}

/* compare 8 limbs against constant: -1 a<b, 0 eq, 1 a>b */
static int fe_cmp(const fe *a, const fe *b)
{
    for (int i = 7; i >= 0; i--) {
        if (a->v[i] < b->v[i]) {
            return -1;
        }
        if (a->v[i] > b->v[i]) {
            return 1;
        }
    }
    return 0;
}

static int fe_eq(const fe *a, const fe *b) { return fe_cmp(a, b) == 0; }

static int fe_iszero(const fe *a)
{
    uint32_t x = 0;
    for (int i = 0; i < 8; i++) {
        x |= a->v[i];
    }
    return x == 0;
}

static int fe_isodd(const fe *a) { return (int)(a->v[0] & 1u); }

/* r = a + b mod p. a,b < p so a+b < 2p: one conditional subtract suffices. */
static void fe_add(fe *r, const fe *a, const fe *b)
{
    uint64_t c = 0;
    for (int i = 0; i < 8; i++) {
        uint64_t s = (uint64_t)a->v[i] + b->v[i] + c;
        r->v[i]   = (uint32_t)s;
        c         = s >> 32;
    }
    /* a+b <= 2p-2 < 2^256: carry out is 0. Conditional subtract p. */
    if (fe_cmp(r, &FE_P) >= 0) {
        uint64_t bw = 0;
        for (int i = 0; i < 8; i++) {
            uint64_t t = (uint64_t)r->v[i] - FE_P.v[i] - bw;
            r->v[i]    = (uint32_t)t;
            bw         = (t >> 32) & 1u;
        }
    }
}

/* r = p - a (or 0 if a == 0). */
static void fe_neg(fe *r, const fe *a)
{
    if (fe_iszero(a)) {
        fe_zero(r);
        return;
    }
    uint64_t bw = 0;
    for (int i = 0; i < 8; i++) {
        uint64_t t = (uint64_t)FE_P.v[i] - a->v[i] - bw;
        r->v[i]    = (uint32_t)t;
        bw         = (t >> 32) & 1u;
    }
}

/* r = a - b mod p = a + (-b). */
static void fe_sub(fe *r, const fe *a, const fe *b)
{
    fe nb;
    fe_neg(&nb, b);
    fe_add(r, a, &nb);
}

/* reduce a 16-limb (512-bit) value mod p; r becomes canonical (< p). */
static void fe_reduce(uint32_t r[16])
{
    /* Fold high half: 2^256 == 38 (mod p), value := lo + 38*hi.
       Each fold strictly decreases the integer when hi > 0, so the loop
       terminates with the high half zero and value < 2^256. */
    for (;;) {
        uint32_t hi_nonzero = 0;
        for (int i = 8; i < 16; i++) {
            hi_nonzero |= r[i];
        }
        if (!hi_nonzero) {
            break;
        }
        uint64_t c = 0;
        for (int i = 0; i < 8; i++) {
            uint64_t s = (uint64_t)r[i] + 38u * (uint64_t)r[i + 8] + c;
            r[i]     = (uint32_t)s;
            r[i + 8] = 0;
            c        = s >> 32;
        }
        r[8] = (uint32_t)c; /* c < 39 */
    }
    /* value < 2^256 < 2.1*p: subtract p while >= p (at most twice) */
    {
        fe tmp;
        for (int i = 0; i < 8; i++) {
            tmp.v[i] = r[i];
        }
        while (fe_cmp(&tmp, &FE_P) >= 0) {
            uint64_t bw = 0;
            for (int i = 0; i < 8; i++) {
                uint64_t t = (uint64_t)tmp.v[i] - FE_P.v[i] - bw;
                tmp.v[i]   = (uint32_t)t;
                bw         = (t >> 32) & 1u;
            }
        }
        for (int i = 0; i < 8; i++) {
            r[i] = tmp.v[i];
        }
    }
}

/* r = a * b mod p (schoolbook 8x8 -> 16, then reduce). */
static void fe_mul(fe *r, const fe *a, const fe *b)
{
    PROF_FE_MUL();
    uint32_t t[16];
    for (int i = 0; i < 16; i++) {
        t[i] = 0;
    }
    for (int i = 0; i < 8; i++) {
        uint64_t c = 0;
        for (int j = 0; j < 8; j++) {
            /* max: (2^32-1)^2 + (2^32-1) + (2^32-1) = 2^64 - 1: fits */
            uint64_t s = (uint64_t)a->v[i] * b->v[j] + t[i + j] + c;
            t[i + j] = (uint32_t)s;
            c        = s >> 32;
        }
        for (int k = i + 8; c != 0 && k < 16; k++) {
            uint64_t s = (uint64_t)t[k] + c;
            t[k] = (uint32_t)s;
            c    = s >> 32;
        }
    }
    fe_reduce(t);
    for (int i = 0; i < 8; i++) {
        r->v[i] = t[i];
    }
}

static void fe_sq(fe *r, const fe *a) { fe_mul(r, a, a); }

/* r = base^exp mod p; exp = 8x32-bit LE limbs, scanned from bit (255..0). */
static void fe_pow(fe *r, const fe *base, const uint32_t exp[8])
{
    fe acc;
    fe_one(&acc);
    for (int i = 255; i >= 0; i--) {
        fe_sq(&acc, &acc);
        if ((exp[i >> 5] >> (i & 31)) & 1u) {
            fe_mul(&acc, &acc, base);
        }
    }
    fe_copy(r, &acc);
}

/* load 32 LE bytes; clears the top bit (used as sign bit elsewhere).
 * Returns 0 if the 255-bit value is non-canonical (>= p). */
static int fe_frombytes(fe *r, const uint8_t in[32])
{
    for (int i = 0; i < 8; i++) {
        r->v[i] = (uint32_t)in[i * 4 + 0] | ((uint32_t)in[i * 4 + 1] << 8) |
                  ((uint32_t)in[i * 4 + 2] << 16) | ((uint32_t)in[i * 4 + 3] << 24);
    }
    r->v[7] &= 0x7fffffffu; /* strip sign bit */
    return fe_cmp(r, &FE_P) < 0;
}

/* ------------------------------------------------------------------ */
/* group: extended twisted-Edwards coords, x=X/Z y=Y/Z T=XY/Z         */
/* ------------------------------------------------------------------ */

typedef struct {
    fe x, y, z, t;
} ge;

/* base point B */
static const ge GE_BASE = {
    { { 0x8f25d51au, 0xc9562d60u, 0x9525a7b2u, 0x692cc760u,
        0xfdd6dc5cu, 0xc0a4e231u, 0xcd6e53feu, 0x216936d3u } },
    { { 0x66666658u, 0x66666666u, 0x66666666u, 0x66666666u,
        0x66666666u, 0x66666666u, 0x66666666u, 0x66666666u } },
    { { 1u, 0u, 0u, 0u, 0u, 0u, 0u, 0u } },
    /* t = x*y mod p = Bx*By */
    { { 0xa5b7dda3u, 0x6dde8ab3u, 0x775152f5u, 0x20f09f80u,
        0x64abe37du, 0x66ea4e8eu, 0xd78b7665u, 0x67875f0fu } },
};

static void ge_identity(ge *r)
{
    fe_zero(&r->x);
    fe_one(&r->y);
    fe_one(&r->z);
    fe_zero(&r->t);
}

/* r = p + q — complete addition formula (a = -1, d non-square). */
static void ge_add(ge *r, const ge *p, const ge *q)
{
    fe a, b, c, d, e, f, g, h, t1, t2;
    fe_sub(&a, &p->y, &p->x);
    fe_sub(&t1, &q->y, &q->x);
    fe_mul(&a, &a, &t1);
    fe_add(&b, &p->y, &p->x);
    fe_add(&t2, &q->y, &q->x);
    fe_mul(&b, &b, &t2);
    fe_mul(&c, &p->t, &q->t);
    fe_mul(&c, &c, &FE_D);
    fe_add(&c, &c, &c);
    fe_mul(&d, &p->z, &q->z);
    fe_add(&d, &d, &d);
    fe_sub(&e, &b, &a);
    fe_sub(&f, &d, &c);
    fe_add(&g, &d, &c);
    fe_add(&h, &b, &a);
    fe_mul(&r->x, &e, &f);
    fe_mul(&r->y, &g, &h);
    fe_mul(&r->t, &e, &h);
    fe_mul(&r->z, &f, &g);
}

/* r = 2*p — doubling formula. */
static void ge_double(ge *r, const ge *p)
{
    fe a, b, c, d, e, f, g, h, t1;
    fe_sq(&a, &p->x);
    fe_sq(&b, &p->y);
    fe_sq(&c, &p->z);
    fe_add(&c, &c, &c);
    fe_neg(&d, &a);
    fe_add(&t1, &p->x, &p->y);
    fe_sq(&e, &t1);
    fe_sub(&e, &e, &a);
    fe_sub(&e, &e, &b);
    fe_add(&g, &d, &b);
    fe_sub(&f, &g, &c);
    fe_sub(&h, &d, &b);
    fe_mul(&r->x, &e, &f);
    fe_mul(&r->y, &g, &h);
    fe_mul(&r->t, &e, &h);
    fe_mul(&r->z, &f, &g);
}

/* r = [s]P; s = 32-byte LE scalar < 2^253 (bits 252..0 scanned). */
static void ge_scalarmult(ge *r, const uint8_t s[32], const ge *p)
{
    ge q;
    ge_identity(&q);
    for (int i = 252; i >= 0; i--) {
        ge_double(&q, &q);
        if ((s[i >> 3] >> (i & 7)) & 1u) {
            ge_add(&q, &q, p);
        }
    }
    fe_copy(&r->x, &q.x);
    fe_copy(&r->y, &q.y);
    fe_copy(&r->z, &q.z);
    fe_copy(&r->t, &q.t);
}

/* projective equality: x1==x2 and y1==y2 via cross-multiplication */
static int ge_equal(const ge *p, const ge *q)
{
    fe a, b;
    fe_mul(&a, &p->x, &q->z);
    fe_mul(&b, &q->x, &p->z);
    if (!fe_eq(&a, &b)) {
        return 0;
    }
    fe_mul(&a, &p->y, &q->z);
    fe_mul(&b, &q->y, &p->z);
    return fe_eq(&a, &b);
}

/* 1 if the point is the identity (0,1) */
static int ge_is_identity(const ge *p)
{
    fe yz;
    if (!fe_iszero(&p->x)) {
        return 0;
    }
    fe_sub(&yz, &p->y, &p->z); /* y == z in projective for y=1 affine */
    return fe_iszero(&yz);
}

/* decode 32 bytes (LE y with x-sign in top bit) -> point.
 * Returns 0 on any decode failure (non-canonical y, no valid x,
 * or x==0 with sign bit set). */
static int ge_decode(ge *r, const uint8_t enc[32])
{
    uint8_t sign = (uint8_t)(enc[31] >> 7);
    fe y, u, v, v3, v7, x, chk, t1;
    if (!fe_frombytes(&y, enc)) {
        return 0;
    }
    /* u = y^2 - 1, v = d*y^2 + 1 */
    fe_sq(&u, &y);
    fe_mul(&v, &u, &FE_D);
    {
        fe one;
        fe_one(&one);
        fe_sub(&u, &u, &one);
        fe_add(&v, &v, &one);
    }
    /* x = (u v^3) (u v^7)^((p-5)/8) */
    fe_sq(&v3, &v);
    fe_mul(&v3, &v3, &v);
    fe_sq(&v7, &v3);
    fe_mul(&v7, &v7, &v);
    fe_mul(&t1, &u, &v7);
    fe_pow(&x, &t1, PM5D8);
    fe_mul(&x, &x, &u);
    fe_mul(&x, &x, &v3);
    /* check v*x^2 == u  (or == -u: fix with sqrtm1) */
    fe_sq(&chk, &x);
    fe_mul(&chk, &chk, &v);
    if (!fe_eq(&chk, &u)) {
        fe t2;
        fe_add(&t2, &chk, &u);
        if (!fe_iszero(&t2)) {
            return 0;
        }
        fe_mul(&x, &x, &FE_SQRTM1);
    }
    if (fe_iszero(&x) && sign != 0) {
        return 0; /* x=0 has no sign */
    }
    if (fe_isodd(&x) != sign) {
        fe_neg(&x, &x);
    }
    fe_copy(&r->x, &x);
    fe_copy(&r->y, &y);
    fe_one(&r->z);
    fe_mul(&r->t, &x, &y);
    return 1;
}

/* ------------------------------------------------------------------ */
/* scalar helpers (mod L)                                             */
/* ------------------------------------------------------------------ */

/* 1 if 32-byte LE scalar >= L */
static int scalar_gte_l(const uint8_t s[32])
{
    for (int i = 31; i >= 0; i--) {
        uint8_t lb = (uint8_t)((SCALAR_L[i >> 2] >> ((i & 3) * 8)) & 0xffu);
        if (s[i] < lb) {
            return 0;
        }
        if (s[i] > lb) {
            return 1;
        }
    }
    return 1; /* equal */
}

/* r = h mod L; h = 64-byte LE (512-bit), reduced by shift-subtract (2*rem+bit, cmp/sub L) per bit. */
static void scalar_reduce(uint8_t r[32], const uint8_t h[64])
{
    uint32_t rem[8];
    for (int i = 0; i < 8; i++) {
        rem[i] = 0;
    }
    for (int i = 511; i >= 0; i--) {
        uint32_t bit = (h[i >> 3] >> (i & 7)) & 1u;
        /* rem = 2*rem + bit  (rem < 2L < 2^254 fits in 8 limbs) */
        uint32_t carry = bit;
        for (int j = 0; j < 8; j++) {
            uint32_t nc = rem[j] >> 31;
            rem[j] = (rem[j] << 1) | carry;
            carry = nc;
        }
        /* if rem >= L: rem -= L */
        int ge = 1;
        for (int j = 7; j >= 0; j--) {
            if (rem[j] < SCALAR_L[j]) { ge = 0; break; }
            if (rem[j] > SCALAR_L[j]) { ge = 1; break; }
        }
        if (ge) {
            uint64_t bw = 0;
            for (int j = 0; j < 8; j++) {
                uint64_t t = (uint64_t)rem[j] - SCALAR_L[j] - bw;
                rem[j] = (uint32_t)t;
                bw     = (t >> 32) & 1u;
            }
        }
    }
    for (int i = 0; i < 32; i++) {
        r[i] = (uint8_t)((rem[i >> 2] >> ((i & 3) * 8)) & 0xffu);
    }
}

/* ------------------------------------------------------------------ */
/* RFC 8032 §5.1.7 verification                                       */
/* ------------------------------------------------------------------ */

int eth_ed25519_verify(const uint8_t sig[64], const uint8_t pk[32],
                       const uint8_t *msg, uint32_t msg_len)
{
    ge a_point, r_point, p1, p2, p3;
    uint8_t k[32];
    uint8_t h[64];

    /* step 1: split sig into R (enc) and S; S must be < L */
    if (scalar_gte_l(sig + 32)) {
        return 0;
    }
    /* decode public key A; reject non-canonical / non-decodable */
    if (!ge_decode(&a_point, pk)) {
        return 0;
    }
    /* reject small-order A: [8]A == identity means order divides 8 */
    {
        ge a8;
        ge_double(&a8, &a_point);
        ge_double(&a8, &a8);
        ge_double(&a8, &a8);
        if (ge_is_identity(&a8)) {
            return 0;
        }
    }
    /* decode R */
    if (!ge_decode(&r_point, sig)) {
        return 0;
    }
    /* k = SHA512(R || A || M) mod L */
    {
        eth_sha512_ctx ctx;
        eth_sha512_init(&ctx);
        eth_sha512_update(&ctx, sig, 32);      /* R bytes */
        eth_sha512_update(&ctx, pk, 32);       /* A bytes */
        eth_sha512_update(&ctx, msg, msg_len); /* M */
        eth_sha512_final(&ctx, h);
    }
    scalar_reduce(k, h);

    /* check [S]B == R + [k]A */
    ge_scalarmult(&p1, sig + 32, &GE_BASE);
    ge_scalarmult(&p2, k, &a_point);
    ge_add(&p3, &r_point, &p2);
    return ge_equal(&p1, &p3);
}

/* ------------------------------------------------------------------ */
/* built-in KAT: RFC 8032 §7.1 TEST 1 (empty message)                 */
/* ------------------------------------------------------------------ */

int eth_ed25519_selftest(void)
{
    static const uint8_t pk[32] = {
        0xd7, 0x5a, 0x98, 0x01, 0x82, 0xb1, 0x0a, 0xb7,
        0xd5, 0x4b, 0xfe, 0xd3, 0xc9, 0x64, 0x07, 0x3a,
        0x0e, 0xe1, 0x72, 0xf3, 0xda, 0xa6, 0x23, 0x25,
        0xaf, 0x02, 0x1a, 0x68, 0xf7, 0x07, 0x51, 0x1a,
    };
    static const uint8_t sig[64] = {
        0xe5, 0x56, 0x43, 0x00, 0xc3, 0x60, 0xac, 0x72,
        0x90, 0x86, 0xe2, 0xcc, 0x80, 0x6e, 0x82, 0x8a,
        0x84, 0x87, 0x7f, 0x1e, 0xb8, 0xe5, 0xd9, 0x74,
        0xd8, 0x73, 0xe0, 0x65, 0x22, 0x49, 0x01, 0x55,
        0x5f, 0xb8, 0x82, 0x15, 0x90, 0xa3, 0x3b, 0xac,
        0xc6, 0x1e, 0x39, 0x70, 0x1c, 0xf9, 0xb4, 0x6b,
        0xd2, 0x5b, 0xf5, 0xf0, 0x59, 0x5b, 0xbe, 0x24,
        0x65, 0x51, 0x41, 0x43, 0x8e, 0x7a, 0x10, 0x0b,
    };
    /* empty message */
    if (!eth_ed25519_verify(sig, pk, (const uint8_t *)"", 0)) {
        return 0;
    }
    /* tampered signature must fail */
    {
        uint8_t bad[64];
        for (int i = 0; i < 64; i++) {
            bad[i] = sig[i];
        }
        bad[0] ^= 1u;
        if (eth_ed25519_verify(bad, pk, (const uint8_t *)"", 0) != 0) {
            return 0;
        }
    }
    return 1;
}
