#include "image.h"

#define UART_BASE 0x10000000u
#define FLASH_BASE 0x18000000u

static uint32_t read32(uint32_t address) {
  return *(volatile uint32_t *)(uintptr_t)address;
}

static void putc_uart(char c) {
  while (read32(UART_BASE + 0x2c) & (1u << 4)) {
  }
  *(volatile uint32_t *)(UART_BASE + 0x30) = (unsigned char)c;
}

static void puts_uart(const char *p) {
  while (*p) putc_uart(*p++);
}

static void flash_copy(void *output, uint32_t offset, uint32_t count) {
  unsigned char *dst = output;
  // PS QSPI linear reads are performed as aligned words, including the tail.
  for (uint32_t i = 0; i < count; i += 4) {
    uint32_t word = read32(FLASH_BASE + FLASH_PAYLOAD_OFFSET + offset + i);
    for (unsigned b = 0; b < 4 && i + b < count; ++b) {
      dst[i + b] = (unsigned char)(word >> (8 * b));
    }
  }
}

static void stop(void) {
  puts_uart("Fuxi boot: invalid image; halted\r\n");
  for (;;) __asm__ volatile("wfi");
}

extern void enter_opensbi(void) __attribute__((noreturn));

void boot_main(void) {
  puts_uart("Fuxi ZedBoard boot\r\n");

  struct image_header header;
  flash_copy(&header, 0, sizeof(header));
  if (image_validate(&header)) stop();

  for (unsigned i = 0; i < IMAGE_SEGMENTS; ++i) {
    const struct image_segment *s = &header.segments[i];
    // The on-flash format keeps each compressed block word aligned.
    if (s->offset & 3u) stop();
    flash_copy((void *)SCRATCH_ADDRESS, s->offset, s->packed_size);
    if (image_unpack(s, (void *)SCRATCH_ADDRESS,
                     (void *)(uintptr_t)s->address)) {
      stop();
    }
  }

  puts_uart("Fuxi boot: entering OpenSBI\r\n");
  enter_opensbi();
}
