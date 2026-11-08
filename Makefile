SHELL := /bin/bash
ROOT := $(abspath .)
PYTHON ?= python3
VIVADO ?= vivado
SBT ?= sbt
VERILATOR ?= verilator
DTC ?= dtc
CONFIG ?= DefaultConfig
RISCV_CC ?= clang
RISCV_OBJCOPY ?= llvm-objcopy
RISCV_LD ?=
OPENSBI ?=
LINUX ?=
UBOOT_CROSS_COMPILE ?= arm-none-eabi-
FLASH_IMAGE ?= $(ROOT)/build/flash/flash.bin

.PHONY: all prepare rtl bootrom dtb test test-peripherals test-image project fpga fsbl payload flash sync sd-flasher sd-flasher-package test-sd-flasher
all: prepare
prepare: rtl bootrom dtb

rtl:
	mkdir -p build/fuxi
	cd third_party/fuxi && $(SBT) "runMain Fuxi --config $(CONFIG) --target-dir $(ROOT)/build/fuxi"

bootrom:
	$(PYTHON) scripts/build_bootrom.py --cc "$(RISCV_CC)" --objcopy "$(RISCV_OBJCOPY)" $(if $(RISCV_LD),--ld "$(RISCV_LD)")

dtb:
	mkdir -p build
	$(DTC) -I dts -O dtb -o build/fuxi-zedboard.dtb software/linux/fuxi-zedboard.dts

test: test-peripherals test-image

test-peripherals:
	mkdir -p build/tests/peripherals
	$(VERILATOR) --binary --timing --assert -Wno-TIMESCALEMOD --top-module peripherals_tb --Mdir build/tests/peripherals rtl/axi_lite_regs.v rtl/clint.v rtl/plic.v tests/peripherals_tb.sv
	build/tests/peripherals/Vperipherals_tb

test-image:
	$(PYTHON) tests/test_image.py

# Prepare locally, then rsync the sources and generated portable inputs to a
# Linux host with Vivado. These targets deliberately do not invoke sbt or LLVM.
project:
	test -f build/fuxi/Fuxi.v && test -f build/bootrom/bootrom.mem
	$(VIVADO) -mode batch -source scripts/create_project.tcl -log build/create.log -journal build/create.jou

fpga: project
	$(VIVADO) -mode batch -source scripts/implement.tcl -log build/implement.log -journal build/implement.jou

fsbl:
	$(PYTHON) scripts/build_fsbl.py

payload: dtb
	test -n "$(OPENSBI)" && test -n "$(LINUX)"
	$(PYTHON) scripts/pack_image.py --opensbi "$(OPENSBI)" --linux "$(LINUX)" --dtb build/fuxi-zedboard.dtb

flash:
	$(PYTHON) scripts/package_flash.py

# Independent PS-only SD boot environment; no Vivado/XSA/bitstream dependency.
sd-flasher:
	$(PYTHON) scripts/build_sd_flasher.py --cross-compile "$(UBOOT_CROSS_COMPILE)"
	$(PYTHON) scripts/package_sd_flasher.py --flash "$(FLASH_IMAGE)"

sd-flasher-package:
	$(PYTHON) scripts/package_sd_flasher.py --flash "$(FLASH_IMAGE)"

test-sd-flasher:
	$(PYTHON) tests/test_sd_flasher.py

sync:
	test -n "$(REMOTE)" && test -n "$(REMOTE_DIR)"
	rsync -az --exclude=.git --exclude=target --exclude=/build/ --exclude=__pycache__ ./ "$(REMOTE):$(REMOTE_DIR)/"
	rsync -az --relative build/fuxi build/bootrom "$(REMOTE):$(REMOTE_DIR)/"
