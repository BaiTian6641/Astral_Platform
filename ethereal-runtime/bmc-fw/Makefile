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
         $(BUILD)/sha512.o $(BUILD)/ed25519.o $(BUILD)/daemon.o \
         $(BUILD)/sdi.o $(BUILD)/efp_spi.o

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

$(BUILD)/main.o: main.c drivers/uart.h drivers/emri.h crypto/ed25519.h daemon/daemon.h efp-spi/efp_spi.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/uart.o: drivers/uart.c drivers/uart.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/sha512.o: crypto/sha512.c crypto/sha512.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/ed25519.o: crypto/ed25519.c crypto/ed25519.h crypto/sha512.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/daemon.o: daemon/daemon.c daemon/daemon.h daemon/keyring.h \
                   drivers/emri.h drivers/uart.h crypto/ed25519.h \
                   efp-spi/efp_spi.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/sdi.o: efp-spi/sdi.c efp-spi/sdi.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/efp_spi.o: efp-spi/efp_spi.c efp-spi/efp_spi.h efp-spi/sdi.h \
                    drivers/emri.h daemon/daemon.h | $(BUILD)
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

# ----------------------------------------------------------------------
# E1-BMC2 sim-demo firmware: dual-partition fw-update variant (fwupdate/,
# emri-v0.md sec 3.6 v0.4). SIM-SCOPED: no Ed25519/daemon/SPI — just the
# boot stub + update server + UART/EMRI drivers.
# ----------------------------------------------------------------------
FWUPD_OBJS := $(BUILD)/crt0.o $(BUILD)/main_fwupdate.o $(BUILD)/uart.o \
              $(BUILD)/fwupdate.o

$(BUILD)/main_fwupdate.o: fwupdate/main_fwupdate.c drivers/uart.h \
                          fwupdate/fwupdate.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/fwupdate.o: fwupdate/fwupdate.c fwupdate/fwupdate.h drivers/emri.h \
                     drivers/uart.h daemon/daemon.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/fwupdate.elf: $(FWUPD_OBJS) link.ld
	$(CC) $(LDFLAGS) $(FWUPD_OBJS) -o $@

$(BUILD)/fwupdate_boot.bin: $(BUILD)/fwupdate.elf
	$(OBJCOPY) -O binary --only-section=.boot $< $@

$(BUILD)/fwupdate_boot.hex: $(BUILD)/fwupdate_boot.bin bin2hex.py
	python3 bin2hex.py $< $@ 256

$(BUILD)/fwupdate_dmem.bin: $(BUILD)/fwupdate.elf
	$(OBJCOPY) -O binary --only-section=.text --only-section=.data $< $@

$(BUILD)/fwupdate_dmem_lane0.hex: $(BUILD)/fwupdate_dmem.bin bin2hex.py
	python3 bin2hex.py --lanes 4 4096 $< $(BUILD)/fwupdate_dmem_lane

.PHONY: fwupdate slots
fwupdate: $(BUILD)/fwupdate_boot.hex $(BUILD)/fwupdate_dmem_lane0.hex

# Slot payloads (XIP from the TB flash window 0x4001_0000): slot A payload
# entry = word 5 = byte 0x14; slot B entry = word 64+5 = byte 0x114
# (fwupdate.h slot layout). Padded to exactly FW_PAYLOAD_WORDS = 16 words.
SLOT_A_ENTRY := 0x40010014
SLOT_B_ENTRY := 0x40010114

$(BUILD)/slot_v1.elf: fwupdate/slot_payload.S | $(BUILD)
	$(CC) $(ASFLAGS) -nostartfiles -Wl,-Ttext=$(SLOT_A_ENTRY) -D SLOT_VER=1 -o $@ $<

$(BUILD)/slot_v2.elf: fwupdate/slot_payload.S | $(BUILD)
	$(CC) $(ASFLAGS) -nostartfiles -Wl,-Ttext=$(SLOT_B_ENTRY) -D SLOT_VER=2 -o $@ $<

$(BUILD)/slot_v1.hex: $(BUILD)/slot_v1.elf bin2hex.py
	$(OBJCOPY) -O binary $< $(BUILD)/slot_v1.bin
	python3 bin2hex.py $(BUILD)/slot_v1.bin $@ 16

$(BUILD)/slot_v2.hex: $(BUILD)/slot_v2.elf bin2hex.py
	$(OBJCOPY) -O binary $< $(BUILD)/slot_v2.bin
	python3 bin2hex.py $(BUILD)/slot_v2.bin $@ 16

slots: $(BUILD)/slot_v1.hex $(BUILD)/slot_v2.hex

# Regenerate the trusted-key keyring (deterministic; also used for TB vectors).
vectors: daemon/gen_daemon_vectors.py
	python3 daemon/gen_daemon_vectors.py --keyring daemon/keyring.h
