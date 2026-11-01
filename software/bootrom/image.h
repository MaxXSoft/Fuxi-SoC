#ifndef FUXI_IMAGE_H
#define FUXI_IMAGE_H
#include <stdint.h>
#include <stddef.h>
#define IMAGE_MAGIC "FUXISOC"
#define IMAGE_VERSION 1u
#define IMAGE_SEGMENTS 3u
#define FLASH_PAYLOAD_OFFSET 0x00800000u
#define FLASH_PAYLOAD_LIMIT 0x00800000u
#define SCRATCH_ADDRESS 0x87000000u
#define SCRATCH_SIZE 0x00800000u
#define OPENSBI_ADDRESS 0x80000000u
#define KERNEL_ADDRESS 0x80400000u
#define DTB_ADDRESS 0x87e00000u
struct image_segment {
    uint32_t address, offset, packed_size, unpacked_size, crc32, codec;
};
struct image_header {
    char magic[8];
    uint32_t version, crc32;
    struct image_segment segments[IMAGE_SEGMENTS];
};
_Static_assert(sizeof(struct image_header) == 88, "image ABI");
uint32_t image_crc32(const void *data, size_t size);
int image_validate(const struct image_header *header);
int image_unpack(const struct image_segment *segment, const void *packed, void *output);
#endif
