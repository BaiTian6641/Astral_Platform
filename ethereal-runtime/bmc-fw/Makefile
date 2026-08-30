# SPDX-License-Identifier: MIT
#
# bmc-fw Makefile — build the NEORV32 BMC firmware image (E1-BMC2).
#
# Uses the bare-metal RISC-V toolchain (riscv64-unknown-elf-gcc, rv32imc/ilp32).
# Toolchain resolution order: $RISCV/bin/riscv64-unknown-elf-gcc, then
# ~/tools/riscv/usr/bin/..., then PATH. Override with `make RISCV=/path`.
#
# Output: build/bmc_fw.hex — one 32-bit word per line (%08x), for $readmemh
# backdoor preload into the IMEM ROM (matches tb_bmc_hello/tb_bmc_axi_*).
#
# Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2.

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
OBJS  := $(BUILD)/crt0.o $(BUILD)/main.o $(BUILD)/uart.o

.PHONY: all clean check-tool
all: $(BUILD)/bmc_fw.hex

check-tool:
ifeq ($(TOOLCHAIN),)
	@echo "[bmc-fw] ERROR: $(RISCV_PREFIX)-gcc not found. Install the bare-metal"; \
	 echo "        RISC-V toolchain (riscv64-unknown-elf) or set RISCV=<path>."; exit 1
endif

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/crt0.o: boot/crt0.S | $(BUILD)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD)/main.o: main.c drivers/uart.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/uart.o: drivers/uart.c drivers/uart.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/bmc_fw.elf: $(OBJS) link.ld
	$(CC) $(LDFLAGS) $(OBJS) -o $@

$(BUILD)/bmc_fw.bin: $(BUILD)/bmc_fw.elf
	$(OBJCOPY) -O binary $< $@

$(BUILD)/bmc_fw.hex: $(BUILD)/bmc_fw.bin bin2hex.py
	python3 bin2hex.py $< $@ 256

clean:
	rm -rf $(BUILD)
