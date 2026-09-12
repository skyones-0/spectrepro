#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <spectrepro/vt.h>

//! [grid-ref-tracked]
static uint32_t codepoint_at_tracked_ref(SpectreProTrackedGridRef tracked) {
  SpectreProGridRef snapshot = SPECTREPRO_INIT_SIZED(SpectreProGridRef);
  SpectreProResult result = spectrepro_tracked_grid_ref_snapshot(tracked, &snapshot);
  assert(result == SPECTREPRO_SUCCESS);

  SpectreProCell cell;
  result = spectrepro_grid_ref_cell(&snapshot, &cell);
  assert(result == SPECTREPRO_SUCCESS);

  bool has_text = false;
  spectrepro_cell_get(cell, SPECTREPRO_CELL_DATA_HAS_TEXT, &has_text);
  assert(has_text);

  uint32_t codepoint = 0;
  spectrepro_cell_get(cell, SPECTREPRO_CELL_DATA_CODEPOINT, &codepoint);
  return codepoint;
}

int main() {
  SpectreProTerminal terminal;
  SpectreProResult result = spectrepro_terminal_new(NULL, &terminal, 8, 3);
  assert(result == SPECTREPRO_SUCCESS);

  const char *text = "alpha\r\n"
                     "bravo\r\n"
                     "charlie";
  spectrepro_terminal_vt_write(
      terminal, (const uint8_t *)text, strlen(text));

  SpectreProTrackedGridRef tracked = NULL;
  SpectreProPoint alpha = {
    .tag = SPECTREPRO_POINT_TAG_ACTIVE,
    .value = { .coordinate = { .x = 0, .y = 0 } },
  };
  result = spectrepro_terminal_grid_ref_track(terminal, alpha, &tracked);
  assert(result == SPECTREPRO_SUCCESS);

  // Writing another line scrolls the original "alpha" row into scrollback.
  // The tracked ref still follows the same cell.
  const char *more = "\r\ndelta";
  spectrepro_terminal_vt_write(
      terminal, (const uint8_t *)more, strlen(more));

  assert(spectrepro_tracked_grid_ref_has_value(tracked));
  printf("tracked codepoint after scroll: %c\n",
      (char)codepoint_at_tracked_ref(tracked));

  SpectreProPointCoordinate screen = {0};
  result = spectrepro_tracked_grid_ref_point(
      tracked, SPECTREPRO_POINT_TAG_SCREEN, &screen);
  assert(result == SPECTREPRO_SUCCESS);
  printf("tracked screen point: %u,%u\n", screen.x, screen.y);

  // Resetting the terminal discards the old grid contents. The tracked
  // handle remains valid, but no longer has a meaningful location.
  spectrepro_terminal_reset(terminal);
  assert(!spectrepro_tracked_grid_ref_has_value(tracked));

  SpectreProGridRef discarded = SPECTREPRO_INIT_SIZED(SpectreProGridRef);
  result = spectrepro_tracked_grid_ref_snapshot(tracked, &discarded);
  assert(result == SPECTREPRO_NO_VALUE);

  // The same handle can be moved to a new point after it loses its value.
  const char *replacement = "echo";
  spectrepro_terminal_vt_write(
      terminal, (const uint8_t *)replacement, strlen(replacement));

  SpectreProPoint echo = {
    .tag = SPECTREPRO_POINT_TAG_ACTIVE,
    .value = { .coordinate = { .x = 0, .y = 0 } },
  };
  result = spectrepro_tracked_grid_ref_set(tracked, terminal, echo);
  assert(result == SPECTREPRO_SUCCESS);
  assert(spectrepro_tracked_grid_ref_has_value(tracked));
  printf("tracked codepoint after reset/set: %c\n",
      (char)codepoint_at_tracked_ref(tracked));

  spectrepro_tracked_grid_ref_free(tracked);
  spectrepro_terminal_free(terminal);
  return 0;
}
//! [grid-ref-tracked]
