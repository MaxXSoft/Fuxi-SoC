OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
  ROM (rx) : ORIGIN = 0x00000200, LENGTH = 0x3e00
  WORK (rw) : ORIGIN = 0x87ff0000, LENGTH = 0x10000
}
SECTIONS {
  .text : { KEEP(*(.text.start)) *(.text*) *(.rodata*) *(.srodata*) } > ROM
  .data : { *(.data*) *(.sdata*) } > WORK
  .bss (NOLOAD) : {
    . = ALIGN(4); __bss_start = .; *(.bss*) *(.sbss*) *(COMMON)
    . = ALIGN(4); __bss_end = .;
  } > WORK
  __global_pointer$ = ORIGIN(WORK) + 0x800;
  __stack_top = ORIGIN(WORK) + LENGTH(WORK);
  ASSERT(_start == 0x200, "reset entry must match Fuxi reset PC")
  ASSERT((boot_trap & 3) == 0, "mtvec handler must be four-byte aligned")
  ASSERT(SIZEOF(.data) == 0, "ROM must not contain initialized writable data")
  ASSERT(__bss_end + 0x4000 <= __stack_top, "insufficient boot stack")
  /DISCARD/ : { *(.comment*) *(.eh_frame*) }
}
