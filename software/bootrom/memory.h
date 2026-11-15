#ifndef FUXISOC_BOOTROM_MEMORY_H_
#define FUXISOC_BOOTROM_MEMORY_H_
#ifndef __ASSEMBLER__

#include <stddef.h>

void *memcpy(void *, const void *, size_t);
void *memmove(void *, const void *, size_t);
void *memset(void *, int, size_t);

#endif  // __ASSEMBLER__
#endif  // FUXISOC_BOOTROM_MEMORY_H_
