/**
 * @file event.h
 *
 * Key event representation and manipulation.
 */

#ifndef SPECTREPRO_VT_KEY_EVENT_H
#define SPECTREPRO_VT_KEY_EVENT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <spectrepro/vt/types.h>
#include <spectrepro/vt/allocator.h>

/**
 * Opaque handle to a key event.
 * 
 * This handle represents a keyboard input event containing information about
 * the physical key pressed, modifiers, and generated text.
 *
 * @ingroup key
 */
typedef struct SpectreProKeyEventImpl *SpectreProKeyEvent;

/**
 * Keyboard input event types.
 *
 * @ingroup key
 */
typedef enum SPECTREPRO_ENUM_TYPED {
    /** Key was released */
    SPECTREPRO_KEY_ACTION_RELEASE = 0,
    /** Key was pressed */
    SPECTREPRO_KEY_ACTION_PRESS = 1,
    /** Key is being repeated (held down) */
    SPECTREPRO_KEY_ACTION_REPEAT = 2,
    SPECTREPRO_KEY_ACTION_MAX_VALUE = SPECTREPRO_ENUM_MAX_VALUE,
} SpectreProKeyAction;

/**
 * Keyboard modifier keys bitmask.
 *
 * A bitmask representing all keyboard modifiers. This tracks which modifier keys 
 * are pressed and, where supported by the platform, which side (left or right) 
 * of each modifier is active.
 *
 * Use the SPECTREPRO_MODS_* constants to test and set individual modifiers.
 *
 * Modifier side bits are only meaningful when the corresponding modifier bit is set.
 * Not all platforms support distinguishing between left and right modifier 
 * keys and SpectrePro is built to expect that some platforms may not provide this
 * information.
 *
 * @ingroup key
 */
typedef uint16_t SpectreProMods;

/** Shift key is pressed */
#define SPECTREPRO_MODS_SHIFT (1 << 0)
/** Control key is pressed */
#define SPECTREPRO_MODS_CTRL (1 << 1)
/** Alt/Option key is pressed */
#define SPECTREPRO_MODS_ALT (1 << 2)
/** Super/Command/Windows key is pressed */
#define SPECTREPRO_MODS_SUPER (1 << 3)
/** Caps Lock is active */
#define SPECTREPRO_MODS_CAPS_LOCK (1 << 4)
/** Num Lock is active */
#define SPECTREPRO_MODS_NUM_LOCK (1 << 5)

/**
 * Right shift is pressed (0 = left, 1 = right).
 * Only meaningful when SPECTREPRO_MODS_SHIFT is set.
 */
#define SPECTREPRO_MODS_SHIFT_SIDE (1 << 6)
/**
 * Right ctrl is pressed (0 = left, 1 = right).
 * Only meaningful when SPECTREPRO_MODS_CTRL is set.
 */
#define SPECTREPRO_MODS_CTRL_SIDE (1 << 7)
/**
 * Right alt is pressed (0 = left, 1 = right).
 * Only meaningful when SPECTREPRO_MODS_ALT is set.
 */
#define SPECTREPRO_MODS_ALT_SIDE (1 << 8)
/**
 * Right super is pressed (0 = left, 1 = right).
 * Only meaningful when SPECTREPRO_MODS_SUPER is set.
 */
#define SPECTREPRO_MODS_SUPER_SIDE (1 << 9)

/**
 * Physical key codes.
 *
 * The set of key codes that SpectrePro is aware of. These represent physical keys 
 * on the keyboard and are layout-independent. For example, the "a" key on a US 
 * keyboard is the same as the "ф" key on a Russian keyboard, but both will 
 * report the same key_a value.
 *
 * Layout-dependent strings are provided separately as UTF-8 text and are produced 
 * by the platform. These values are based on the W3C UI Events KeyboardEvent code 
 * standard. See: https://www.w3.org/TR/uievents-code
 *
 * @ingroup key
 */
typedef enum SPECTREPRO_ENUM_TYPED {
    SPECTREPRO_KEY_UNIDENTIFIED = 0,

    // Writing System Keys (W3C § 3.1.1)
    SPECTREPRO_KEY_BACKQUOTE,
    SPECTREPRO_KEY_BACKSLASH,
    SPECTREPRO_KEY_BRACKET_LEFT,
    SPECTREPRO_KEY_BRACKET_RIGHT,
    SPECTREPRO_KEY_COMMA,
    SPECTREPRO_KEY_DIGIT_0,
    SPECTREPRO_KEY_DIGIT_1,
    SPECTREPRO_KEY_DIGIT_2,
    SPECTREPRO_KEY_DIGIT_3,
    SPECTREPRO_KEY_DIGIT_4,
    SPECTREPRO_KEY_DIGIT_5,
    SPECTREPRO_KEY_DIGIT_6,
    SPECTREPRO_KEY_DIGIT_7,
    SPECTREPRO_KEY_DIGIT_8,
    SPECTREPRO_KEY_DIGIT_9,
    SPECTREPRO_KEY_EQUAL,
    SPECTREPRO_KEY_INTL_BACKSLASH,
    SPECTREPRO_KEY_INTL_RO,
    SPECTREPRO_KEY_INTL_YEN,
    SPECTREPRO_KEY_A,
    SPECTREPRO_KEY_B,
    SPECTREPRO_KEY_C,
    SPECTREPRO_KEY_D,
    SPECTREPRO_KEY_E,
    SPECTREPRO_KEY_F,
    SPECTREPRO_KEY_G,
    SPECTREPRO_KEY_H,
    SPECTREPRO_KEY_I,
    SPECTREPRO_KEY_J,
    SPECTREPRO_KEY_K,
    SPECTREPRO_KEY_L,
    SPECTREPRO_KEY_M,
    SPECTREPRO_KEY_N,
    SPECTREPRO_KEY_O,
    SPECTREPRO_KEY_P,
    SPECTREPRO_KEY_Q,
    SPECTREPRO_KEY_R,
    SPECTREPRO_KEY_S,
    SPECTREPRO_KEY_T,
    SPECTREPRO_KEY_U,
    SPECTREPRO_KEY_V,
    SPECTREPRO_KEY_W,
    SPECTREPRO_KEY_X,
    SPECTREPRO_KEY_Y,
    SPECTREPRO_KEY_Z,
    SPECTREPRO_KEY_MINUS,
    SPECTREPRO_KEY_PERIOD,
    SPECTREPRO_KEY_QUOTE,
    SPECTREPRO_KEY_SEMICOLON,
    SPECTREPRO_KEY_SLASH,

    // Functional Keys (W3C § 3.1.2)
    SPECTREPRO_KEY_ALT_LEFT,
    SPECTREPRO_KEY_ALT_RIGHT,
    SPECTREPRO_KEY_BACKSPACE,
    SPECTREPRO_KEY_CAPS_LOCK,
    SPECTREPRO_KEY_CONTEXT_MENU,
    SPECTREPRO_KEY_CONTROL_LEFT,
    SPECTREPRO_KEY_CONTROL_RIGHT,
    SPECTREPRO_KEY_ENTER,
    SPECTREPRO_KEY_META_LEFT,
    SPECTREPRO_KEY_META_RIGHT,
    SPECTREPRO_KEY_SHIFT_LEFT,
    SPECTREPRO_KEY_SHIFT_RIGHT,
    SPECTREPRO_KEY_SPACE,
    SPECTREPRO_KEY_TAB,
    SPECTREPRO_KEY_CONVERT,
    SPECTREPRO_KEY_KANA_MODE,
    SPECTREPRO_KEY_NON_CONVERT,

    // Control Pad Section (W3C § 3.2)
    SPECTREPRO_KEY_DELETE,
    SPECTREPRO_KEY_END,
    SPECTREPRO_KEY_HELP,
    SPECTREPRO_KEY_HOME,
    SPECTREPRO_KEY_INSERT,
    SPECTREPRO_KEY_PAGE_DOWN,
    SPECTREPRO_KEY_PAGE_UP,

    // Arrow Pad Section (W3C § 3.3)
    SPECTREPRO_KEY_ARROW_DOWN,
    SPECTREPRO_KEY_ARROW_LEFT,
    SPECTREPRO_KEY_ARROW_RIGHT,
    SPECTREPRO_KEY_ARROW_UP,

    // Numpad Section (W3C § 3.4)
    SPECTREPRO_KEY_NUM_LOCK,
    SPECTREPRO_KEY_NUMPAD_0,
    SPECTREPRO_KEY_NUMPAD_1,
    SPECTREPRO_KEY_NUMPAD_2,
    SPECTREPRO_KEY_NUMPAD_3,
    SPECTREPRO_KEY_NUMPAD_4,
    SPECTREPRO_KEY_NUMPAD_5,
    SPECTREPRO_KEY_NUMPAD_6,
    SPECTREPRO_KEY_NUMPAD_7,
    SPECTREPRO_KEY_NUMPAD_8,
    SPECTREPRO_KEY_NUMPAD_9,
    SPECTREPRO_KEY_NUMPAD_ADD,
    SPECTREPRO_KEY_NUMPAD_BACKSPACE,
    SPECTREPRO_KEY_NUMPAD_CLEAR,
    SPECTREPRO_KEY_NUMPAD_CLEAR_ENTRY,
    SPECTREPRO_KEY_NUMPAD_COMMA,
    SPECTREPRO_KEY_NUMPAD_DECIMAL,
    SPECTREPRO_KEY_NUMPAD_DIVIDE,
    SPECTREPRO_KEY_NUMPAD_ENTER,
    SPECTREPRO_KEY_NUMPAD_EQUAL,
    SPECTREPRO_KEY_NUMPAD_MEMORY_ADD,
    SPECTREPRO_KEY_NUMPAD_MEMORY_CLEAR,
    SPECTREPRO_KEY_NUMPAD_MEMORY_RECALL,
    SPECTREPRO_KEY_NUMPAD_MEMORY_STORE,
    SPECTREPRO_KEY_NUMPAD_MEMORY_SUBTRACT,
    SPECTREPRO_KEY_NUMPAD_MULTIPLY,
    SPECTREPRO_KEY_NUMPAD_PAREN_LEFT,
    SPECTREPRO_KEY_NUMPAD_PAREN_RIGHT,
    SPECTREPRO_KEY_NUMPAD_SUBTRACT,
    SPECTREPRO_KEY_NUMPAD_SEPARATOR,
    SPECTREPRO_KEY_NUMPAD_UP,
    SPECTREPRO_KEY_NUMPAD_DOWN,
    SPECTREPRO_KEY_NUMPAD_RIGHT,
    SPECTREPRO_KEY_NUMPAD_LEFT,
    SPECTREPRO_KEY_NUMPAD_BEGIN,
    SPECTREPRO_KEY_NUMPAD_HOME,
    SPECTREPRO_KEY_NUMPAD_END,
    SPECTREPRO_KEY_NUMPAD_INSERT,
    SPECTREPRO_KEY_NUMPAD_DELETE,
    SPECTREPRO_KEY_NUMPAD_PAGE_UP,
    SPECTREPRO_KEY_NUMPAD_PAGE_DOWN,

    // Function Section (W3C § 3.5)
    SPECTREPRO_KEY_ESCAPE,
    SPECTREPRO_KEY_F1,
    SPECTREPRO_KEY_F2,
    SPECTREPRO_KEY_F3,
    SPECTREPRO_KEY_F4,
    SPECTREPRO_KEY_F5,
    SPECTREPRO_KEY_F6,
    SPECTREPRO_KEY_F7,
    SPECTREPRO_KEY_F8,
    SPECTREPRO_KEY_F9,
    SPECTREPRO_KEY_F10,
    SPECTREPRO_KEY_F11,
    SPECTREPRO_KEY_F12,
    SPECTREPRO_KEY_F13,
    SPECTREPRO_KEY_F14,
    SPECTREPRO_KEY_F15,
    SPECTREPRO_KEY_F16,
    SPECTREPRO_KEY_F17,
    SPECTREPRO_KEY_F18,
    SPECTREPRO_KEY_F19,
    SPECTREPRO_KEY_F20,
    SPECTREPRO_KEY_F21,
    SPECTREPRO_KEY_F22,
    SPECTREPRO_KEY_F23,
    SPECTREPRO_KEY_F24,
    SPECTREPRO_KEY_F25,
    SPECTREPRO_KEY_FN,
    SPECTREPRO_KEY_FN_LOCK,
    SPECTREPRO_KEY_PRINT_SCREEN,
    SPECTREPRO_KEY_SCROLL_LOCK,
    SPECTREPRO_KEY_PAUSE,

    // Media Keys (W3C § 3.6)
    SPECTREPRO_KEY_BROWSER_BACK,
    SPECTREPRO_KEY_BROWSER_FAVORITES,
    SPECTREPRO_KEY_BROWSER_FORWARD,
    SPECTREPRO_KEY_BROWSER_HOME,
    SPECTREPRO_KEY_BROWSER_REFRESH,
    SPECTREPRO_KEY_BROWSER_SEARCH,
    SPECTREPRO_KEY_BROWSER_STOP,
    SPECTREPRO_KEY_EJECT,
    SPECTREPRO_KEY_LAUNCH_APP_1,
    SPECTREPRO_KEY_LAUNCH_APP_2,
    SPECTREPRO_KEY_LAUNCH_MAIL,
    SPECTREPRO_KEY_MEDIA_PLAY_PAUSE,
    SPECTREPRO_KEY_MEDIA_SELECT,
    SPECTREPRO_KEY_MEDIA_STOP,
    SPECTREPRO_KEY_MEDIA_TRACK_NEXT,
    SPECTREPRO_KEY_MEDIA_TRACK_PREVIOUS,
    SPECTREPRO_KEY_POWER,
    SPECTREPRO_KEY_SLEEP,
    SPECTREPRO_KEY_AUDIO_VOLUME_DOWN,
    SPECTREPRO_KEY_AUDIO_VOLUME_MUTE,
    SPECTREPRO_KEY_AUDIO_VOLUME_UP,
    SPECTREPRO_KEY_WAKE_UP,

    // Legacy, Non-standard, and Special Keys (W3C § 3.7)
    SPECTREPRO_KEY_COPY,
    SPECTREPRO_KEY_CUT,
    SPECTREPRO_KEY_PASTE,
    SPECTREPRO_KEY_MAX_VALUE = SPECTREPRO_ENUM_MAX_VALUE,
} SpectreProKey;

/**
 * Create a new key event instance.
 * 
 * Creates a new key event with default values. The event must be freed using
 * spectrepro_key_event_free() when no longer needed.
 * 
 * @param allocator Pointer to the allocator to use for memory management, or NULL to use the default allocator
 * @param event Pointer to store the created key event handle
 * @return SPECTREPRO_SUCCESS on success, or an error code on failure
 * 
 * @ingroup key
 */
SPECTREPRO_API SpectreProResult spectrepro_key_event_new(const SpectreProAllocator *allocator, SpectreProKeyEvent *event);

/**
 * Free a key event instance.
 * 
 * Releases all resources associated with the key event. After this call,
 * the event handle becomes invalid and must not be used.
 * 
 * @param event The key event handle to free (may be NULL)
 * 
 * @ingroup key
 */
SPECTREPRO_API void spectrepro_key_event_free(SpectreProKeyEvent event);

/**
 * Set the key action (press, release, repeat).
 *
 * @param event The key event handle, must not be NULL
 * @param action The action to set
 *
 * @ingroup key
 */
SPECTREPRO_API void spectrepro_key_event_set_action(SpectreProKeyEvent event, SpectreProKeyAction action);

/**
 * Get the key action (press, release, repeat).
 *
 * @param event The key event handle, must not be NULL
 * @return The key action
 *
 * @ingroup key
 */
SPECTREPRO_API SpectreProKeyAction spectrepro_key_event_get_action(SpectreProKeyEvent event);

/**
 * Set the physical key code.
 *
 * @param event The key event handle, must not be NULL
 * @param key The physical key code to set
 *
 * @ingroup key
 */
SPECTREPRO_API void spectrepro_key_event_set_key(SpectreProKeyEvent event, SpectreProKey key);

/**
 * Get the physical key code.
 *
 * @param event The key event handle, must not be NULL
 * @return The physical key code
 *
 * @ingroup key
 */
SPECTREPRO_API SpectreProKey spectrepro_key_event_get_key(SpectreProKeyEvent event);

/**
 * Set the modifier keys bitmask.
 *
 * @param event The key event handle, must not be NULL
 * @param mods The modifier keys bitmask to set
 *
 * @ingroup key
 */
SPECTREPRO_API void spectrepro_key_event_set_mods(SpectreProKeyEvent event, SpectreProMods mods);

/**
 * Get the modifier keys bitmask.
 *
 * @param event The key event handle, must not be NULL
 * @return The modifier keys bitmask
 *
 * @ingroup key
 */
SPECTREPRO_API SpectreProMods spectrepro_key_event_get_mods(SpectreProKeyEvent event);

/**
 * Set the consumed modifiers bitmask.
 *
 * @param event The key event handle, must not be NULL
 * @param consumed_mods The consumed modifiers bitmask to set
 *
 * @ingroup key
 */
SPECTREPRO_API void spectrepro_key_event_set_consumed_mods(SpectreProKeyEvent event, SpectreProMods consumed_mods);

/**
 * Get the consumed modifiers bitmask.
 *
 * @param event The key event handle, must not be NULL
 * @return The consumed modifiers bitmask
 *
 * @ingroup key
 */
SPECTREPRO_API SpectreProMods spectrepro_key_event_get_consumed_mods(SpectreProKeyEvent event);

/**
 * Set whether the key event is part of a composition sequence.
 *
 * @param event The key event handle, must not be NULL
 * @param composing Whether the key event is part of a composition sequence
 *
 * @ingroup key
 */
SPECTREPRO_API void spectrepro_key_event_set_composing(SpectreProKeyEvent event, bool composing);

/**
 * Get whether the key event is part of a composition sequence.
 *
 * @param event The key event handle, must not be NULL
 * @return Whether the key event is part of a composition sequence
 *
 * @ingroup key
 */
SPECTREPRO_API bool spectrepro_key_event_get_composing(SpectreProKeyEvent event);

/**
 * Set the UTF-8 text generated by the key for the current keyboard layout.
 *
 * Must contain the unmodified character before any Ctrl/Meta transformations.
 * The encoder derives modifier sequences from the logical key and mods
 * bitmask, not from this text. Do not pass C0 control characters
 * (U+0000-U+001F, U+007F) or platform function key codes (e.g. macOS PUA
 * U+F700-U+F8FF); pass NULL instead and let the encoder use the logical key.
 *
 * The key event does NOT take ownership of the text pointer. The caller
 * must ensure the string remains valid for the lifetime needed by the event.
 *
 * @param event The key event handle, must not be NULL
 * @param utf8 The UTF-8 text to set (or NULL for empty)
 * @param len Length of the UTF-8 text in bytes
 *
 * @ingroup key
 */
SPECTREPRO_API void spectrepro_key_event_set_utf8(SpectreProKeyEvent event, const char *utf8, size_t len);

/**
 * Get the UTF-8 text generated by the key event.
 *
 * The returned pointer is valid until the event is freed or the UTF-8 text is modified.
 *
 * @param event The key event handle, must not be NULL
 * @param len Pointer to store the length of the UTF-8 text in bytes (may be NULL)
 * @return The UTF-8 text (or NULL for empty)
 *
 * @ingroup key
 */
SPECTREPRO_API const char *spectrepro_key_event_get_utf8(SpectreProKeyEvent event, size_t *len);

/**
 * Set the unshifted Unicode codepoint.
 *
 * @param event The key event handle, must not be NULL
 * @param codepoint The unshifted Unicode codepoint to set
 *
 * @ingroup key
 */
SPECTREPRO_API void spectrepro_key_event_set_unshifted_codepoint(SpectreProKeyEvent event, uint32_t codepoint);

/**
 * Get the unshifted Unicode codepoint.
 *
 * @param event The key event handle, must not be NULL
 * @return The unshifted Unicode codepoint
 *
 * @ingroup key
 */
SPECTREPRO_API uint32_t spectrepro_key_event_get_unshifted_codepoint(SpectreProKeyEvent event);

#endif /* SPECTREPRO_VT_KEY_EVENT_H */
