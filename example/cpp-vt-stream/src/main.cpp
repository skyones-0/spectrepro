#include <cassert>
#include <cstdio>
#include <cstring>
#include <spectrepro/vt.h>

int main() {
  // Create a terminal
  SpectreProTerminal terminal;
  SpectreProResult result = spectrepro_terminal_new(nullptr, &terminal, 80, 24);
  assert(result == SPECTREPRO_SUCCESS);

  // Feed VT data into the terminal
  const char *text = "Hello from C++!\r\n";
  spectrepro_terminal_vt_write(terminal, reinterpret_cast<const uint8_t *>(text), std::strlen(text));

  text = "\x1b[1;32mGreen Text\x1b[0m\r\n";
  spectrepro_terminal_vt_write(terminal, reinterpret_cast<const uint8_t *>(text), std::strlen(text));

  text = "\x1b[1;1HTop-left corner\r\n";
  spectrepro_terminal_vt_write(terminal, reinterpret_cast<const uint8_t *>(text), std::strlen(text));

  // Get the final terminal state as a plain string
  SpectreProFormatterTerminalOptions fmt_opts =
      SPECTREPRO_INIT_SIZED(SpectreProFormatterTerminalOptions);
  fmt_opts.emit = SPECTREPRO_FORMATTER_FORMAT_PLAIN;
  fmt_opts.trim = true;

  SpectreProFormatter formatter;
  result = spectrepro_formatter_terminal_new(nullptr, &formatter, terminal, fmt_opts);
  assert(result == SPECTREPRO_SUCCESS);

  uint8_t *buf = nullptr;
  size_t len = 0;
  result = spectrepro_formatter_format_alloc(formatter, nullptr, &buf, &len);
  assert(result == SPECTREPRO_SUCCESS);

  std::fwrite(buf, 1, len, stdout);
  std::printf("\n");

  spectrepro_free(nullptr, buf, len);
  spectrepro_formatter_free(formatter);
  spectrepro_terminal_free(terminal);
  return 0;
}
