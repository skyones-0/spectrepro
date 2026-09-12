/**
 * @file point.h
 *
 * Terminal point types for referencing locations in the terminal grid.
 */

#ifndef SPECTREPRO_VT_POINT_H
#define SPECTREPRO_VT_POINT_H

#include <stdint.h>

#include <spectrepro/vt/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/** @defgroup point Point
 *
 * Types for referencing x/y positions in the terminal grid under
 * different coordinate systems (active area, viewport, full screen,
 * scrollback history).
 *
 * @{
 */

/**
 * A coordinate in the terminal grid.
 *
 * @ingroup point
 */
typedef struct {
  /** Column (0-indexed). */
  uint16_t x;

  /** Row (0-indexed). May exceed page size for screen/history tags. */
  uint32_t y;
} SpectreProPointCoordinate;

/**
 * Point reference tag.
 *
 * Determines which coordinate system a point uses.
 *
 * @ingroup point
 */
typedef enum SPECTREPRO_ENUM_TYPED {
  /** Active area where the cursor can move. */
  SPECTREPRO_POINT_TAG_ACTIVE = 0,

  /** Visible viewport (changes when scrolled). */
  SPECTREPRO_POINT_TAG_VIEWPORT = 1,

  /** Full screen including scrollback. */
  SPECTREPRO_POINT_TAG_SCREEN = 2,

  /** Scrollback history only (before active area). */
  SPECTREPRO_POINT_TAG_HISTORY = 3,
  SPECTREPRO_POINT_TAG_MAX_VALUE = SPECTREPRO_ENUM_MAX_VALUE,
  } SpectreProPointTag;

/**
 * Point value union.
 *
 * @ingroup point
 */
typedef union {
  /** Coordinate (used for all tag variants). */
  SpectreProPointCoordinate coordinate;

  /** Padding for ABI compatibility. Do not use. */
  uint64_t _padding[2];
} SpectreProPointValue;

/**
 * Tagged union for a point in the terminal grid.
 *
 * @ingroup point
 */
typedef struct {
  SpectreProPointTag tag;
  SpectreProPointValue value;
} SpectreProPoint;

/** @} */

#ifdef __cplusplus
}
#endif

#endif /* SPECTREPRO_VT_POINT_H */
