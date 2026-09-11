#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""gen_deploy_scripts — assemble the E2-AST1 deployment-script flash window.

Emits the 128-word script-window image ($readmemh %08x, one 32-bit word per
line) that tb_bmc_script.sv preloads into the external-flash stand-in at
0x4001_0000, where the BMC firmware reads it over XBUS and executes it
(script/script.c). This generator is the normative byte-layout source for the
format; script/script.h documents the opcode table and the interpreter
implements it.

Slot 0  "deploy"  the happy path: start marker -> settle -> DEPLOY r0 ->
                  wait for RUNNING -> EFP_ERR must be 0 -> "region 0 RUNNING"
                  marker -> hold RUNNING (WAIT, so a host/TB can observe the
                  deployed fabric before it is stopped) -> 2 marker iterations
                  through LOOP/LOOPEND ->
                  STOP r0 -> wait for STOPPED -> EFP_ERR must be 0 ->
                  "region 0 stopped" marker -> END.
Slot 1  "reject"  the negative path: a host-staged image whose signature was
                  tampered must be refused by the Ed25519 gate (EFP_ERR=1,
                  bad_sig), reported as a marker and asserted via CHECK_ERR.

Deterministic: no timestamps, no randomness. Format/opcode constants mirror
ethereal-runtime/bmc-fw/script/script.h; EMRI word offsets mirror
drivers/emri.h (single ABI — drift means the script polls the wrong register).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# ---- script container (script.h) ------------------------------------------
WINDOW_WORDS = 128  # 512 B flash stand-in window
SLOT_WORDS = 64  # one script slot (header + instructions)
HDR_WORDS = 4  # magic, version, length, crc32
MAX_INSN = SLOT_WORDS - HDR_WORDS
MAGIC = 0x53435231  # "SCR1"
VERSION = 1

# ---- opcodes (script.h opcode table) --------------------------------------
OP_END = 0x00
OP_DEPLOY = 0x01
OP_STOP = 0x02
OP_POLL = 0x03
OP_CHECK_ERR = 0x04
OP_UART = 0x05
OP_WAIT = 0x06
OP_LOOP = 0x07
OP_LOOPEND = 0x08

# ---- EMRI / EFP ABI constants the scripts touch (drivers/emri.h) ----------
R_EFP_STATUS = 0x16  # {state[3:0], busy[4], done[5]}
R_EFP_ERR = 0x17  # sticky error, [7:0]
EFP_STATUS_STATE_MASK = 0x0F
EFP_S_RUNNING = 6
EFP_S_STOPPED = 8
EFP_ERR_NONE = 0
EFP_ERR_BAD_SIG = 1

# ---- script slot indices / markers (the TB's observable contract) ---------
SLOT_DEPLOY = 0
SLOT_REJECT = 1
MARKER_START = "AST1: script start\n"
MARKER_RUNNING = "AST1: region 0 RUNNING\n"
MARKER_TICK = "AST1: tick\n"
MARKER_STOPPED = "AST1: region 0 stopped\n"
MARKER_REJECT_START = "AST1: script reject\n"
MARKER_REJECTED = "AST1: bad_sig rejected\n"

SETTLE_ITERS = 256  # WAIT: service iterations before the deploy settles
HOLD_ITERS = 2048  # WAIT: hold RUNNING (the TB observes the real fabric)
TICK_ITERS = 2  # LOOP: marker repetitions
REGION0 = 0


def insn(op: int, arg: int = 0) -> int:
    """One instruction word: opcode[31:24] | operand[23:0]."""
    if not 0 <= op <= 0xFF:
        raise ValueError(f"opcode out of range: {op}")
    if not 0 <= arg <= 0xFFFFFF:
        raise ValueError(f"operand out of range: {arg}")
    return ((op & 0xFF) << 24) | (arg & 0xFFFFFF)


def uart_op(text: str) -> list[int]:
    """OP_UART + the marker bytes packed LSB-first across ceil(n/4) words."""
    data = text.encode("ascii")
    if not 1 <= len(data) <= 64:
        raise ValueError(f"UART marker length out of range: {len(data)}")
    words = [
        int.from_bytes(data[i : i + 4].ljust(4, b"\x00"), "little")
        for i in range(0, len(data), 4)
    ]
    return [insn(OP_UART, len(data)), *words]


def poll_op(word: int, mask: int, value: int) -> list[int]:
    """OP_POLL + the {mask[31:16], value[15:0]} immediate word."""
    if mask == 0:
        raise ValueError("POLL mask 0 is rejected by the interpreter")
    return [insn(OP_POLL, word), ((mask & 0xFFFF) << 16) | (value & 0xFFFF)]


def deploy_body() -> list[int]:
    """Slot 0: the happy-path deployment sequence."""
    return [
        *uart_op(MARKER_START),
        insn(OP_WAIT, SETTLE_ITERS),
        insn(OP_DEPLOY, REGION0),
        *poll_op(R_EFP_STATUS, EFP_STATUS_STATE_MASK, EFP_S_RUNNING),
        insn(OP_CHECK_ERR, EFP_ERR_NONE),
        *uart_op(MARKER_RUNNING),
        insn(OP_WAIT, HOLD_ITERS),
        insn(OP_LOOP, TICK_ITERS),
        *uart_op(MARKER_TICK),
        insn(OP_LOOPEND),
        insn(OP_STOP, REGION0),
        *poll_op(R_EFP_STATUS, EFP_STATUS_STATE_MASK, EFP_S_STOPPED),
        insn(OP_CHECK_ERR, EFP_ERR_NONE),
        *uart_op(MARKER_STOPPED),
        insn(OP_END),
    ]


def reject_body() -> list[int]:
    """Slot 1: a tampered-signature image must be refused by the Ed25519 gate."""
    return [
        *uart_op(MARKER_REJECT_START),
        insn(OP_DEPLOY, REGION0),
        insn(OP_CHECK_ERR, EFP_ERR_BAD_SIG),
        *uart_op(MARKER_REJECTED),
        insn(OP_END),
    ]


def crc32_word(crc: int, word: int) -> int:
    """CRC32 as occ_top/fwupdate.c/script.c: poly 0x04C11DB7, init 0xFFFFFFFF,
    MSB-byte-first per word, no final xor."""
    for _ in range(4):
        crc ^= ((word >> 24) & 0xFF) << 24
        crc &= 0xFFFFFFFF
        for _ in range(8):
            if crc & 0x80000000:
                crc = ((crc << 1) ^ 0x04C11DB7) & 0xFFFFFFFF
            else:
                crc = (crc << 1) & 0xFFFFFFFF
        word = (word << 8) & 0xFFFFFFFF
    return crc


def body_crc(body: list[int]) -> int:
    """CRC32 over the instruction words (the slot's integrity gate)."""
    crc = 0xFFFFFFFF
    for word in body:
        crc = crc32_word(crc, word)
    return crc


def slot_image(name: str, body: list[int]) -> list[int]:
    """Header + body, zero-padded to SLOT_WORDS (padding is never executed)."""
    if not 1 <= len(body) <= MAX_INSN:
        raise ValueError(f"slot {name}: {len(body)} instruction words (max {MAX_INSN})")
    header = [MAGIC, VERSION, len(body), body_crc(body)]
    image = [*header, *body]
    return image + [0] * (SLOT_WORDS - len(image))


def window_image(slots: dict[int, list[int]]) -> list[int]:
    """Assemble the flash window from script bodies keyed by slot index."""
    image = [0] * WINDOW_WORDS
    for index, body in sorted(slots.items()):
        if not 0 <= index < WINDOW_WORDS // SLOT_WORDS:
            raise ValueError(f"slot index out of range: {index}")
        slot = slot_image(f"slot {index}", body)
        image[index * SLOT_WORDS : (index + 1) * SLOT_WORDS] = slot
    return image


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out",
        default="generated/bmc/script_window.hex",
        help="output $readmemh image (default: %(default)s)",
    )
    args = parser.parse_args(argv)

    slots = {SLOT_DEPLOY: deploy_body(), SLOT_REJECT: reject_body()}
    for index, body in sorted(slots.items()):
        print(
            f"[gen_deploy_scripts] slot {index}: {len(body)} instruction words, "
            f"crc32 0x{body_crc(body):08x}"
        )
    image = window_image(slots)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("".join(f"{word:08x}\n" for word in image))
    print(f"[gen_deploy_scripts] {len(image)} words -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
