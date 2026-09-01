# SPDX-License-Identifier: MIT
#
# bmc-fw Makefile — build the NEORV32 BMC firmware images (E1-RUN2 daemon).
#
# Uses the bare-metal RISC-V toolchain (riscv64-unknown-elf-gcc, rv32imc/ilp32).
# Toolchain resolution order: $RISCV/bin/riscv64-unknown-elf-gcc, then
# ~/tools/riscv/usr/bin/..., then PATH. Override with `make RISCV=/path`.
#
# DMEM-exec bootstrap (see boot/crt0.S BOOTSTRAP NOTE): the vendored netlist's
# IMEM ROM is physically 1 KiB, so the link emits TWO images:
#   build/bmc_boot.hex         — .boot stub (crt0), $readmemh into the IMEM ROM
#                                array (256 words, word-per-line %08x);
#   build/bmc_dmem_lane{0..3}.hex — the full firmware (.text/.rodata/.data in
#                                DMEM @0x80000000), split into the 4 dmem_ram
#                                byte-lane spram arrays ($readmemh %02x).
#
# `make vectors` regenerates daemon/keyring.h (deterministic; committed).
#
# Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2/§2.3.

RISCV_PREFIX ?= riscv64-unknown-elf
ifeq ($(RISCV),)
TOOLCHAIN := $(firstword $(wildcard ~/tools/riscv/usr/bin/$(RISCV_PREFIX)-gcc) $(shell which $(RISCV_PREFIX)-gcc 2>/dev/null))
else
TOOLCHAIN := $(RISCV)/bin/$(RISCV_PREFIX)-gcc
endif
CC      := $(TOOLCHAIN)
OBJCOPY := $(TOOLCHAIN:gcc=objcopy)

CROSS_FLAGS := -march=rv32imc -mabi=ilp32 -nostdlib -ffreestanding -Os \
               -Wall -Wextra -Werror -fno-common -g0
CFLAGS  := $(CROSS_FLAGS) -I.
ASFLAGS := $(CROSS_FLAGS)
LDFLAGS := $(CROSS_FLAGS) -T link.ld -Wl,--no-warn-rwx-segments

BUILD := build
OBJS  := $(BUILD)/crt0.o $(BUILD)/main.o $(BUILD)/uart.o \
         $(BUILD)/sha512.o $(BUILD)/ed25519.o $(BUILD)/daemon.o

.PHONY: all clean check-tool vectors
all: $(BUILD)/bmc_boot.hex $(BUILD)/bmc_dmem_lane0.hex

check-tool:
ifeq ($(TOOLCHAIN),)
	@echo "[bmc-fw] ERROR: $(RISCV_PREFIX)-gcc not found. Install the bare-metal"; \
	 echo "        RISC-V toolchain (riscv64-unknown-elf) or set RISCV=<path>."; exit 1
endif

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/crt0.o: boot/crt0.S link.ld | $(BUILD)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD)/main.o: main.c drivers/uart.h drivers/emri.h crypto/ed25519.h daemon/daemon.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/uart.o: drivers/uart.c drivers/uart.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/sha512.o: crypto/sha512.c crypto/sha512.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/ed25519.o: crypto/ed25519.c crypto/ed25519.h crypto/sha512.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/daemon.o: daemon/daemon.c daemon/daemon.h daemon/keyring.h \
                   drivers/emri.h drivers/uart.h crypto/ed25519.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/bmc_fw.elf: $(OBJS) link.ld
	$(CC) $(LDFLAGS) $(OBJS) -o $@

# Boot stub image (.boot section only; the ROM is 256 words = 1 KiB).
$(BUILD)/bmc_boot.bin: $(BUILD)/bmc_fw.elf
	$(OBJCOPY) -O binary --only-section=.boot $< $@

$(BUILD)/bmc_boot.hex: $(BUILD)/bmc_boot.bin bin2hex.py
	python3 bin2hex.py $< $@ 256

# DMEM image (.text+.rodata+.data at 0x80000000) split into 4 byte lanes
# (4096-deep spram per lane = 16 KiB DMEM).
$(BUILD)/bmc_dmem.bin: $(BUILD)/bmc_fw.elf
	$(OBJCOPY) -O binary --only-section=.text --only-section=.data $< $@

$(BUILD)/bmc_dmem_lane0.hex: $(BUILD)/bmc_dmem.bin bin2hex.py
	python3 bin2hex.py --lanes 4 4096 $< $(BUILD)/bmc_dmem_lane

# Regenerate the trusted-key keyring (deterministic; also used for TB vectors).
vectors: daemon/gen_daemon_vectors.py
	python3 daemon/gen_daemon_vectors.py --keyring daemon/keyring.h

clean:
	rm -rf $(BUILD)
