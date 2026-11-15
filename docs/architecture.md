# ZedBoard platform contract

## Hardware

The target is ZedBoard's XC7Z020-CLG484-1. The default Fuxi configuration is
selected by `make prepare`; FCLK0, the core, its interconnect and CLINT timebase
run at 50 MHz. The PS board preset supplies DDR3 and MIO pin/clock settings.
UART1 is the board's USB serial interface. SD, Ethernet, USB, HDMI, audio and
runtime Flash programming are outside this initial platform.

Three Fuxi AXI4 masters feed AMD AXI Interconnect, with register slices and
automatic AXI4-to-AXI3/AXI4-Lite conversion. The PS S_AXI_GP0 port provides the
DDR and PS peripheral access. This first implementation favors simplicity over
DDR bandwidth; it does not use an HP port. FuxiWrapper's AXI3-style WID outputs
are unused at the AXI4 boundary; the interconnect generates the AXI3 WID needed
by the PS.

| Fuxi physical address | Size | Target | PS/bus address |
| --- | --- | --- | --- |
| `0x00000000` | 16 KiB | Boot ROM, reset PC `0x200` | unchanged |
| `0x10000000` | 4 KiB | PS Cadence UART1 | `0xe0001000` |
| `0x11000000` | 64 KiB | CLINT, hart 0 | unchanged |
| `0x12000000` | 4 MiB | PLIC, 31 sources, M/S contexts | unchanged |
| `0x18000000` | 16 MiB | QSPI linear bank 0, read only | `0xfc000000` |
| `0x80000000` | 128 MiB | DDR for Fuxi | `0x08000000` |

Translation occurs **after** the core's cacheability decision. All MMIO lies in
Fuxi's default uncached interval `[0x10000000, 0x20000000)`. The address editor
contains translated bus addresses; the device tree contains Fuxi addresses.
These mappings are a platform convention, not an isolation boundary: software
must not use unadvertised PS-address aliases. PS software must not use DDR
`[0x08000000, 0x10000000)` after releasing Fuxi.

Boot ROM uses inferred block RAM behind AMD AXI BRAM Controller. Reads support
cache-line bursts; writes are acknowledged by the controller and ignored by the
ROM. ROM changes require a new bitstream.

CLINT implements `msip` at `0`, `mtimecmp` at `0x4000` and `mtime` at `0xbff8`.
Its 64-bit `mtime` also drives the core's `time/timeh` CSR input. Both halves of
the timer are writable, with byte strobes; `mtimecmp` resets to all ones.
The timer IRQ is registered and reflects changes one cycle later.

PLIC implements priorities 0–7, pending bits, per-context enables, threshold,
and claim/complete at standard offsets. Context 0 is M-mode and context 1 is
S-mode. Source 10 is PS UART1's dedicated `IRQ_P2F_UART1` signal; other sources
are tied low. Inputs pass through two synchronizer stages. Gateways are level
sensitive and do not accept another request until completion. Claim clears the
shared pending bit atomically and ignores threshold, while notification obeys
threshold. Lowest source ID wins ties. A five-level balanced arbitration tree computes
the winning request; CPU-facing notifications are registered with one cycle of
latency so arbitration does not extend the core's trap-selection path. Registers use aligned 32-bit accesses;
completion requires all four write strobes. Reserved reads return zero.

## Boot sequence

1. Zynq BootROM reads `BOOT.BIN` from QSPI and starts the ARM FSBL.
2. Upstream FSBL uses **the PS initialization exported from this design's XSA**,
   initializes DDR/MIO/clocks and loads the bitstream. Its before-bitstream hook
   keeps EMIO GPIO0 low so Fuxi stays in reset.
3. The handoff hook selects Flash bank 0, enables the 16 MiB QSPI linear window
   using single-lane fast-read command `0x0b` (no quad-enable dependency), disables
   UART interrupts, flushes the ARM cache and raises EMIO GPIO0.
4. The synchronized reset controller releases the core, CLINT and PLIC. The ARM
   FSBL stops its watchdog and enters its existing WFE loop because BOOT.BIN has
   no ARM application partition. CPU1 remains parked by Zynq's boot flow.
5. Fuxi starts at `0x200`, checks the payload header and loads/decompresses
   OpenSBI, Linux and DTB. Each output has a CRC32 check. It executes `fence` and
   `fence.i`, then enters OpenSBI with `a0=hartid`, `a1=DTB`, `a2=0`.
6. Generic OpenSBI FW_JUMP enters the kernel at `0x80400000`. Linux uses CLINT,
   PLIC and the PS UART directly, with an initramfs for its initial rootfs.

This is a **QSPI cold-boot** flow. Loading only the bitstream by JTAG will leave
Fuxi in reset; FSBL must configure the PS and perform the handoff. The design
has no runtime monitor, Exit register, reset-service register, or warm-restart
protocol. Linux shutdown can halt, but cannot currently turn off or reboot the
board. Restart through a board reset. Do not toggle EMIO0 on a running system:
AXI transactions must first be quiesced for a supported warm-reset design.

## Flash and DDR image layout

`software/bootrom/image_layout.json` is the shared definition of image magic,
version, segment destinations/limits, scratch storage and Flash allocation.
Host tools read it through `scripts/image_layout.py`; Boot ROM builds and host
decoder tests generate their own `image_layout.h` under `build/` for C and
assembly. The SD packager renders the same layout into `flash-fuxi.cmd` from
`software/flasher/flash-fuxi.cmd.in`. Generated headers/scripts are not checked in.
Layout changes must also respect the platform mappings, Linux reservations and
external OpenSBI build settings described here.

The first 16 MiB of the 32 MiB Flash is used:

| Flash offset | Contents |
| --- | --- |
| `0x00000000`–`0x007fffff` | AMD BOOT.BIN: custom FSBL + bitstream |
| `0x00800000`–`0x00ffffff` | Fuxi payload container |

Payload format v1 is little endian: 8-byte magic `FUXISOC\0`, version `u32`,
header CRC32 `u32`, then three 24-byte records. Each record consists of six
`u32`s: destination, offset relative to payload, compressed length, output
length, output CRC32, codec (`0=raw`, `1=LZ4 raw block`). Header CRC32 is computed
over all 88 bytes with its CRC field zeroed. Offsets are word aligned. Records
are ordered, non-overlapping and constrained to the layout below. CRCs detect
corruption; they do not authenticate images.

| Fuxi DDR address | Use |
| --- | --- |
| `0x80000000`–`0x803fffff` | OpenSBI, reserved from Linux |
| `0x80400000`–`0x86ffffff` | Linux Image, including optional built-in initramfs |
| `0x87000000`–`0x877fffff` | temporary compressed-input buffer |
| `0x87e00000`–`0x87efffff` | DTB |
| `0x87ff0000`–`0x87ffffff` | loader BSS and stack |

Scratch and stack can be reclaimed after the loader exits. Keep an uncompressed
Linux `Image` as input; the packer performs its own LZ4 compression. OpenSBI does
not read Flash itself. Bank switching and decompression do not need to be added
to verilator-axi-testbench: it may keep its current ROM/loading process.

## Sharing software with the testbench

The RISC-V ISA, RAM base/size, OpenSBI entry, kernel entry and DTB address match
the existing Fuxi-Linux flow. Build **one** kernel with both 8250 and Cadence UART
drivers, and use the appropriate DTB. Merge `software/linux/zedboard.config` with
the Fuxi-Linux configuration. Existing kernels built only with 8250 will not have
a working board console. Generic OpenSBI must include its Cadence UART FDT
support (enabled in the normal generic configuration).

Use RV32 generic OpenSBI with `FW_TEXT_START=0x80000000`,
`FW_JUMP_ADDR=0x80400000`, `FW_JUMP_FDT_ADDR=0x87e00000`. The board DTB deliberately
omits the simulator's syscon Exit/poweroff device and requests the Fuxi-Linux
interactive initramfs shell. FSBL and the board ROM are platform-specific;
OpenSBI, the kernel and userspace can be common.

PS UART clocks are fixed by FSBL (reference 50 MHz, APB approximately 111 MHz).
The device tree uses fixed-clock providers, so an ARM-specific SLCR clock driver
is not required on RISC-V. DMA is not part of this UART-only peripheral set.
Adding SD/Ethernet later requires address translation, interrupt routing and
cache-coherency work for DMA, not just new device-tree nodes.
