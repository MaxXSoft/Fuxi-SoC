# Build and validate

## Tools and dependencies

- Git and initialized submodules (`git submodule update --init --recursive`).
- JDK/sbt compatible with the pinned Fuxi build.
- Python 3, a native C compiler, LLVM with the RISC-V backend plus LLD and
  llvm-objcopy (or a `riscv*-unknown-elf-gcc` toolchain).
- Verilator and a C++ toolchain for RTL tests; `dtc` for the device tree.
- Linux x86-64 Vivado **2025.2**, Zynq-7000 device support and board definition
  `avnet.com:zedboard:part0:1.4`.
- `arm-none-eabi-gcc`, its binutils, and newlib for FSBL. On Ubuntu:
  `apt-get install --no-install-recommends gcc-arm-none-eabi libnewlib-arm-none-eabi`.
  This flow builds the upstream standalone BSP directly and does not need Vitis.

Vivado's board catalog must contain the Avnet ZedBoard definition before running
Tcl. The 1.4 preset is the source for DDR/MIO configuration; do not substitute a
preset for another board. The script asserts reset polarity after propagation.
On Ubuntu, Vivado 2025.2 can spill multiline OS metadata into generated HDL
headers. `sanitize_vivado_headers.py` repairs only those comments automatically.

## Prepare and test

```sh
make prepare RISCV_CC=clang RISCV_OBJCOPY=llvm-objcopy RISCV_LD=ld.lld
make test
```

`RISCV_LD` may be an absolute path to LLD. For GCC, set `RISCV_CC` and
`RISCV_OBJCOPY` to the matching cross-toolchain executables and omit `RISCV_LD`.
The first sbt run downloads the pinned Scala/Chisel toolchain dependencies.

`build/fuxi/` contains generated core RTL, `build/bootrom/` contains ELF, raw
binary, linker map and BRAM memory files, and `build/fuxi-zedboard.dtb` is the
board DTB. The generated ROM is 16 KiB with entry point at byte offset `0x200`.
All generated files remain ignored by Git.

Tests exercise independent AXI AW/W ordering, B/R backpressure, CLINT register
strobes/timer delivery, PLIC priorities, two-context claims, threshold,
completion/retrigger and reserved registers. Host tests compile the **actual ROM
C decoder** and round-trip raw/LZ4 images, check every header byte for corruption,
and reject malformed blocks and out-of-range segments.

## Remote Vivado build

Use rsync, including submodule working trees, rather than copying a Vivado
project. `REMOTE_DIR` is the path **on the SSH host**, not necessarily the path
inside its Docker container:

```sh
make sync REMOTE=my-server REMOTE_DIR=/host/path/Fuxi-SoC
ssh my-server 'docker exec my-container bash -lc "source /opt/AMD/2025.2/Vivado/settings64.sh; cd /container/path/Fuxi-SoC; make fpga"'
```

`make sync` does not delete remote files. It excludes `.git`, sbt targets and
generated build outputs, and transfers the prepared portable RTL/ROM inputs separately.
`make fpga` creates a fresh project, validates the block design, synthesizes,
places, routes, writes the bitstream and exports the hardware platform.

`constraints/cache_ram.xdc` forces the I/D-Cache **data arrays** into block RAM
at their leaf memory instances. The constraint belongs to this FPGA platform;
the core's Chisel memories remain portable. Asynchronous tag memories and
valid/dirty metadata keep their existing lookup latency and may use LUTs/FFs.
Synthesis and implementation both verify BRAM primitives under each data array
and reject LUT RAM there. If a core/compiler update renames these instances,
update the constraint and checker together; do not disable the check.

Outputs:

- `build/fuxi_zedboard.bit`, `build/fuxi_zedboard.xsa`.
- `build/reports/timing_summary.rpt`: setup/hold slack, TNS, failing endpoints,
  unconstrained paths and clock checks.
- `build/reports/critical_paths.rpt`, `utilization.rpt`, `route_status.rpt`,
  `drc.rpt`, `methodology.rpt`, `clock_interaction.rpt`.
- `build/reports/cache_ram_synth.rpt`, `cache_ram.rpt`: verified cache data RAM
  mappings before and after implementation.

The reports are evidence of that build, not repository inputs. A bitstream may
be generated even when timing fails: inspect WNS/TNS and hold results before
using it. `make fpga` does not program a board or change Flash.

## FSBL and Flash image

After `make project` or `make fpga` has exported the XSA:

```sh
make fsbl
```

This copies the pinned AMD sources to `build/fsbl/`, replaces the upstream Zed
`ps7_init.c/.h` with the files from **this XSA**, installs the custom hooks, and
builds `build/fsbl/fsbl.elf`. The dependency checkout stays clean. The upstream
Zed BSP supplies PS driver configuration tables; PS UART reference frequency
must remain 50 MHz. The peripheral IRQ and GPIO routing in the PL is handled
by the hardware Tcl, not by generated ARM device drivers.

Build a generic RV32 OpenSBI `fw_jump.bin` and an uncompressed Linux `Image` with
a built-in initramfs. Merge `software/linux/zedboard.config` into the existing
Fuxi-Linux config and run `olddefconfig` before compiling the kernel. The resulting
kernel retains testbench 8250 support and adds the board's Cadence console.
See [architecture.md](architecture.md) for entry addresses and the DTB contract.
Then:

```sh
make payload OPENSBI=/path/to/fw_jump.bin LINUX=/path/to/Image
make flash
```

Run `make flash` in an environment with `bootgen` on PATH (Vivado settings).
It builds `build/flash/BOOT.BIN` containing only FSBL and bitstream, and combines
it with the payload at offset 8 MiB into `build/flash/flash.bin`. Both allocations
are checked against the 16 MiB bank-0 boundary. `flash.bin` is a raw Flash image,
not an SD-card filesystem image. Program it at QSPI offset 0 using the board's
normal Flash-programming workflow, then select QSPI boot mode and reset.

No real-board boot is implied by RTL tests or successful implementation. Board
bring-up should check the FSBL handoff message, ROM message, OpenSBI banner,
Linux console, timer ticks and bidirectional UART traffic in that order.

For a kernel-only build that reuses an existing Fuxi-Linux initramfs and leaves
that repository untouched, unpack the Linux revision recorded by Fuxi-Linux's
`sources.lock` into a clean directory, then run on Linux:

```sh
python3 scripts/build_linux.py --source /path/to/linux \
  --config /path/to/Fuxi-Linux/output/images/linux.config \
  --initramfs /path/to/Fuxi-Linux/output/images/rootfs.cpio \
  --cross-compile riscv64-linux-gnu- --jobs 8
make payload OPENSBI=/path/to/fw_jump.bin LINUX=build/Image
```

The cross compiler must support RV32/ILP32; the executable prefix alone does not
select a 64-bit kernel. The script verifies RV32 and both UART console drivers
in the resolved configuration. Host build dependencies include `bison`, `flex`,
`bc`, OpenSSL and ELF development headers. All new kernel objects stay under
`build/linux/`, and `build/Image` is the resulting common kernel. Recheck the
simulator boot after changing kernel sources or toolchain versions.
