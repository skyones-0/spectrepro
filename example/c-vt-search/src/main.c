#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <spectrepro/vt.h>

//! [search-main]
int main() {
  // Create a terminal and fill it with some content to search.
  SpectreProTerminal terminal;
  SpectreProResult result = spectrepro_terminal_new(NULL, &terminal, 80, 24);
  assert(result == SPECTREPRO_SUCCESS);

  const char *lines[] = {
    "$ make test\r\n",
    "compiling module A... ok\r\n",
    "compiling module B... error: missing semicolon\r\n",
    "linking... error: undefined symbol\r\n",
    "$ grep -n ERROR build.log\r\n",
  };
  for (size_t i = 0; i < sizeof(lines) / sizeof(lines[0]); i++) {
    spectrepro_terminal_vt_write(terminal, (const uint8_t *)lines[i],
                              strlen(lines[i]));
  }

  // The user opened the find bar, so create a search bound to the
  // terminal. It starts idle until it has a needle.
  SpectreProSearch search;
  result = spectrepro_search_new(NULL, &search, terminal);
  assert(result == SPECTREPRO_SUCCESS);

  // The user typed a query. Matching is byte-exact except ASCII
  // letters, which compare case-insensitively, so "error" also finds
  // "ERROR". Retyping just sets the needle again: a changed needle
  // restarts the search and an unchanged one keeps its results.
  SpectreProString needle = { (const uint8_t *)"error", 5 };
  result = spectrepro_search_set(search, SPECTREPRO_SEARCH_OPT_NEEDLE, &needle);
  assert(result == SPECTREPRO_SUCCESS);

  // Drive the search. Interactive embedders interleave
  // spectrepro_search_tick() and spectrepro_search_feed() with their event
  // loop, but for a one-shot search we can just run it to completion.
  result = spectrepro_search_run(search);
  assert(result == SPECTREPRO_SUCCESS);

  // The total match count, for find bar text like "1 of 3".
  size_t total = 0;
  result = spectrepro_search_get(search, SPECTREPRO_SEARCH_DATA_TOTAL_MATCHES,
                              &total);
  assert(result == SPECTREPRO_SUCCESS);
  printf("%zu matches for \"error\"\n", total);

  // The user pressed Enter, so select the next match. Selection starts
  // at the newest match, moves toward older content, and wraps around.
  // This scrolls the viewport to the match if it isn't visible, per
  // the SPECTREPRO_SEARCH_OPT_SELECT_SCROLL policy.
  while (true) {
    result = spectrepro_search_set(search, SPECTREPRO_SEARCH_OPT_SELECT_NEXT, NULL);
    if (result != SPECTREPRO_SUCCESS) break;

    // Read the selection state in one call. Index 0 is the newest
    // match, so a "k of n" find bar renders index + 1.
    size_t idx = 0;
    SpectreProSelection match = SPECTREPRO_INIT_SIZED(SpectreProSelection);
    const SpectreProSearchData keys[] = {
      SPECTREPRO_SEARCH_DATA_SELECTED_INDEX,
      SPECTREPRO_SEARCH_DATA_SELECTED_MATCH,
    };
    void *values[] = { &idx, &match };
    result = spectrepro_search_get_multi(
        search, sizeof(keys) / sizeof(keys[0]), keys, values, NULL);
    assert(result == SPECTREPRO_SUCCESS);
    printf("selected %zu of %zu\n", idx + 1, total);

    // Wrapped back around to the first match: stop.
    if (idx + 1 == total) break;
  }

  // Each frame while the find bar is open, feed to catch up with any
  // terminal changes and then read the viewport matches to draw
  // highlights. The list can include matches just past the viewport
  // when they share a page with it, so convert each endpoint to
  // viewport coordinates and skip matches outside the visible rows.
  result = spectrepro_search_feed(search);
  assert(result == SPECTREPRO_SUCCESS);

  SpectreProSelection viewport_storage[64];
  SpectreProSelectionBuffer viewport = {
    .ptr = viewport_storage,
    .cap = sizeof(viewport_storage) / sizeof(viewport_storage[0]),
  };
  result = spectrepro_search_get(search, SPECTREPRO_SEARCH_DATA_VIEWPORT_MATCHES,
                              &viewport);
  assert(result == SPECTREPRO_SUCCESS);
  for (size_t i = 0; i < viewport.len; i++) {
    SpectreProPointCoordinate start, end;
    if (spectrepro_terminal_point_from_grid_ref(
            terminal, &viewport_storage[i].start, SPECTREPRO_POINT_TAG_VIEWPORT,
            &start) != SPECTREPRO_SUCCESS) continue;
    if (spectrepro_terminal_point_from_grid_ref(
            terminal, &viewport_storage[i].end, SPECTREPRO_POINT_TAG_VIEWPORT,
            &end) != SPECTREPRO_SUCCESS) continue;
    if (start.y >= 24 || end.y >= 24) continue;

    // A real embedder draws a highlight rect from start to end here.
    printf("highlight rows %u-%u, cols %u-%u\n",
           (unsigned)start.y, (unsigned)end.y,
           (unsigned)start.x, (unsigned)end.x);
  }

  // Closing the find bar. The search borrows the terminal, but the
  // two can be freed in either order.
  spectrepro_search_free(search);
  spectrepro_terminal_free(terminal);
  return 0;
}
//! [search-main]
