#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <spectrepro/vt.h>

//! [selection-gesture-main]
static void vt_write(SpectreProTerminal terminal, const char *s) {
  spectrepro_terminal_vt_write(terminal, (const uint8_t *)s, strlen(s));
}

static SpectreProGridRef ref_at(SpectreProTerminal terminal, uint16_t x, uint16_t y) {
  SpectreProGridRef ref = SPECTREPRO_INIT_SIZED(SpectreProGridRef);
  SpectreProPoint point = {
    .tag = SPECTREPRO_POINT_TAG_ACTIVE,
    .value = { .coordinate = { .x = x, .y = y } },
  };

  SpectreProResult result = spectrepro_terminal_grid_ref(terminal, point, &ref);
  assert(result == SPECTREPRO_SUCCESS);
  return ref;
}

static void print_selection(
    SpectreProTerminal terminal,
    const char *label,
    const SpectreProSelection *selection) {
  SpectreProTerminalSelectionFormatOptions opts =
      SPECTREPRO_INIT_SIZED(SpectreProTerminalSelectionFormatOptions);
  opts.emit = SPECTREPRO_FORMATTER_FORMAT_PLAIN;
  opts.trim = true;
  opts.selection = selection;

  uint8_t *buf = NULL;
  size_t len = 0;
  SpectreProResult result = spectrepro_terminal_selection_format_alloc(
      terminal, NULL, opts, &buf, &len);
  assert(result == SPECTREPRO_SUCCESS);

  printf("%s: ", label);
  fwrite(buf, 1, len, stdout);
  printf("\n");

  spectrepro_free(NULL, buf, len);
}

static SpectreProSelectionGestureEvent new_event(
    SpectreProSelectionGestureEventType type) {
  SpectreProSelectionGestureEvent event = NULL;
  SpectreProResult result = spectrepro_selection_gesture_event_new(NULL, &event, type);
  assert(result == SPECTREPRO_SUCCESS);
  return event;
}

int main() {
  SpectreProTerminal terminal;
  SpectreProResult result = spectrepro_terminal_new(NULL, &terminal, 20, 4);
  assert(result == SPECTREPRO_SUCCESS);

  vt_write(terminal, "hello world\r\nsecond line");

  SpectreProSelectionGesture gesture = NULL;
  result = spectrepro_selection_gesture_new(NULL, &gesture);
  assert(result == SPECTREPRO_SUCCESS);

  SpectreProSelectionGestureEvent press =
      new_event(SPECTREPRO_SELECTION_GESTURE_EVENT_TYPE_PRESS);
  SpectreProSelectionGestureEvent drag =
      new_event(SPECTREPRO_SELECTION_GESTURE_EVENT_TYPE_DRAG);
  SpectreProSelectionGestureEvent release =
      new_event(SPECTREPRO_SELECTION_GESTURE_EVENT_TYPE_RELEASE);
  SpectreProSelectionGestureEvent deep_press =
      new_event(SPECTREPRO_SELECTION_GESTURE_EVENT_TYPE_DEEP_PRESS);

  SpectreProSelectionGestureGeometry geometry = {
    .columns = 20,
    .cell_width = 10,
    .padding_left = 0,
    .screen_height = 40,
  };

  // Press in the first cell. A normal single press records the click anchor but
  // doesn't produce a selection yet, so we discard the optional output.
  SpectreProGridRef press_ref = ref_at(terminal, 0, 0);
  result = spectrepro_selection_gesture_event_set(
      press, SPECTREPRO_SELECTION_GESTURE_EVENT_OPT_REF, &press_ref);
  assert(result == SPECTREPRO_SUCCESS);

  SpectreProSurfacePosition press_pos = { .x = 2, .y = 8 };
  result = spectrepro_selection_gesture_event_set(
      press, SPECTREPRO_SELECTION_GESTURE_EVENT_OPT_POSITION, &press_pos);
  assert(result == SPECTREPRO_SUCCESS);

  result = spectrepro_selection_gesture_event(
      gesture, terminal, press, NULL);
  assert(result == SPECTREPRO_NO_VALUE);

  // Drag across "hello". The drag event returns a selection snapshot that the
  // embedder can apply to its UI, copy, or format immediately.
  SpectreProGridRef drag_ref = ref_at(terminal, 4, 0);
  result = spectrepro_selection_gesture_event_set(
      drag, SPECTREPRO_SELECTION_GESTURE_EVENT_OPT_REF, &drag_ref);
  assert(result == SPECTREPRO_SUCCESS);

  SpectreProSurfacePosition drag_pos = { .x = 46, .y = 8 };
  result = spectrepro_selection_gesture_event_set(
      drag, SPECTREPRO_SELECTION_GESTURE_EVENT_OPT_POSITION, &drag_pos);
  assert(result == SPECTREPRO_SUCCESS);

  result = spectrepro_selection_gesture_event_set(
      drag, SPECTREPRO_SELECTION_GESTURE_EVENT_OPT_GEOMETRY, &geometry);
  assert(result == SPECTREPRO_SUCCESS);

  SpectreProSelection selection = SPECTREPRO_INIT_SIZED(SpectreProSelection);
  result = spectrepro_selection_gesture_event(
      gesture, terminal, drag, &selection);
  assert(result == SPECTREPRO_SUCCESS);
  print_selection(terminal, "drag", &selection);

  // Release updates gesture state but never produces a selection.
  result = spectrepro_selection_gesture_event_set(
      release, SPECTREPRO_SELECTION_GESTURE_EVENT_OPT_REF, &drag_ref);
  assert(result == SPECTREPRO_SUCCESS);
  result = spectrepro_selection_gesture_event(
      gesture, terminal, release, NULL);
  assert(result == SPECTREPRO_NO_VALUE);

  bool dragged = false;
  result = spectrepro_selection_gesture_get(
      gesture, terminal, SPECTREPRO_SELECTION_GESTURE_DATA_DRAGGED, &dragged);
  assert(result == SPECTREPRO_SUCCESS);
  printf("dragged: %s\n", dragged ? "true" : "false");

  // Deep press uses the active click anchor to select the surrounding word.
  spectrepro_selection_gesture_reset(gesture, terminal);
  SpectreProGridRef world_ref = ref_at(terminal, 6, 0);
  result = spectrepro_selection_gesture_event_set(
      press, SPECTREPRO_SELECTION_GESTURE_EVENT_OPT_REF, &world_ref);
  assert(result == SPECTREPRO_SUCCESS);
  result = spectrepro_selection_gesture_event(
      gesture, terminal, press, NULL);
  assert(result == SPECTREPRO_NO_VALUE);

  result = spectrepro_selection_gesture_event(
      gesture, terminal, deep_press, &selection);
  assert(result == SPECTREPRO_SUCCESS);
  print_selection(terminal, "deep press", &selection);

  spectrepro_selection_gesture_event_free(deep_press);
  spectrepro_selection_gesture_event_free(release);
  spectrepro_selection_gesture_event_free(drag);
  spectrepro_selection_gesture_event_free(press);
  spectrepro_selection_gesture_free(gesture, terminal);
  spectrepro_terminal_free(terminal);
  return 0;
}
//! [selection-gesture-main]
