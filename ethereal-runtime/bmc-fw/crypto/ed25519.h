/* SPDX-License-Identifier: MIT */
/*
 * ed25519.h — Ed25519 signature VERIFICATION (RFC 8032, verify-only) for bmc-fw.
 *
 * Freestanding C99, no libc, no dynamic memory (G1). Constant-time is NOT a
 * goal (public-key verify on the BMC); simplicity + correctness first.
 *
 * The E1-RUN2 daemon verifies the ethimg signature over the manifest_digest
 * hex UTF-8 bytes (ethereal-tools/tools/ethimg.py _sign_digest/_verify_sig).
 *
 * Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md (E1-RUN2 daemon
 *           verify path); ethereal-tools/tools/ethimg.py §signature.
 */
#ifndef BMC_FW_CRYPTO_ED25519_H
#define BMC_FW_CRYPTO_ED25519_H

#include <stdint.h>

int eth_ed25519_verify(const uint8_t sig[64], const uint8_t pk[32],
                       const uint8_t *msg, uint32_t msg_len);
/* returns 1 = signature valid, 0 = invalid. All inputs little-endian per RFC 8032. */

/* Built-in known-answer test (RFC 8032 §7.1 TEST 1, empty message).
 * Returns 1 on pass, 0 on fail. For on-target smoke testing. */
int eth_ed25519_selftest(void);

#endif /* BMC_FW_CRYPTO_ED25519_H */
