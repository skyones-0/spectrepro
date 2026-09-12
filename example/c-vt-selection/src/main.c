#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <spectrepro/vt.h>

//! [selection-main]
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
  SpectreProFormatterTerminalOptions opts = SPECTREPRO_INIT_SIZED(SpectreProFormatterTerminalOptions);
  opts.emit = SPECTREPRO_FORMATTER_FORMAT_PLAIN;
  opts.trim = true;
  opts.selection = selection;

  SpectreProFormatter formatter;
  SpectreProResult result = spectrepro_formatter_terminal_new(
      NULL, &formatter, terminal, opts);
  assert(result == SPECTREPRO_SUCCESS);

  uint8_t *buf = NULL;
  size_t len = 0;
  result = spectrepro_formatter_format_alloc(formatter, NULL, &buf, &len);
  assert(result == SPECTREPRO_SUCCESS);

  printf("%s: ", label);
  fwrite(buf, 1, len, stdout);
  printf("\n");

  spectrepro_free(NULL, buf, len);
  spectrepro_formatter_free(formatter);
}

int main() {
  SpectreProTerminal terminal;
  SpectreProResult result = spectrepro_terminal_new(NULL, &terminal, 80, 8);
  assert(result == SPECTREPRO_SUCCESS);

  // A realistic shell transcript with OSC 133 semantic prompt markers.
  // SpectrePro uses these markers to distinguish prompt/input from command
  // output for semantic line and output selections.
  vt_write(terminal,
      "\033]133;A\007$ "           // Prompt starts: "$ "
      "\033]133;B\007git status"  // Input starts: "git status"
      "\033]133;C\007\r\n"        // Output starts after Enter
      "On branch main\r\n"
      "nothing to commit, working tree clean");

  SpectreProSelection selection = SPECTREPRO_INIT_SIZED(SpectreProSelection);

  // Double-click style word selection under the cursor.
  SpectreProTerminalSelectWordOptions word = SPECTREPRO_INIT_SIZED(SpectreProTerminalSelectWordOptions);
  word.ref = ref_at(terminal, 6, 0); // the "status" in "git status"
  result = spectrepro_terminal_select_word(terminal, &word, &selection);
  assert(result == SPECTREPRO_SUCCESS);
  print_selection(terminal, "word", &selection);

  //! [selection-word-between]
  // Double-click-and-drag style selection. Suppose the user double-clicks
  // "git" and drags to "status". The pointer may pass over whitespace, so
  // select the nearest word between the original click and current drag point
  // in both directions, then combine the outer word bounds.
  SpectreProGridRef click_ref = ref_at(terminal, 2, 0); // the "git" in "git status"
  SpectreProGridRef drag_ref = ref_at(terminal, 6, 0);  // the "status" in "git status"

  SpectreProTerminalSelectWordBetweenOptions start_word_opts =
      SPECTREPRO_INIT_SIZED(SpectreProTerminalSelectWordBetweenOptions);
  start_word_opts.start = click_ref;
  start_word_opts.end = drag_ref;

  SpectreProSelection start_word = SPECTREPRO_INIT_SIZED(SpectreProSelection);
  result = spectrepro_terminal_select_word_between(
      terminal, &start_word_opts, &start_word);
  assert(result == SPECTREPRO_SUCCESS);

  SpectreProTerminalSelectWordBetweenOptions end_word_opts =
      SPECTREPRO_INIT_SIZED(SpectreProTerminalSelectWordBetweenOptions);
  end_word_opts.start = drag_ref;
  end_word_opts.end = click_ref;

  SpectreProSelection end_word = SPECTREPRO_INIT_SIZED(SpectreProSelection);
  result = spectrepro_terminal_select_word_between(
      terminal, &end_word_opts, &end_word);
  assert(result == SPECTREPRO_SUCCESS);

  SpectreProSelection drag_selection = SPECTREPRO_INIT_SIZED(SpectreProSelection);
  drag_selection.start = start_word.start;
  drag_selection.end = end_word.end;
  print_selection(terminal, "double-click drag", &drag_selection);
  //! [selection-word-between]

  // Triple-click style line selection. With semantic prompt boundaries enabled,
  // this selects only the input area rather than the leading "$ " prompt.
  SpectreProTerminalSelectLineOptions line = SPECTREPRO_INIT_SIZED(SpectreProTerminalSelectLineOptions);
  line.ref = ref_at(terminal, 2, 0); // the "git status" input area
  line.semantic_prompt_boundary = true;
  result = spectrepro_terminal_select_line(terminal, &line, &selection);
  assert(result == SPECTREPRO_SUCCESS);
  print_selection(terminal, "line", &selection);

  // Select exactly the command output for the command under the cursor.
  result = spectrepro_terminal_select_output(
      terminal, ref_at(terminal, 0, 1), &selection);
  assert(result == SPECTREPRO_SUCCESS);
  print_selection(terminal, "output", &selection);

  // Select all visible content.
  result = spectrepro_terminal_select_all(terminal, &selection);
  assert(result == SPECTREPRO_SUCCESS);
  print_selection(terminal, "all", &selection);

  spectrepro_terminal_free(terminal);
  return 0;
}
//! [selection-main]
