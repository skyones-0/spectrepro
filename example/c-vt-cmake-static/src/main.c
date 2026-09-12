#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <spectrepro/vt.h>

int main() {
  // Create a terminal with a small grid
  SpectreProTerminal terminal;
  SpectreProResult result = spectrepro_terminal_new(NULL, &terminal, 80, 24);
  assert(result == SPECTREPRO_SUCCESS);

  // Write some VT-encoded content into the terminal
  const char *commands[] = {
    "Hello from a \033[1mCMake\033[0m-built program (static)!\r\n",
    "Line 2: \033[4munderlined\033[0m text\r\n",
    "Line 3: \033[31mred\033[0m \033[32mgreen\033[0m \033[34mblue\033[0m\r\n",
  };
  for (size_t i = 0; i < sizeof(commands) / sizeof(commands[0]); i++) {
    spectrepro_terminal_vt_write(terminal, (const uint8_t *)commands[i],
                              strlen(commands[i]));
  }

  // Format the terminal contents as plain text
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

  printf("Plain text (%zu bytes):\n", len);
  fwrite(buf, 1, len, stdout);
  printf("\n");

  spectrepro_free(NULL, buf, len);
  spectrepro_formatter_free(formatter);
  spectrepro_terminal_free(terminal);
  return 0;
}
