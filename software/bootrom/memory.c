#include "memory.h"

void *memcpy(void *d, const void *s, size_t n) {
  unsigned char *dst = d;
  const unsigned char *src = s;
  while (n--) *dst++ = *src++;
  return d;
}

void *memmove(void *d, const void *s, size_t n) {
  unsigned char *dst = d;
  const unsigned char *src = s;
  if (dst < src) return memcpy(d, s, n);
  while (n) {
    --n;
    dst[n] = src[n];
  }
  return d;
}

void *memset(void *d, int v, size_t n) {
  unsigned char *dst = d;
  while (n--) *dst++ = (unsigned char)v;
  return d;
}
