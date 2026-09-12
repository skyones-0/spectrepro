#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <spectrepro/vt.h>

//! [grid-ref-traverse]
int main() {
  // Create a small terminal
  SpectreProTerminal terminal;
  SpectreProResult result = spectrepro_terminal_new(NULL, &terminal, 10, 3);
  assert(result == SPECTREPRO_SUCCESS);

  // Write some content so the grid has interesting data
  const char *text = "Hello!\r\n"    // Row 0: H e l l o !
                     "World\r\n"     // Row 1: W o r l d
                     "\033[1mBold";   // Row 2: B o l d (bold style)
  spectrepro_terminal_vt_write(
      terminal, (const uint8_t *)text, strlen(text));

  // Get terminal dimensions
  uint16_t cols, rows;
  spectrepro_terminal_get(terminal, SPECTREPRO_TERMINAL_DATA_COLS, &cols);
  spectrepro_terminal_get(terminal, SPECTREPRO_TERMINAL_DATA_ROWS, &rows);

  // Traverse the entire grid using grid refs
  for (uint16_t row = 0; row < rows; row++) {
    printf("Row %u: ", row);
    for (uint16_t col = 0; col < cols; col++) {
      // Resolve the point to a grid reference
      SpectreProGridRef ref = SPECTREPRO_INIT_SIZED(SpectreProGridRef);
      SpectreProPoint pt = {
        .tag = SPECTREPRO_POINT_TAG_ACTIVE,
        .value = { .coordinate = { .x = col, .y = row } },
      };
      result = spectrepro_terminal_grid_ref(terminal, pt, &ref);
      assert(result == SPECTREPRO_SUCCESS);

      // Read the cell from the grid ref
      SpectreProCell cell;
      result = spectrepro_grid_ref_cell(&ref, &cell);
      assert(result == SPECTREPRO_SUCCESS);

      // Check if the cell has text
      bool has_text = false;
      spectrepro_cell_get(cell, SPECTREPRO_CELL_DATA_HAS_TEXT, &has_text);

      if (has_text) {
        uint32_t codepoint = 0;
        spectrepro_cell_get(cell, SPECTREPRO_CELL_DATA_CODEPOINT, &codepoint);
        printf("%c", (char)codepoint);
      } else {
        printf(".");
      }
    }

    // Also inspect the row for wrap state
    SpectreProGridRef ref = SPECTREPRO_INIT_SIZED(SpectreProGridRef);
    SpectreProPoint pt = {
      .tag = SPECTREPRO_POINT_TAG_ACTIVE,
      .value = { .coordinate = { .x = 0, .y = row } },
    };
    spectrepro_terminal_grid_ref(terminal, pt, &ref);

    SpectreProRow grid_row;
    spectrepro_grid_ref_row(&ref, &grid_row);

    bool wrap = false;
    spectrepro_row_get(grid_row, SPECTREPRO_ROW_DATA_WRAP, &wrap);
    printf(" (wrap=%s", wrap ? "true" : "false");

    // Check the style of the first cell with text
    SpectreProStyle style = SPECTREPRO_INIT_SIZED(SpectreProStyle);
    spectrepro_grid_ref_style(&ref, &style);
    printf(", bold=%s)\n", style.bold ? "true" : "false");
  }

  spectrepro_terminal_free(terminal);
  return 0;
}
//! [grid-ref-traverse]
