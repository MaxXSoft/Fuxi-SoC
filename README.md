# Fuxi-SoC

[Fuxi](https://github.com/MaxXSoft/Fuxi) RISC-V System-on-Chip design for
ZedBoard.

## Getting started

```sh
git clone https://github.com/MaxXSoft/Fuxi-SoC.git && cd Fuxi-SoC
git -c core.symlinks=true submodule update --init --recursive

# On x86-64 Linux with Vivado and the build tools installed:
source /path/to/Vivado/settings64.sh
make test
make fpga RISCV_CC=clang RISCV_OBJCOPY=llvm-objcopy RISCV_LD=ld.lld
make fsbl
```

`make fpga` prepares the RTL and Boot ROM before running Vivado. For a split
build (for example, preparing inputs on macOS and running Vivado on Linux), see
the optional [remote build workflow](docs/build.md#optional-remote-vivado-build).

## Design details

The PS initializes DDR/MIO/clocks, configures the PL, enables QSPI linear reads,
and releases Fuxi. ARM then parks. Fuxi loads OpenSBI, Linux and its device tree
from Flash into DDR.

- [Build, test and firmware packaging](docs/build.md)
- [Address map, interrupts and boot/software contract](docs/architecture.md)
- [Program QSPI from SD without JTAG or Vivado](docs/sd-flasher.md)

## Dependencies

`third_party/fuxi` supplies the core, `third_party/embeddedsw` the AMD Zynq FSBL
and standalone drivers, `third_party/lz4` the boot image codec, and
`third_party/u-boot` the optional SD maintenance bootloader. Each dependency
retains its own license. This repository's original code is licensed under MIT.

For the corresponding Linux build, please check
[Fuxi-Linux](https://github.com/MaxXSoft/Fuxi-Linux).
