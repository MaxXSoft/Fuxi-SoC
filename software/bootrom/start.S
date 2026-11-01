.section .text.start, "ax"
.global _start
_start:
    csrw mie, zero
    csrw mip, zero
    la sp, __stack_top
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop
    la t0, boot_trap
    csrw mtvec, t0
    la t0, __bss_start
    la t1, __bss_end
1:  bgeu t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b
2:  call boot_main
    # mtvec uses its low two bits for MODE, even when RVC is enabled.
    .balign 4
.global boot_trap
boot_trap:
    csrci mstatus, 8
3:  wfi
    j 3b
.global enter_opensbi
enter_opensbi:
    fence rw, rw
    fence.i
    li t0, 0x80000000
    csrr a0, mhartid
    li a1, 0x87e00000
    li a2, 0
    jr t0
