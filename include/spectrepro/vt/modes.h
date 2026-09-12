/**
 * @file modes.h
 *
 * Terminal mode utilities - pack and unpack ANSI/DEC mode identifiers.
 */

#ifndef SPECTREPRO_VT_MODES_H
#define SPECTREPRO_VT_MODES_H

/** @defgroup modes Mode Utilities
 *
 * Utilities for working with terminal modes. A mode is a compact
 * 16-bit representation of a terminal mode identifier that encodes both
 * the numeric mode value (up to 15 bits) and whether the mode is an ANSI
 * mode or a DEC private mode (?-prefixed).
 *
 * The packed layout (least-significant bit first) is:
 * - Bits 0–14: mode value (u15)
 * - Bit 15: ANSI flag (0 = DEC private mode, 1 = ANSI mode)
 *
 * ## Example
 *
 * @snippet c-vt-modes/src/main.c modes-pack-unpack
 *
 * ## DECRPM Report Encoding
 *
 * Use spectrepro_mode_report_encode() to encode a DECRPM response into a
 * caller-provided buffer:
 *
 * @snippet c-vt-modes/src/main.c modes-decrpm
 *
 * @{
 */

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include <spectrepro/vt/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/** @name ANSI Modes
 * Modes for standard ANSI modes.
 * @{
 */
#define SPECTREPRO_MODE_KAM              (spectrepro_mode_new(2, true))    /**< Keyboard action (disable keyboard) */
#define SPECTREPRO_MODE_INSERT           (spectrepro_mode_new(4, true))    /**< Insert mode */
#define SPECTREPRO_MODE_SRM              (spectrepro_mode_new(12, true))   /**< Send/receive mode */
#define SPECTREPRO_MODE_LINEFEED         (spectrepro_mode_new(20, true))   /**< Linefeed/new line mode */
/** @} */

/** @name DEC Private Modes
 * Modes for DEC private modes (?-prefixed).
 * @{
 */
#define SPECTREPRO_MODE_DECCKM           (spectrepro_mode_new(1, false))   /**< Cursor keys */
#define SPECTREPRO_MODE_132_COLUMN       (spectrepro_mode_new(3, false))   /**< 132/80 column mode */
#define SPECTREPRO_MODE_SLOW_SCROLL      (spectrepro_mode_new(4, false))   /**< Slow scroll */
#define SPECTREPRO_MODE_REVERSE_COLORS   (spectrepro_mode_new(5, false))   /**< Reverse video */
#define SPECTREPRO_MODE_ORIGIN           (spectrepro_mode_new(6, false))   /**< Origin mode */
#define SPECTREPRO_MODE_WRAPAROUND       (spectrepro_mode_new(7, false))   /**< Auto-wrap mode */
#define SPECTREPRO_MODE_AUTOREPEAT       (spectrepro_mode_new(8, false))   /**< Auto-repeat keys */
#define SPECTREPRO_MODE_X10_MOUSE        (spectrepro_mode_new(9, false))   /**< X10 mouse reporting */
#define SPECTREPRO_MODE_CURSOR_BLINKING  (spectrepro_mode_new(12, false))  /**< Cursor blink */
#define SPECTREPRO_MODE_CURSOR_VISIBLE   (spectrepro_mode_new(25, false))  /**< Cursor visible (DECTCEM) */
#define SPECTREPRO_MODE_ENABLE_MODE_3    (spectrepro_mode_new(40, false))  /**< Allow 132 column mode */
#define SPECTREPRO_MODE_REVERSE_WRAP     (spectrepro_mode_new(45, false))  /**< Reverse wrap */
#define SPECTREPRO_MODE_ALT_SCREEN_LEGACY (spectrepro_mode_new(47, false)) /**< Alternate screen (legacy) */
#define SPECTREPRO_MODE_KEYPAD_KEYS      (spectrepro_mode_new(66, false))  /**< Application keypad */
#define SPECTREPRO_MODE_BACKARROW_KEY_MODE (spectrepro_mode_new(67, false))  /**< Backarrow key mode (DECBKM) */
#define SPECTREPRO_MODE_LEFT_RIGHT_MARGIN (spectrepro_mode_new(69, false)) /**< Left/right margin mode */
#define SPECTREPRO_MODE_NORMAL_MOUSE     (spectrepro_mode_new(1000, false)) /**< Normal mouse tracking */
#define SPECTREPRO_MODE_BUTTON_MOUSE     (spectrepro_mode_new(1002, false)) /**< Button-event mouse tracking */
#define SPECTREPRO_MODE_ANY_MOUSE        (spectrepro_mode_new(1003, false)) /**< Any-event mouse tracking */
#define SPECTREPRO_MODE_FOCUS_EVENT      (spectrepro_mode_new(1004, false)) /**< Focus in/out events */
#define SPECTREPRO_MODE_UTF8_MOUSE       (spectrepro_mode_new(1005, false)) /**< UTF-8 mouse format */
#define SPECTREPRO_MODE_SGR_MOUSE        (spectrepro_mode_new(1006, false)) /**< SGR mouse format */
#define SPECTREPRO_MODE_ALT_SCROLL       (spectrepro_mode_new(1007, false)) /**< Alternate scroll mode */
#define SPECTREPRO_MODE_URXVT_MOUSE      (spectrepro_mode_new(1015, false)) /**< URxvt mouse format */
#define SPECTREPRO_MODE_SGR_PIXELS_MOUSE (spectrepro_mode_new(1016, false)) /**< SGR-Pixels mouse format */
#define SPECTREPRO_MODE_NUMLOCK_KEYPAD   (spectrepro_mode_new(1035, false)) /**< Ignore keypad with NumLock */
#define SPECTREPRO_MODE_ALT_ESC_PREFIX   (spectrepro_mode_new(1036, false)) /**< Alt key sends ESC prefix */
#define SPECTREPRO_MODE_ALT_SENDS_ESC    (spectrepro_mode_new(1039, false)) /**< Alt sends escape */
#define SPECTREPRO_MODE_REVERSE_WRAP_EXT (spectrepro_mode_new(1045, false)) /**< Extended reverse wrap */
#define SPECTREPRO_MODE_ALT_SCREEN       (spectrepro_mode_new(1047, false)) /**< Alternate screen */
#define SPECTREPRO_MODE_SAVE_CURSOR      (spectrepro_mode_new(1048, false)) /**< Save cursor (DECSC) */
#define SPECTREPRO_MODE_ALT_SCREEN_SAVE  (spectrepro_mode_new(1049, false)) /**< Alt screen + save cursor + clear */
#define SPECTREPRO_MODE_BRACKETED_PASTE  (spectrepro_mode_new(2004, false)) /**< Bracketed paste mode */
#define SPECTREPRO_MODE_SYNC_OUTPUT      (spectrepro_mode_new(2026, false)) /**< Synchronized output */
#define SPECTREPRO_MODE_GRAPHEME_CLUSTER (spectrepro_mode_new(2027, false)) /**< Grapheme cluster mode */
#define SPECTREPRO_MODE_COLOR_SCHEME_REPORT (spectrepro_mode_new(2031, false)) /**< Report color scheme */
#define SPECTREPRO_MODE_VISIBILITY_REPORT (spectrepro_mode_new(2033, false)) /**< Report terminal visibility */
#define SPECTREPRO_MODE_IN_BAND_RESIZE   (spectrepro_mode_new(2048, false)) /**< In-band size reports */
#define SPECTREPRO_MODE_PASTE_EVENTS     (spectrepro_mode_new(5522, false)) /**< Kitty clipboard protocol paste events */
/** @} */

/**
 * A packed 16-bit terminal mode.
 *
 * Encodes a mode value (bits 0–14) and an ANSI flag (bit 15) into a
 * single 16-bit integer. Use the inline helper functions to construct
 * and inspect modes rather than manipulating bits directly.
 */
typedef uint16_t SpectreProMode;

/**
 * Create a mode from a mode value and ANSI flag.
 *
 * @param value The numeric mode value (0–32767)
 * @param ansi true for an ANSI mode, false for a DEC private mode
 * @return The packed mode
 *
 * @ingroup modes
 */
static inline SpectreProMode spectrepro_mode_new(uint16_t value, bool ansi) {
    return (SpectreProMode)((value & 0x7FFF) | ((uint16_t)ansi << 15));
}

/**
 * Extract the numeric mode value from a mode.
 *
 * @param mode The mode
 * @return The mode value (0–32767)
 *
 * @ingroup modes
 */
static inline uint16_t spectrepro_mode_value(SpectreProMode mode) {
    return mode & 0x7FFF;
}

/**
 * Check whether a mode represents an ANSI mode.
 *
 * @param mode The mode
 * @return true if this is an ANSI mode, false if it is a DEC private mode
 *
 * @ingroup modes
 */
static inline bool spectrepro_mode_ansi(SpectreProMode mode) {
    return (mode >> 15) != 0;
}

/**
 * DECRPM report state values.
 *
 * These correspond to the Ps2 parameter in a DECRPM response
 * sequence (CSI ? Ps1 ; Ps2 $ y).
 */
typedef enum SPECTREPRO_ENUM_TYPED {
    /** Mode is not recognized */
    SPECTREPRO_MODE_REPORT_NOT_RECOGNIZED = 0,
    /** Mode is set (enabled) */
    SPECTREPRO_MODE_REPORT_SET = 1,
    /** Mode is reset (disabled) */
    SPECTREPRO_MODE_REPORT_RESET = 2,
    /** Mode is permanently set */
    SPECTREPRO_MODE_REPORT_PERMANENTLY_SET = 3,
    /** Mode is permanently reset */
    SPECTREPRO_MODE_REPORT_PERMANENTLY_RESET = 4,
    SPECTREPRO_MODE_REPORT_MAX_VALUE = SPECTREPRO_ENUM_MAX_VALUE,
} SpectreProModeReportState;

/**
 * Encode a DECRPM (DEC Private Mode Report) response sequence.
 *
 * Writes a mode report escape sequence into the provided buffer.
 * The generated sequence has the form:
 * - DEC private mode: CSI ? Ps1 ; Ps2 $ y
 * - ANSI mode:        CSI Ps1 ; Ps2 $ y
 *
 * If the buffer is too small, the function returns SPECTREPRO_OUT_OF_SPACE
 * and writes the required buffer size to @p out_written. The caller can
 * then retry with a sufficiently sized buffer.
 *
 * @param mode The mode identifying the mode to report on
 * @param state The report state for this mode
 * @param buf Output buffer to write the encoded sequence into (may be NULL)
 * @param buf_len Size of the output buffer in bytes
 * @param[out] out_written On success, the number of bytes written. On
 *             SPECTREPRO_OUT_OF_SPACE, the required buffer size.
 * @return SPECTREPRO_SUCCESS on success, SPECTREPRO_OUT_OF_SPACE if the buffer
 *         is too small
 */
SPECTREPRO_API SpectreProResult spectrepro_mode_report_encode(
    SpectreProMode mode,
    SpectreProModeReportState state,
    char* buf,
    size_t buf_len,
    size_t* out_written);

#ifdef __cplusplus
}
#endif

/** @} */

#endif /* SPECTREPRO_VT_MODES_H */
