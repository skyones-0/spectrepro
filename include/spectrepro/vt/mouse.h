/**
 * @file mouse.h
 *
 * Mouse encoding module - encode mouse events into terminal escape sequences.
 */

#ifndef SPECTREPRO_VT_MOUSE_H
#define SPECTREPRO_VT_MOUSE_H

/** @defgroup mouse Mouse Encoding
 *
 * Utilities for encoding mouse events into terminal escape sequences,
 * supporting X10, UTF-8, SGR, URxvt, and SGR-Pixels mouse protocols.
 *
 * ## Basic Usage
 *
 * 1. Create an encoder instance with spectrepro_mouse_encoder_new().
 * 2. Configure encoder options with spectrepro_mouse_encoder_setopt() or
 *    spectrepro_mouse_encoder_setopt_from_terminal().
 * 3. For each mouse event:
 *    - Create a mouse event with spectrepro_mouse_event_new().
 *    - Set event properties (action, button, modifiers, position).
 *    - Encode with spectrepro_mouse_encoder_encode().
 *    - Free the event with spectrepro_mouse_event_free() or reuse it.
 * 4. Free the encoder with spectrepro_mouse_encoder_free() when done.
 *
 * For a complete working example, see example/c-vt-encode-mouse in the
 * repository.
 *
 * ## Example
 *
 * @snippet c-vt-encode-mouse/src/main.c mouse-encode
 *
 * ## Example: Encoding with Terminal State
 *
 * When you have a SpectreProTerminal, you can sync its tracking mode and
 * output format into the encoder automatically:
 *
 * @code{.c}
 * // Create a terminal and feed it some VT data that enables mouse tracking
 * SpectreProTerminal terminal;
 * spectrepro_terminal_new(NULL, &terminal, 80, 24);
 *
 * // Application might write data that enables mouse reporting, etc.
 * spectrepro_terminal_vt_write(terminal, vt_data, vt_len);
 *
 * // Create an encoder and sync its options from the terminal
 * SpectreProMouseEncoder encoder;
 * spectrepro_mouse_encoder_new(NULL, &encoder);
 * spectrepro_mouse_encoder_setopt_from_terminal(encoder, terminal);
 *
 * // Encode a mouse event using the terminal-derived options
 * char buf[128];
 * size_t written = 0;
 * spectrepro_mouse_encoder_encode(encoder, event, buf, sizeof(buf), &written);
 *
 * spectrepro_mouse_encoder_free(encoder);
 * spectrepro_terminal_free(terminal);
 * @endcode
 *
 * @{
 */

#include <spectrepro/vt/mouse/event.h>
#include <spectrepro/vt/mouse/encoder.h>

/** @} */

#endif /* SPECTREPRO_VT_MOUSE_H */
