#ifndef FUXISOC_BOOTROM_IMAGE_H_
#define FUXISOC_BOOTROM_IMAGE_H_

#include <stddef.h>
#include <stdint.h>

#include "image_layout.h"

struct image_segment {
  uint32_t address, offset, packed_size, unpacked_size, crc32, codec;
};

struct image_header {
  char magic[8];
  uint32_t version, crc32;
  struct image_segment segments[IMAGE_SEGMENTS];
};

_Static_assert(sizeof(struct image_header) == IMAGE_HEADER_SIZE, "image ABI");

uint32_t image_crc32(const void *data, size_t size);
int image_validate(const struct image_header *header);
int image_unpack(const struct image_segment *segment, const void *packed,
                 void *output);

#endif  // FUXISOC_BOOTROM_IMAGE_H_
