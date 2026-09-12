/**
 * @file style.h
 *
 * Terminal cell style types.
 */

#ifndef SPECTREPRO_VT_STYLE_H
#define SPECTREPRO_VT_STYLE_H

#include <spectrepro/vt/color.h>
#include <spectrepro/vt/types.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** @defgroup style Style
 *
 * Terminal cell style attributes.
 *
 * A style describes the visual attributes of a terminal cell, including
 * foreground, background, and underline colors, as well as flags for
 * bold, italic, underline, and other text decorations.
 *
 * @{
 */

/**
 * Style identifier type.
 *
 * Used to look up the full style from a grid reference.
 * Obtain this from a cell via SPECTREPRO_CELL_DATA_STYLE_ID.
 *
 * @ingroup style
 */
typedef uint16_t SpectreProStyleId;

/**
 * Style color tags.
 *
 * These values identify the type of color in a style color.
 * Use the tag to determine which field in the color value union to access.
 *
 * @ingroup style
 */
typedef enum SPECTREPRO_ENUM_TYPED {
  SPECTREPRO_STYLE_COLOR_NONE = 0,
  SPECTREPRO_STYLE_COLOR_PALETTE = 1,
  SPECTREPRO_STYLE_COLOR_RGB = 2,
  SPECTREPRO_STYLE_COLOR_TAG_MAX_VALUE = SPECTREPRO_ENUM_MAX_VALUE,
  } SpectreProStyleColorTag;

/**
 * Style color value union.
 *
 * Use the tag to determine which field is active.
 *
 * @ingroup style
 */
typedef union {
  SpectreProColorPaletteIndex palette;
  SpectreProColorRgb rgb;
  uint64_t _padding;
} SpectreProStyleColorValue;

/**
 * Style color (tagged union).
 *
 * A color used in a style attribute. Can be unset (none), a palette
 * index, or a direct RGB value.
 *
 * @ingroup style
 */
typedef struct {
  SpectreProStyleColorTag tag;
  SpectreProStyleColorValue value;
} SpectreProStyleColor;

/**
 * Terminal cell style.
 *
 * Describes the complete visual style for a terminal cell, including
 * foreground, background, and underline colors, as well as text
 * decoration flags. The underline field uses the same values as
 * SpectreProSgrUnderline.
 *
 * This is a sized struct. Use SPECTREPRO_INIT_SIZED() to initialize it.
 *
 * @ingroup style
 */
typedef struct {
  size_t size;
  SpectreProStyleColor fg_color;
  SpectreProStyleColor bg_color;
  SpectreProStyleColor underline_color;
  bool bold;
  bool italic;
  bool faint;
  bool blink;
  bool inverse;
  bool invisible;
  bool strikethrough;
  bool overline;
  int underline; /**< One of SPECTREPRO_SGR_UNDERLINE_* values */
} SpectreProStyle;

/**
 * Get the default style.
 *
 * Initializes the style to the default values (no colors, no flags).
 *
 * @param style Pointer to the style to initialize
 *
 * @ingroup style
 */
SPECTREPRO_API void spectrepro_style_default(SpectreProStyle* style);

/**
 * Check if a style is the default style.
 *
 * Returns true if all colors are unset and all flags are off.
 *
 * @param style Pointer to the style to check
 * @return true if the style is the default style
 *
 * @ingroup style
 */
SPECTREPRO_API bool spectrepro_style_is_default(const SpectreProStyle* style);

#ifdef __cplusplus
}
#endif

/** @} */

#endif /* SPECTREPRO_VT_STYLE_H */
