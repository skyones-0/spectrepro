/**
 * @file formatter.h
 *
 * Format terminal content as plain text, VT sequences, or HTML.
 */

#ifndef SPECTREPRO_VT_FORMATTER_H
#define SPECTREPRO_VT_FORMATTER_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <spectrepro/vt/allocator.h>
#include <spectrepro/vt/io.h>
#include <spectrepro/vt/selection.h>
#include <spectrepro/vt/types.h>
#include <spectrepro/vt/terminal.h>

#ifdef __cplusplus
extern "C" {
#endif

/** @defgroup formatter Formatter
 *
 * Format terminal content as plain text, VT sequences, or HTML.
 *
 * A formatter captures a reference to a terminal and formatting options.
 * It can be used repeatedly to produce output that reflects the current
 * terminal state at the time of each format call.
 *
 * The terminal must outlive the formatter.
 *
 * @{
 */

/**
 * Extra screen state to include in styled output.
 *
 * @ingroup formatter
 */
typedef struct {
  /** Size of this struct in bytes. Must be set to sizeof(SpectreProFormatterScreenExtra). */
  size_t size;

  /** Emit cursor position using CUP (CSI H). */
  bool cursor;

  /** Emit current SGR style state based on the cursor's active style_id. */
  bool style;

  /** Emit current hyperlink state using OSC 8 sequences. */
  bool hyperlink;

  /** Emit character protection mode using DECSCA. */
  bool protection;

  /** Emit Kitty keyboard protocol state using CSI > u and CSI = sequences. */
  bool kitty_keyboard;

  /** Emit character set designations and invocations. */
  bool charsets;
} SpectreProFormatterScreenExtra;

/**
 * Extra terminal state to include in styled output.
 *
 * @ingroup formatter
 */
typedef struct {
  /** Size of this struct in bytes. Must be set to sizeof(SpectreProFormatterTerminalExtra). */
  size_t size;

  /** Emit the palette using OSC 4 sequences. */
  bool palette;

  /** Emit terminal modes that differ from their defaults using CSI h/l. */
  bool modes;

  /** Emit scrolling region state using DECSTBM and DECSLRM sequences. */
  bool scrolling_region;

  /** Emit tabstop positions by clearing all tabs and setting each one. */
  bool tabstops;

  /** Emit the present working directory using OSC 7. */
  bool pwd;

  /** Emit keyboard modes such as ModifyOtherKeys. */
  bool keyboard;

  /** Screen-level extras. */
  SpectreProFormatterScreenExtra screen;
} SpectreProFormatterTerminalExtra;

/**
 * Options for creating a terminal formatter.
 *
 * @ingroup formatter
 */
typedef struct {
  /** Size of this struct in bytes. Must be set to sizeof(SpectreProFormatterTerminalOptions). */
  size_t size;

  /** Output format to emit. */
  SpectreProFormatterFormat emit;

  /** Whether to unwrap soft-wrapped lines. */
  bool unwrap;

  /** Whether to trim trailing whitespace on non-blank lines. */
  bool trim;

  /** Extra terminal state to include in styled output. */
  SpectreProFormatterTerminalExtra extra;

  /** Optional selection to restrict output to a range.
   *  If NULL, the entire screen is formatted. */
  const SpectreProSelection *selection;
} SpectreProFormatterTerminalOptions;

/**
 * Create a formatter for a terminal's active screen.
 *
 * The terminal must outlive the formatter. The formatter stores a borrowed
 * reference to the terminal and reads its current state on each format call.
 *
 * @param allocator Pointer to allocator, or NULL to use the default allocator
 * @param formatter Pointer to store the created formatter handle
 * @param terminal The terminal to format (must not be NULL)
 * @param options Formatting options
 * @return SPECTREPRO_SUCCESS on success, or an error code on failure
 *
 * @ingroup formatter
 */
SPECTREPRO_API SpectreProResult spectrepro_formatter_terminal_new(
    const SpectreProAllocator* allocator,
    SpectreProFormatter* formatter,
    SpectreProTerminal terminal,
    SpectreProFormatterTerminalOptions options);

/**
 * Run the formatter and stream output to a writer.
 *
 * Each call formats the current terminal state and invokes the writer
 * synchronously as output becomes available. The callback may be called more
 * than once and must not call formatter or terminal APIs using the same
 * formatter or its terminal.
 *
 * If an error occurs, the writer may already contain a partial formatted
 * output. The operation cannot be resumed from that partial output. This
 * function does not flush or make the caller's destination durable.
 *
 * @param formatter The formatter handle (must not be NULL)
 * @param writer Destination writer whose write callback must not be NULL
 * @return SPECTREPRO_SUCCESS on success, SPECTREPRO_IO_ERROR if the writer rejects
 *         output, SPECTREPRO_LIMIT_EXCEEDED if output accounting overflows, or
 *         SPECTREPRO_INVALID_VALUE if an argument is invalid
 *
 * @ingroup formatter
 */
SPECTREPRO_API SpectreProResult spectrepro_formatter_format(
    SpectreProFormatter formatter,
    SpectreProWriter writer);

/**
 * Run the formatter and produce output into the caller-provided buffer.
 *
 * Each call formats the current terminal state. Pass NULL for buf to
 * query the required buffer size without writing any output; in that case
 * out_written receives the required size and the return value is
 * SPECTREPRO_OUT_OF_SPACE.
 *
 * If the buffer is too small, returns SPECTREPRO_OUT_OF_SPACE and sets
 * out_written to the required size. The caller can then retry with a
 * larger buffer.
 *
 * @param formatter The formatter handle (must not be NULL)
 * @param buf Pointer to the output buffer, or NULL to query size
 * @param buf_len Length of the output buffer in bytes
 * @param out_written Pointer to receive the number of bytes written,
 *                    or the required size on failure
 * @return SPECTREPRO_SUCCESS on success, or an error code on failure
 *
 * @ingroup formatter
 */
SPECTREPRO_API SpectreProResult spectrepro_formatter_format_buf(SpectreProFormatter formatter,
                                           uint8_t* buf,
                                           size_t buf_len,
                                           size_t* out_written);

/**
 * Run the formatter and return an allocated buffer with the output.
 *
 * Each call formats the current terminal state. The buffer is allocated
 * using the provided allocator (or the default allocator if NULL).
 * The caller is responsible for freeing the returned buffer with
 * spectrepro_free(), passing the same allocator (or NULL for the default)
 * that was used for the allocation.
 * Empty output returns SPECTREPRO_SUCCESS with *out_ptr set to NULL and
 * *out_len set to zero. This result can be passed to spectrepro_free().
 *
 * @param formatter The formatter handle (must not be NULL)
 * @param allocator Pointer to allocator, or NULL to use the default allocator
 * @param out_ptr Pointer to receive the allocated buffer
 * @param out_len Pointer to receive the length of the output in bytes
 * @return SPECTREPRO_SUCCESS on success, SPECTREPRO_OUT_OF_MEMORY on allocation
 *         failure
 *
 * @ingroup formatter
 */
SPECTREPRO_API SpectreProResult spectrepro_formatter_format_alloc(SpectreProFormatter formatter,
                                             const SpectreProAllocator* allocator,
                                             uint8_t** out_ptr,
                                             size_t* out_len);

/**
 * Free a formatter instance.
 *
 * Releases all resources associated with the formatter. After this call,
 * the formatter handle becomes invalid.
 *
 * @param formatter The formatter handle to free (may be NULL)
 *
 * @ingroup formatter
 */
SPECTREPRO_API void spectrepro_formatter_free(SpectreProFormatter formatter);

/** @} */

#ifdef __cplusplus
}
#endif

#endif /* SPECTREPRO_VT_FORMATTER_H */
