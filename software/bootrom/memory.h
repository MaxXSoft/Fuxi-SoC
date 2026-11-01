#ifndef FUXI_MEMORY_H
#define FUXI_MEMORY_H
#ifndef __ASSEMBLER__
#include <stddef.h>
void *memcpy(void *, const void *, size_t);
void *memmove(void *, const void *, size_t);
void *memset(void *, int, size_t);
#endif
#endif
