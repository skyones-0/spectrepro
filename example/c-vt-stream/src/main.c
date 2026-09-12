#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <spectrepro/vt.h>

int main(void) {
  //! [vt-stream-init]
  // Create a terminal
  SpectreProTerminal terminal;
  SpectreProResult result = spectrepro_terminal_new(NULL, &terminal, 80, 24);
  assert(result == SPECTREPRO_SUCCESS);
  //! [vt-stream-init]

  //! [vt-stream-write]
  // Feed VT data into the terminal
  const char *text = "Hello, World!\r\n";
  spectrepro_terminal_vt_write(terminal, (const uint8_t *)text, strlen(text));

  // ANSI color codes: ESC[1;32m = bold green, ESC[0m = reset
  text = "\x1b[1;32mGreen Text\x1b[0m\r\n";
  spectrepro_terminal_vt_write(terminal, (const uint8_t *)text, strlen(text));

  // Cursor positioning: ESC[1;1H = move to row 1, column 1
  text = "\x1b[1;1HTop-left corner\r\n";
  spectrepro_terminal_vt_write(terminal, (const uint8_t *)text, strlen(text));

  // Cursor movement: ESC[5B = move down 5 lines
  text = "\x1b[5B";
  spectrepro_terminal_vt_write(terminal, (const uint8_t *)text, strlen(text));
  text = "Moved down!\r\n";
  spectrepro_terminal_vt_write(terminal, (const uint8_t *)text, strlen(text));

  // Erase line: ESC[2K = clear entire line
  text = "\x1b[2K";
  spectrepro_terminal_vt_write(terminal, (const uint8_t *)text, strlen(text));
  text = "New content\r\n";
  spectrepro_terminal_vt_write(terminal, (const uint8_t *)text, strlen(text));

  // Multiple lines
  text = "Line A\r\nLine B\r\nLine C\r\n";
  spectrepro_terminal_vt_write(terminal, (const uint8_t *)text, strlen(text));
  //! [vt-stream-write]

  //! [vt-stream-read]
  // Get the final terminal state as a plain string using the formatter
  SpectreProFormatterTerminalOptions fmt_opts =
      SPECTREPRO_INIT_SIZED(SpectreProFormatterTerminalOptions);
  fmt_opts.emit = SPECTREPRO_FORMATTER_FORMAT_PLAIN;
  fmt_opts.trim = true;

  SpectreProFormatter formatter;
  result = spectrepro_formatter_terminal_new(NULL, &formatter, terminal, fmt_opts);
  assert(result == SPECTREPRO_SUCCESS);

  uint8_t *buf = NULL;
  size_t len = 0;
  result = spectrepro_formatter_format_alloc(formatter, NULL, &buf, &len);
  assert(result == SPECTREPRO_SUCCESS);

  fwrite(buf, 1, len, stdout);
  printf("\n");

  spectrepro_free(NULL, buf, len);
  spectrepro_formatter_free(formatter);
  //! [vt-stream-read]

  spectrepro_terminal_free(terminal);
  return 0;
}
