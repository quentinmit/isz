#include <stdbool.h>
#include <stdint.h>
// size_t and ssize_t are not used in any of the structs we care about, so it's okay if they have the wrong width.
typedef unsigned int size_t;
typedef signed int ssize_t;
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
#include "kgd_pp_interface.h"
