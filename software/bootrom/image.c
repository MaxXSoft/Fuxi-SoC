#include "image.h"

#include "lz4.h"

uint32_t image_crc32(const void *data, size_t size) {
  const unsigned char *p = data;
  uint32_t crc = ~0u;
  while (size--) {
    crc ^= *p++;
    for (unsigned bit = 0; bit < 8; ++bit)
      crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1u)));
  }
  return ~crc;
}

int image_validate(const struct image_header *h) {
  static const uint32_t addresses[] = {OPENSBI_ADDRESS, KERNEL_ADDRESS,
                                       DTB_ADDRESS};
  static const uint32_t limits[] = {0x400000, SCRATCH_ADDRESS - KERNEL_ADDRESS,
                                    0x100000};
  static const char magic[8] = IMAGE_MAGIC;
  struct image_header copy = *h;
  for (unsigned i = 0; i < sizeof(magic); ++i)
    if (h->magic[i] != magic[i]) return -1;
  if (h->version != IMAGE_VERSION) return -2;
  copy.crc32 = 0;
  if (image_crc32(&copy, sizeof(copy)) != h->crc32) return -3;
  uint32_t previous_end = sizeof(*h);
  for (unsigned i = 0; i < IMAGE_SEGMENTS; ++i) {
    const struct image_segment *s = &h->segments[i];
    if (s->address != addresses[i] || !s->unpacked_size ||
        s->unpacked_size > limits[i])
      return -4;
    if (s->codec > 1 || !s->packed_size || s->packed_size > SCRATCH_SIZE ||
        (s->codec == 0 && s->packed_size != s->unpacked_size))
      return -5;
    if (s->offset < previous_end || s->offset > FLASH_PAYLOAD_LIMIT ||
        s->packed_size > FLASH_PAYLOAD_LIMIT - s->offset)
      return -6;
    previous_end = s->offset + s->packed_size;
  }
  return 0;
}

int image_unpack(const struct image_segment *s, const void *packed,
                 void *output) {
  if (s->codec == 1) {
    int n = LZ4_decompress_safe(packed, output, (int)s->packed_size,
                                (int)s->unpacked_size);
    if (n < 0 || (uint32_t)n != s->unpacked_size) return -1;
  } else {
    const unsigned char *src = packed;
    unsigned char *dst = output;
    for (uint32_t i = 0; i < s->unpacked_size; ++i) dst[i] = src[i];
  }
  return image_crc32(output, s->unpacked_size) == s->crc32 ? 0 : -2;
}
