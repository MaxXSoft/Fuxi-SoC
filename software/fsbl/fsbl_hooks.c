// ZedBoard handoff: PS owns initialization; Fuxi owns UART and DDR afterwards.

#include "fsbl.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xqspips.h"

extern XQspiPs QspiInstance;
extern u8 BitstreamFlag;
extern u32 SendBankSelect(u8 bank);

#define GPIO_BASE 0xe000a000u
#define GPIO_DATA2 (GPIO_BASE + 0x048u)
#define GPIO_DIRM2 (GPIO_BASE + 0x284u)
#define GPIO_OEN2 (GPIO_BASE + 0x288u)
#define UART1_BASE 0xe0001000u

u32 FsblHookBeforeBitstreamDload(void) {
  // Keep EMIO0 low before PL configuration, including a warm FSBL restart.
  Xil_Out32(GPIO_DATA2, Xil_In32(GPIO_DATA2) & ~1u);
  Xil_Out32(GPIO_DIRM2, Xil_In32(GPIO_DIRM2) | 1u);
  Xil_Out32(GPIO_OEN2, Xil_In32(GPIO_OEN2) | 1u);
  return XST_SUCCESS;
}

u32 FsblHookAfterBitstreamDload(void) { return XST_SUCCESS; }

u32 FsblHookBeforeHandoff(void) {
  // BOOT.BIN contains FSBL + bitstream only and must be booted from QSPI.
  if ((Xil_In32(BOOT_MODE_REG) & BOOT_MODES_MASK) != QSPI_MODE) {
    return XST_FAILURE;
  }
  if (!BitstreamFlag) return XST_FAILURE;

  // FSBL uses I/O mode on the 32 MiB S25FL256S. Restore bank 0, then expose
  // a 16 MiB linear window. 0x0b single-lane fast read needs no quad-enable
  // bit.
  if (SendBankSelect(0) != XST_SUCCESS) return XST_FAILURE;

  XQspiPs_Disable(&QspiInstance);
  if (XQspiPs_SetOptions(&QspiInstance, XQSPIPS_LQSPI_MODE_OPTION |
                                            XQSPIPS_HOLD_B_DRIVE_OPTION) !=
      XST_SUCCESS) {
    return XST_FAILURE;
  }
  XQspiPs_SetLqspiConfigReg(&QspiInstance,
                            XQSPIPS_LQSPI_CR_LINEAR_MASK | 0x10bu);
  XQspiPs_Enable(&QspiInstance);

  // Return UART to polling operation; OpenSBI/Linux configure their own IRQs.
  Xil_Out32(UART1_BASE + 0x0c, 0xffffffffu);
  Xil_Out32(UART1_BASE + 0x14, 0xffffffffu);
  xil_printf("FSBL: releasing Fuxi at 50 MHz\r\n");
  while (!(Xil_In32(UART1_BASE + 0x2c) & (1u << 3))) {
  }

  Xil_DCacheFlush();
  __asm__ volatile("dsb sy" ::: "memory");
  Xil_Out32(GPIO_DATA2, Xil_In32(GPIO_DATA2) | 1u);
  __asm__ volatile("dsb sy" ::: "memory");

  // With no ARM application, upstream FSBL stops its watchdog and enters
  // FsblHandoffJtagExit's WFE loop. No ARM code accesses Fuxi's DDR allocation.
  return XST_SUCCESS;
}

void FsblHookFallback(void) {
  Xil_Out32(GPIO_DATA2, Xil_In32(GPIO_DATA2) & ~1u);
  xil_printf("FSBL: Fuxi handoff failed\r\n");
  for (;;) __asm__ volatile("wfe");
}
