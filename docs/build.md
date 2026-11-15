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
`PYTHON=/path/to/python3` selects the interpreter for both the Makefile's Python
commands and this Tcl-invoked helper. Standalone Tcl invocation defaults to
`python3` unless `PYTHON` is set in the environment.

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
`make test` also runs the SD flasher's host validation and failure-path checks.
With `UBOOT_SANDBOX=/path/to/sandbox/u-boot`, it additionally runs the real U-Boot
interpreter regression; otherwise it prints an explicit skip message for that
regression. See [the sandbox requirements](sd-flasher.md#rebuild-the-maintenance-package).

## Local Vivado build

On x86-64 Linux, configure the installed Vivado environment and build directly:

```sh
source /path/to/Vivado/settings64.sh
make fpga RISCV_CC=clang RISCV_OBJCOPY=llvm-objcopy RISCV_LD=ld.lld
```

`make project` and `make fpga` generate the RTL and Boot ROM locally by default;
no remote server or container is required. `make prepare` remains useful for
preparing portable inputs (including the DTB) without running Vivado. The default
`make` target is still `prepare`.

`make fpga` then creates a fresh project, validates the block design, synthesizes,
places, routes, writes the bitstream and exports the hardware platform.
Implementation uses Vivado's `Performance_ExplorePostRoutePhysOpt` strategy:
Explore placement/routing followed by physical optimization using routed
delays. The PS fabric clock remains 50 MHz; this does not add pipeline stages
or relax timing constraints. Use the final `build/reports/` results, which
include post-route optimization, rather than the intermediate routed checkpoint.

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

## Optional remote Vivado build

Inputs can also be prepared on another machine, such as an ARM64 Mac. Use rsync,
including submodule working trees, to transfer the sources and portable inputs:

```sh
make prepare RISCV_CC=clang RISCV_OBJCOPY=llvm-objcopy RISCV_LD=ld.lld
make sync REMOTE=my-server REMOTE_DIR=/host/path/Fuxi-SoC
ssh my-server 'bash -lc "source /path/to/Vivado/settings64.sh; cd /host/path/Fuxi-SoC; make fpga PREPARED_INPUTS=1"'
```

`PREPARED_INPUTS=1` uses existing RTL/ROM files without invoking sbt or the RISC-V
toolchain. Both inputs must exist and must match the intended source/configuration;
rerun `make prepare` and `make sync` after changing them. This mode also works for
already prepared inputs on a single machine.

If Vivado is installed inside a container, the final command can instead be:

```sh
ssh my-server 'docker exec my-container bash -lc "source /opt/AMD/2025.2/Vivado/settings64.sh; cd /container/path/Fuxi-SoC; make fpga PREPARED_INPUTS=1"'
```

`REMOTE_DIR` is the path on the SSH host, which may differ from the path inside
the container. `make sync` does not delete remote files. It excludes `.git`, sbt
targets and generated build outputs, and transfers the prepared portable RTL/ROM
inputs separately.

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
are checked against the 16 MiB bank-0 boundary. It also writes
`build/flash/flash.meta` with the image length and SHA-256 for the reusable SD
updater. `flash.bin` is a raw Flash image, not an SD-card filesystem image.
Program it at QSPI offset 0 using the board's
normal Flash-programming workflow, then select QSPI boot mode and reset.

For a Mac-only programming workstation, [the SD maintenance flow](sd-flasher.md)
boots U-Boot on the PS and programs/verifies `flash.bin` from SD. It needs no
JTAG connection, USB forwarding or Vivado during programming. `make sd-flasher`
builds its independent SPL/U-Boot boot environment from the pinned submodule.

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
