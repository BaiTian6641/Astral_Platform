# SPDX-License-Identifier: MIT
#
# bmc-fw crypto Makefile — host-side validation for the Ed25519 verifier (E1-RUN2).
# Standalone: NOT wired into the root Makefile (daemon wave owns target linking).
#
#   make            — build + run the host test suite (gcc, -Wall -Wextra -Werror)
#   make profile    — build + run with fe_mul op-counter (cycle estimate input)
#   make target     — riscv64 cross-compile check (rv32imc/ilp32, .o only)
#   make vectors    — regenerate test_vectors.h via gen_vectors.py (PyCA)
#   make clean
#
# Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md (E1-RUN2).

CC      ?= gcc
CFLAGS  := -Wall -Wextra -Werror -std=c99 -O2 -I.

RISCV_PREFIX ?= riscv64-unknown-elf
ifeq ($(RISCV),)
RISCV_GCC := $(firstword $(wildcard ~/tools/riscv/usr/bin/$(RISCV_PREFIX)-gcc) $(shell which $(RISCV_PREFIX)-gcc 2>/dev/null))
else
RISCV_GCC := $(RISCV)/bin/$(RISCV_PREFIX)-gcc
endif
RISCV_SIZE  := $(RISCV_GCC:gcc=size)
CROSS_FLAGS := -march=rv32imc -mabi=ilp32 -nostdlib -ffreestanding -Os \
               -Wall -Wextra -Werror -I.

BUILD := build
OBJS  := $(BUILD)/sha512.o $(BUILD)/ed25519.o $(BUILD)/test_host.o

.PHONY: all run profile target vectors clean
all: run

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/sha512.o: sha512.c sha512.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/ed25519.o: ed25519.c ed25519.h sha512.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/test_host.o: test_host.c ed25519.h sha512.h test_vectors.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/test_host: $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) -o $@

run: $(BUILD)/test_host
	./$(BUILD)/test_host

profile: ed25519.c ed25519.h sha512.c sha512.h test_host.c test_vectors.h | $(BUILD)
	$(CC) $(CFLAGS) -DETH_ED25519_PROFILE -o $(BUILD)/test_profile \
	    test_host.c ed25519.c sha512.c
	./$(BUILD)/test_profile

target: ed25519.c ed25519.h sha512.c sha512.h | $(BUILD)
	$(RISCV_GCC) $(CROSS_FLAGS) -c ed25519.c -o $(BUILD)/ed25519.rv32.o
	$(RISCV_GCC) $(CROSS_FLAGS) -c sha512.c -o $(BUILD)/sha512.rv32.o
	$(RISCV_SIZE) $(BUILD)/ed25519.rv32.o $(BUILD)/sha512.rv32.o

vectors: gen_vectors.py
	python3 gen_vectors.py > test_vectors.h

clean:
	rm -rf $(BUILD)
