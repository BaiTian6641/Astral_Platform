/* SPDX-License-Identifier: MIT */
/*
 * sha512.h — freestanding SHA-512 (FIPS 180-4) for bmc-fw crypto (no libc).
 *
 * One-shot + streaming API, static state only, no dynamic memory (G1). Used by the
 * Ed25519 verifier (RFC 8032 needs SHA-512 for the challenge hash).
 *
 * Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md (E1-RUN2 daemon
 *           verify path); ethereal-runtime/bmc-fw/crypto/ed25519.c.
 */
#ifndef BMC_FW_CRYPTO_SHA512_H
#define BMC_FW_CRYPTO_SHA512_H

#include <stdint.h>
#include <stddef.h>

/* Streaming context: 8x64-bit state + 128-byte block buffer. */
typedef struct {
    uint64_t h[8];          /* running state */
    uint64_t len_hi;        /* total message length, bits, 128-bit counter */
    uint64_t len_lo;
    uint8_t  block[128];    /* partial block */
    uint32_t block_len;     /* bytes in block[] */
} eth_sha512_ctx;

void eth_sha512_init(eth_sha512_ctx *ctx);
void eth_sha512_update(eth_sha512_ctx *ctx, const uint8_t *data, uint32_t len);
void eth_sha512_final(eth_sha512_ctx *ctx, uint8_t out[64]);

/* One-shot convenience. */
void eth_sha512(const uint8_t *data, uint32_t len, uint8_t out[64]);

#endif /* BMC_FW_CRYPTO_SHA512_H */
