# Fuxi-SoC

Source-built ZedBoard platform for the RV32 Fuxi processor. Vivado 2025.2 builds
an `xc7z020clg484-1` design from Tcl and RTL; generated projects, firmware,
bitstreams and reports live under `build/` and are not versioned.

Initialize the pinned dependencies with `git submodule update --init --recursive`.
`third_party/fuxi` supplies the core, `third_party/embeddedsw` the AMD Zynq FSBL
and standalone drivers, and `third_party/lz4` the boot image codec. Each dependency
retains its own license. This repository's original code is licensed under MIT.

The PS initializes DDR/MIO/clocks, configures the PL, enables QSPI linear reads,
and releases Fuxi. ARM then parks. Fuxi loads OpenSBI, Linux and its device tree
from Flash into DDR. There is no runtime ARM monitor.
