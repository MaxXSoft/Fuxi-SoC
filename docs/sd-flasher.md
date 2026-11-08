# Program Fuxi QSPI from an SD card

This maintenance environment boots **only the Zynq PS** from SD and uses U-Boot
to program the existing Fuxi Flash image. Neither JTAG, Vivado, `hw_server`, a
network connection, nor an ARM Linux installation is needed on the board.
Fuxi's normal QSPI boot path is unchanged.

## Files and startup

Extract `build/sd-flasher/zedboard-sd-flasher.zip` to the root of the **first
FAT32 partition on an MBR-partitioned SD card**. These four files are required:

| File | Purpose |
| --- | --- |
| `BOOT.BIN` | U-Boot SPL, including the Zynq BootROM header and upstream ZedBoard PS/DDR initialization |
| `u-boot.img` | U-Boot proper and its ZedBoard **ARM** device tree, loaded by SPL from SD |
| `flash.bin` | Complete **Fuxi QSPI image**, including its custom ARM FSBL, PL bitstream and RISC-V software payload |
| `flash-fuxi.scr` | Manually invoked update script bound to this particular `flash.bin` by size and SHA-256 |

`BOOT.BIN` alone is not sufficient: keep `u-boot.img` beside it. Do not replace
this SD `BOOT.BIN` with `build/flash/BOOT.BIN`, and do not write the SD SPL image
to QSPI. The normal Fuxi image is `flash.bin` and is written at QSPI offset zero.
The other files in the ZIP are documentation, configuration, licenses and checksums.
Use `shasum -a 256 -c SHA256SUMS` on macOS (or `sha256sum -c SHA256SUMS` on Linux)
to check the extracted files.

An ordinary 4–32 GB SD card with one FAT32 partition is convenient. No ext4
partition or root filesystem is needed. On macOS, Disk Utility's **Show All
Devices** exposes the whole card; when preparing an expendable card, choose
**MS-DOS (FAT)** and **Master Boot Record**, not exFAT or GUID. Formatting erases
the selected card. Copy the files normally; the ZIP and `BOOT.BIN` are not raw
whole-disk images. Safely eject the card before inserting it in the ZedBoard.

Connect the 12 V supply and **J14/UART** to a serial terminal at **115200 8N1,
no flow control**. J17/PROG is not needed. With power off, set the mode jumpers:

| Boot mode | JP7 | JP8 | JP9 | JP10 | JP11 |
| --- | --- | --- | --- | --- | --- |
| SD maintenance | GND | GND | 3V3 | 3V3 | GND |
| QSPI Fuxi | GND | GND | GND | 3V3 | GND |

Use the board's GND/3V3 labels rather than guessing pin numbers. Power on in SD
mode, keeping JP6 in its factory shorted position for SD boot. Expect `U-Boot
SPL`, then `U-Boot`, then an interactive prompt. Autoboot,
preboot commands, SPL bitstream loading and persistent environment storage are
disabled. Booting this card does not automatically program Flash or launch Fuxi.

## Program and verify

At the U-Boot prompt, this command explicitly starts the Flash update:

```text
fatload mmc 0:1 0x02000000 flash-fuxi.scr && source 0x02000000
```

The script checks the SD file's exact size, loads it to DDR at `0x10000000`,
checks SHA-256, probes QSPI, then runs `sf update` at offset 0. The package only
accepts Fuxi images within the first 16 MiB, with a Zynq header and a Fuxi payload
at offset 8 MiB. The script reads the programmed bytes back into DDR at
`0x12000000` and compares every byte. These buffers do not overlap each other,
the script at `0x02000000`, or U-Boot's relocated image near the top of 512 MiB DDR.
QSPI update erases/writes affected sectors; padding in the final sector can be
erased too. Do not interrupt power during the update.

Only **`FUXI_FLASH_VERIFY_PASS`** indicates a successful update and readback.
Any `FAIL` message means stop and inspect the preceding error; do not continue
with later commands from another recipe. A hash/size error before `sf update`
leaves Flash unchanged. A write or readback error can leave a partial image;
SD maintenance boot remains available to retry.

After PASS, **power off**, select QSPI boot, and power on. Removing the SD card
is optional. A cold power cycle also resets the Flash addressing state. Do not
use the PL-only PROG button to switch the PS boot source.

Expected normal boot: `FSBL: releasing Fuxi at 50 MHz`, `Fuxi ZedBoard boot`,
OpenSBI, Linux, then the initramfs shell. This procedure does not add SD storage
support to Fuxi Linux. The maintenance U-Boot's device tree and PS initialization
are independent of the Fuxi runtime device tree and custom FSBL.

## Rebuild

The U-Boot source is pinned by the `third_party/u-boot` submodule (v2026.04).
SPL uses `board/xilinx/zynq/zynq-zed/ps7_init_gpl.c`; no generated XSA, AMD FSBL
or Bootgen is used for the SD bootloader. On Linux, install GNU make, a native C
compiler, an ARM bare-metal cross compiler, Python 3, bison, flex, pkg-config and
OpenSSL development headers. For example on Ubuntu:

```sh
apt-get install --no-install-recommends build-essential gcc-arm-none-eabi \
    python3 bison flex pkg-config libssl-dev
git -c core.symlinks=true submodule update --init third_party/u-boot
make sd-flasher
```

`make sd-flasher` builds U-Boot and packages the existing `build/flash/flash.bin`.
An alternate compiler prefix can be set with `UBOOT_CROSS_COMPILE=arm-linux-gnueabihf-`.
Outputs stay under ignored `build/sd-flasher/`. To package a new Fuxi image
without rebuilding U-Boot:

```sh
make sd-flasher-package FLASH_IMAGE=/absolute/path/to/flash.bin
```

Copy **both** the regenerated `flash.bin` and `flash-fuxi.scr` to SD. Their size
and hash must agree. The generated manifest records package checksums, resolved
U-Boot version, and the lack of physical-board validation. `make test-sd-flasher`
checks package validation and update failure handling using host command stubs;
it does not emulate Zynq hardware or prove a board boots.

The packager preserves the upstream SPL code/header and pads the file through
the end declared in its BootROM load-length field. This accommodates v2026.04
`mkimage` counting the header in that length, without relying on an SD read past
EOF. Both the header checksum and the declared load bounds are checked.

## References

- [U-Boot Zynq board and SD boot documentation](https://docs.u-boot.org/en/latest/board/xilinx/zynq.html)
- [Zephyr's ZedBoard U-Boot SPL procedure](https://docs.zephyrproject.org/latest/boards/digilent/zedboard/doc/index.html)
- [U-Boot sf update/read commands](https://docs.u-boot.org/en/latest/usage/cmd/sf.html)
- [ZedBoard hardware guide](https://files.digilent.com/resources/programmable-logic/zedboard/ZedBoard_HW_UG_v2_2.pdf)
- [ADI ZedBoard SD jumper table](https://developer.analog.com/docs/system-level/solutions/reference-designs/eval-ad9265/quickstart/zed.html)

The build/configuration checks and host regressions do not constitute physical
board validation. First use must verify SPL DDR initialization, SD loading,
the detected QSPI model/capacity and final readback on the actual ZedBoard.
