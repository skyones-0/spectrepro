/**
 * @file event.h
 *
 * Mouse event representation and manipulation.
 */

#ifndef SPECTREPRO_VT_MOUSE_EVENT_H
#define SPECTREPRO_VT_MOUSE_EVENT_H

#include <stdbool.h>
#include <spectrepro/vt/allocator.h>
#include <spectrepro/vt/key/event.h>
#include <spectrepro/vt/types.h>

/**
 * Opaque handle to a mouse event.
 *
 * This handle represents a normalized mouse input event containing
 * action, button, modifiers, and surface-space position.
 *
 * @ingroup mouse
 */
typedef struct SpectreProMouseEventImpl *SpectreProMouseEvent;

/**
 * Mouse event action type.
 *
 * @ingroup mouse
 */
typedef enum SPECTREPRO_ENUM_TYPED {
  /** Mouse button was pressed. */
  SPECTREPRO_MOUSE_ACTION_PRESS = 0,

  /** Mouse button was released. */
  SPECTREPRO_MOUSE_ACTION_RELEASE = 1,

  /** Mouse moved. */
  SPECTREPRO_MOUSE_ACTION_MOTION = 2,
  SPECTREPRO_MOUSE_ACTION_MAX_VALUE = SPECTREPRO_ENUM_MAX_VALUE,
} SpectreProMouseAction;

/**
 * Mouse button identity.
 *
 * @ingroup mouse
 */
typedef enum SPECTREPRO_ENUM_TYPED {
  SPECTREPRO_MOUSE_BUTTON_UNKNOWN = 0,
  SPECTREPRO_MOUSE_BUTTON_LEFT = 1,
  SPECTREPRO_MOUSE_BUTTON_RIGHT = 2,
  SPECTREPRO_MOUSE_BUTTON_MIDDLE = 3,
  SPECTREPRO_MOUSE_BUTTON_FOUR = 4,
  SPECTREPRO_MOUSE_BUTTON_FIVE = 5,
  SPECTREPRO_MOUSE_BUTTON_SIX = 6,
  SPECTREPRO_MOUSE_BUTTON_SEVEN = 7,
  SPECTREPRO_MOUSE_BUTTON_EIGHT = 8,
  SPECTREPRO_MOUSE_BUTTON_NINE = 9,
  SPECTREPRO_MOUSE_BUTTON_TEN = 10,
  SPECTREPRO_MOUSE_BUTTON_ELEVEN = 11,
  SPECTREPRO_MOUSE_BUTTON_MAX_VALUE = SPECTREPRO_ENUM_MAX_VALUE,
} SpectreProMouseButton;

/**
 * Mouse position in surface-space pixels.
 *
 * @ingroup mouse
 */
typedef struct {
  float x;
  float y;
} SpectreProMousePosition;

/**
 * Create a new mouse event instance.
 *
 * @param allocator Pointer to allocator, or NULL to use the default allocator
 * @param event Pointer to store the created event handle
 * @return SPECTREPRO_SUCCESS on success, or an error code on failure
 *
 * @ingroup mouse
 */
SPECTREPRO_API SpectreProResult spectrepro_mouse_event_new(const SpectreProAllocator *allocator,
                                      SpectreProMouseEvent *event);

/**
 * Free a mouse event instance.
 *
 * @param event The mouse event handle to free (may be NULL)
 *
 * @ingroup mouse
 */
SPECTREPRO_API void spectrepro_mouse_event_free(SpectreProMouseEvent event);

/**
 * Set the event action.
 *
 * @param event The event handle, must not be NULL
 * @param action The action to set
 *
 * @ingroup mouse
 */
SPECTREPRO_API void spectrepro_mouse_event_set_action(SpectreProMouseEvent event,
                                    SpectreProMouseAction action);

/**
 * Get the event action.
 *
 * @param event The event handle, must not be NULL
 * @return The event action
 *
 * @ingroup mouse
 */
SPECTREPRO_API SpectreProMouseAction spectrepro_mouse_event_get_action(SpectreProMouseEvent event);

/**
 * Set the event button.
 *
 * This sets a concrete button identity for the event.
 * To represent "no button" (for motion events), use
 * spectrepro_mouse_event_clear_button().
 *
 * @param event The event handle, must not be NULL
 * @param button The button to set
 *
 * @ingroup mouse
 */
SPECTREPRO_API void spectrepro_mouse_event_set_button(SpectreProMouseEvent event,
                                    SpectreProMouseButton button);

/**
 * Clear the event button.
 *
 * This sets the event button to "none".
 *
 * @param event The event handle, must not be NULL
 *
 * @ingroup mouse
 */
SPECTREPRO_API void spectrepro_mouse_event_clear_button(SpectreProMouseEvent event);

/**
 * Get the event button.
 *
 * @param event The event handle, must not be NULL
 * @param out_button Output pointer for the button value (may be NULL)
 * @return true if a button is set, false if no button is set
 *
 * @ingroup mouse
 */
SPECTREPRO_API bool spectrepro_mouse_event_get_button(SpectreProMouseEvent event,
                                    SpectreProMouseButton *out_button);

/**
 * Set keyboard modifiers held during the event.
 *
 * @param event The event handle, must not be NULL
 * @param mods Modifier bitmask
 *
 * @ingroup mouse
 */
SPECTREPRO_API void spectrepro_mouse_event_set_mods(SpectreProMouseEvent event,
                                  SpectreProMods mods);

/**
 * Get keyboard modifiers held during the event.
 *
 * @param event The event handle, must not be NULL
 * @return Modifier bitmask
 *
 * @ingroup mouse
 */
SPECTREPRO_API SpectreProMods spectrepro_mouse_event_get_mods(SpectreProMouseEvent event);

/**
 * Set the event position in surface-space pixels.
 *
 * @param event The event handle, must not be NULL
 * @param position The position to set
 *
 * @ingroup mouse
 */
SPECTREPRO_API void spectrepro_mouse_event_set_position(SpectreProMouseEvent event,
                                      SpectreProMousePosition position);

/**
 * Get the event position in surface-space pixels.
 *
 * @param event The event handle, must not be NULL
 * @return The current event position
 *
 * @ingroup mouse
 */
SPECTREPRO_API SpectreProMousePosition spectrepro_mouse_event_get_position(SpectreProMouseEvent event);

#endif /* SPECTREPRO_VT_MOUSE_EVENT_H */
