/**
 * @file sgr.h
 *
 * SGR (Select Graphic Rendition) attribute parsing and handling.
 */

#ifndef SPECTREPRO_VT_SGR_H
#define SPECTREPRO_VT_SGR_H

/** @defgroup sgr SGR Parser
 *
 * SGR (Select Graphic Rendition) attribute parser.
 *
 * SGR sequences are the syntax used to set styling attributes such as
 * bold, italic, underline, and colors for text in terminal emulators.
 * For example, you may be familiar with sequences like `ESC[1;31m`. The
 * `1;31` is the SGR attribute list.
 *
 * The parser processes SGR parameters from CSI sequences (e.g., `ESC[1;31m`)
 * and returns individual text attributes like bold, italic, colors, etc.
 * It supports both semicolon (`;`) and colon (`:`) separators, possibly mixed,
 * and handles SGR color attributes including 8-color, 16-color, 256-color,
 * direct RGB, underline color, and reset forms. Color values are returned
 * using the shared @ref color types; applications that need to parse SpectrePro
 * config/theme color strings, generate palettes, inspect X11 color names, or
 * calculate luminance and contrast should use the @ref color APIs directly.
 *
 * ## Basic Usage
 *
 * 1. Create a parser instance with spectrepro_sgr_new()
 * 2. Set SGR parameters with spectrepro_sgr_set_params()
 * 3. Iterate through attributes using spectrepro_sgr_next()
 * 4. Free the parser with spectrepro_sgr_free() when done
 *
 * ## Example
 *
 * @snippet c-vt-sgr/src/main.c sgr-basic
 *
 * @{
 */

#include <spectrepro/vt/allocator.h>
#include <spectrepro/vt/color.h>
#include <spectrepro/vt/types.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * SGR attribute tags.
 *
 * These values identify the type of an SGR attribute in a tagged union.
 * Use the tag to determine which field in the attribute value union to access.
 *
 * @ingroup sgr
 */
typedef enum SPECTREPRO_ENUM_TYPED {
  SPECTREPRO_SGR_ATTR_UNSET = 0,
  SPECTREPRO_SGR_ATTR_UNKNOWN = 1,
  SPECTREPRO_SGR_ATTR_BOLD = 2,
  SPECTREPRO_SGR_ATTR_RESET_BOLD = 3,
  SPECTREPRO_SGR_ATTR_ITALIC = 4,
  SPECTREPRO_SGR_ATTR_RESET_ITALIC = 5,
  SPECTREPRO_SGR_ATTR_FAINT = 6,
  SPECTREPRO_SGR_ATTR_UNDERLINE = 7,
  SPECTREPRO_SGR_ATTR_UNDERLINE_COLOR = 8,
  SPECTREPRO_SGR_ATTR_UNDERLINE_COLOR_256 = 9,
  SPECTREPRO_SGR_ATTR_RESET_UNDERLINE_COLOR = 10,
  SPECTREPRO_SGR_ATTR_OVERLINE = 11,
  SPECTREPRO_SGR_ATTR_RESET_OVERLINE = 12,
  SPECTREPRO_SGR_ATTR_BLINK = 13,
  SPECTREPRO_SGR_ATTR_RESET_BLINK = 14,
  SPECTREPRO_SGR_ATTR_INVERSE = 15,
  SPECTREPRO_SGR_ATTR_RESET_INVERSE = 16,
  SPECTREPRO_SGR_ATTR_INVISIBLE = 17,
  SPECTREPRO_SGR_ATTR_RESET_INVISIBLE = 18,
  SPECTREPRO_SGR_ATTR_STRIKETHROUGH = 19,
  SPECTREPRO_SGR_ATTR_RESET_STRIKETHROUGH = 20,
  SPECTREPRO_SGR_ATTR_DIRECT_COLOR_FG = 21,
  SPECTREPRO_SGR_ATTR_DIRECT_COLOR_BG = 22,
  SPECTREPRO_SGR_ATTR_BG_8 = 23,
  SPECTREPRO_SGR_ATTR_FG_8 = 24,
  SPECTREPRO_SGR_ATTR_RESET_FG = 25,
  SPECTREPRO_SGR_ATTR_RESET_BG = 26,
  SPECTREPRO_SGR_ATTR_BRIGHT_BG_8 = 27,
  SPECTREPRO_SGR_ATTR_BRIGHT_FG_8 = 28,
  SPECTREPRO_SGR_ATTR_BG_256 = 29,
  SPECTREPRO_SGR_ATTR_FG_256 = 30,
  SPECTREPRO_SGR_ATTR_MAX_VALUE = SPECTREPRO_ENUM_MAX_VALUE,
} SpectreProSgrAttributeTag;

/**
 * Underline style types.
 *
 * @ingroup sgr
 */
typedef enum SPECTREPRO_ENUM_TYPED {
  SPECTREPRO_SGR_UNDERLINE_NONE = 0,
  SPECTREPRO_SGR_UNDERLINE_SINGLE = 1,
  SPECTREPRO_SGR_UNDERLINE_DOUBLE = 2,
  SPECTREPRO_SGR_UNDERLINE_CURLY = 3,
  SPECTREPRO_SGR_UNDERLINE_DOTTED = 4,
  SPECTREPRO_SGR_UNDERLINE_DASHED = 5,
  SPECTREPRO_SGR_UNDERLINE_MAX_VALUE = SPECTREPRO_ENUM_MAX_VALUE,
} SpectreProSgrUnderline;

/**
 * Unknown SGR attribute data.
 *
 * Contains the full parameter list and the partial list where parsing
 * encountered an unknown or invalid sequence.
 *
 * @ingroup sgr
 */
typedef struct {
  const uint16_t* full_ptr;
  size_t full_len;
  const uint16_t* partial_ptr;
  size_t partial_len;
} SpectreProSgrUnknown;

/**
 * SGR attribute value union.
 *
 * This union contains all possible attribute values. Use the tag field
 * to determine which union member is active. Attributes without associated
 * data (like bold, italic) don't use the union value.
 *
 * @ingroup sgr
 */
typedef union {
  SpectreProSgrUnknown unknown;
  SpectreProSgrUnderline underline;
  SpectreProColorRgb underline_color;
  SpectreProColorPaletteIndex underline_color_256;
  SpectreProColorRgb direct_color_fg;
  SpectreProColorRgb direct_color_bg;
  SpectreProColorPaletteIndex bg_8;
  SpectreProColorPaletteIndex fg_8;
  SpectreProColorPaletteIndex bright_bg_8;
  SpectreProColorPaletteIndex bright_fg_8;
  SpectreProColorPaletteIndex bg_256;
  SpectreProColorPaletteIndex fg_256;
  uint64_t _padding[8];
} SpectreProSgrAttributeValue;

/**
 * SGR attribute (tagged union).
 *
 * A complete SGR attribute with both its type tag and associated value.
 * Always check the tag field to determine which value union member is valid.
 *
 * Attributes without associated data (e.g., SPECTREPRO_SGR_ATTR_BOLD) can be
 * identified by tag alone; the value union is not used for these and
 * the memory in the value field is undefined.
 *
 * @ingroup sgr
 */
typedef struct {
  SpectreProSgrAttributeTag tag;
  SpectreProSgrAttributeValue value;
} SpectreProSgrAttribute;

/**
 * Create a new SGR parser instance.
 *
 * Creates a new SGR (Select Graphic Rendition) parser using the provided
 * allocator. The parser must be freed using spectrepro_sgr_free() when
 * no longer needed.
 *
 * @param allocator Pointer to the allocator to use for memory management, or
 * NULL to use the default allocator
 * @param parser Pointer to store the created parser handle
 * @return SPECTREPRO_SUCCESS on success, or an error code on failure
 *
 * @ingroup sgr
 */
SPECTREPRO_API SpectreProResult spectrepro_sgr_new(const SpectreProAllocator* allocator,
                              SpectreProSgrParser* parser);

/**
 * Free an SGR parser instance.
 *
 * Releases all resources associated with the SGR parser. After this call,
 * the parser handle becomes invalid and must not be used. This includes
 * any attributes previously returned by spectrepro_sgr_next().
 *
 * @param parser The parser handle to free (may be NULL)
 *
 * @ingroup sgr
 */
SPECTREPRO_API void spectrepro_sgr_free(SpectreProSgrParser parser);

/**
 * Reset an SGR parser instance to the beginning of the parameter list.
 *
 * Resets the parser's iteration state without clearing the parameters.
 * After calling this, spectrepro_sgr_next() will start from the beginning
 * of the parameter list again.
 *
 * @param parser The parser handle to reset, must not be NULL
 *
 * @ingroup sgr
 */
SPECTREPRO_API void spectrepro_sgr_reset(SpectreProSgrParser parser);

/**
 * Set SGR parameters for parsing.
 *
 * Sets the SGR parameter list to parse. Parameters are the numeric values
 * from a CSI SGR sequence (e.g., for `ESC[1;31m`, params would be {1, 31}).
 *
 * The separators array optionally specifies the separator type for each
 * parameter position. Each byte should be either ';' for semicolon or ':'
 * for colon. This is needed for certain color formats that use colon
 * separators (e.g., `ESC[4:3m` for curly underline). Any invalid separator
 * values are treated as semicolons. The separators array must have the same
 * length as the params array, if it is not NULL.
 *
 * If separators is NULL, all parameters are assumed to be semicolon-separated.
 *
 * This function makes an internal copy of the parameter and separator data,
 * so the caller can safely free or modify the input arrays after this call.
 *
 * After calling this function, the parser is automatically reset and ready
 * to iterate from the beginning.
 *
 * @param parser The parser handle, must not be NULL
 * @param params Array of SGR parameter values
 * @param separators Optional array of separator characters (';' or ':'), or
 * NULL
 * @param len Number of parameters (and separators if provided)
 * @return SPECTREPRO_SUCCESS on success, or an error code on failure
 *
 * @ingroup sgr
 */
SPECTREPRO_API SpectreProResult spectrepro_sgr_set_params(SpectreProSgrParser parser,
                                     const uint16_t* params,
                                     const char* separators,
                                     size_t len);

/**
 * Get the next SGR attribute.
 *
 * Parses and returns the next attribute from the parameter list.
 * Call this function repeatedly until it returns false to process
 * all attributes in the sequence.
 *
 * @param parser The parser handle, must not be NULL
 * @param attr Pointer to store the next attribute
 * @return true if an attribute was returned, false if no more attributes
 *
 * @ingroup sgr
 */
SPECTREPRO_API bool spectrepro_sgr_next(SpectreProSgrParser parser, SpectreProSgrAttribute* attr);

/**
 * Get the full parameter list from an unknown SGR attribute.
 *
 * This function retrieves the full parameter list that was provided to the
 * parser when an unknown attribute was encountered. Primarily useful in
 * WebAssembly environments where accessing struct fields directly is difficult.
 *
 * @param unknown The unknown attribute data
 * @param ptr Pointer to store the pointer to the parameter array (may be NULL)
 * @return The length of the full parameter array
 *
 * @ingroup sgr
 */
SPECTREPRO_API size_t spectrepro_sgr_unknown_full(SpectreProSgrUnknown unknown,
                                const uint16_t** ptr);

/**
 * Get the partial parameter list from an unknown SGR attribute.
 *
 * This function retrieves the partial parameter list where parsing stopped
 * when an unknown attribute was encountered. Primarily useful in WebAssembly
 * environments where accessing struct fields directly is difficult.
 *
 * @param unknown The unknown attribute data
 * @param ptr Pointer to store the pointer to the parameter array (may be NULL)
 * @return The length of the partial parameter array
 *
 * @ingroup sgr
 */
SPECTREPRO_API size_t spectrepro_sgr_unknown_partial(SpectreProSgrUnknown unknown,
                                   const uint16_t** ptr);

/**
 * Get the tag from an SGR attribute.
 *
 * This function extracts the tag that identifies which type of attribute
 * this is. Primarily useful in WebAssembly environments where accessing
 * struct fields directly is difficult.
 *
 * @param attr The SGR attribute
 * @return The attribute tag
 *
 * @ingroup sgr
 */
SPECTREPRO_API SpectreProSgrAttributeTag spectrepro_sgr_attribute_tag(SpectreProSgrAttribute attr);

/**
 * Get the value from an SGR attribute.
 *
 * This function returns a pointer to the value union from an SGR attribute. Use
 * the tag to determine which field of the union is valid. Primarily useful in
 * WebAssembly environments where accessing struct fields directly is difficult.
 *
 * @param attr Pointer to the SGR attribute
 * @return Pointer to the attribute value union
 *
 * @ingroup sgr
 */
SPECTREPRO_API SpectreProSgrAttributeValue* spectrepro_sgr_attribute_value(
    SpectreProSgrAttribute* attr);

#ifdef __cplusplus
}
#endif

/** @} */

#endif /* SPECTREPRO_VT_SGR_H */
