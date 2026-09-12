#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <spectrepro/vt.h>

//! [compression-idle-step]
// Perform one step after the application's idle timer fires. Returning true
// asks the application to schedule another step while the terminal is idle.
static bool compression_idle_step(SpectreProTerminal terminal) {
  SpectreProTerminalCompressionResult compression_result;
  SpectreProResult result = spectrepro_terminal_compress(
      terminal,
      SPECTREPRO_TERMINAL_COMPRESSION_MODE_INCREMENTAL,
      &compression_result);
  assert(result == SPECTREPRO_SUCCESS);

  switch (compression_result) {
    case SPECTREPRO_TERMINAL_COMPRESSION_RESULT_PENDING:
      return true;
    case SPECTREPRO_TERMINAL_COMPRESSION_RESULT_COMPLETE:
    case SPECTREPRO_TERMINAL_COMPRESSION_RESULT_UNSUPPORTED:
      return false;
    default:
      assert(false);
      return false;
  }
}
//! [compression-idle-step]

int main(void) {
  SpectreProTerminal terminal;
  SpectreProResult result = spectrepro_terminal_new(NULL, &terminal, 80, 24);
  assert(result == SPECTREPRO_SUCCESS);

  size_t max_scrollback_bytes = 10 * 1024 * 1024;
  result = spectrepro_terminal_set(
      terminal,
      SPECTREPRO_TERMINAL_OPT_SCROLLBACK_MAX_BYTES,
      &max_scrollback_bytes);
  assert(result == SPECTREPRO_SUCCESS);

  //! [compression-activity]
  uint64_t compression_activity;
  result = spectrepro_terminal_compression_activity(
      terminal,
      &compression_activity);
  assert(result == SPECTREPRO_SUCCESS);

  // Terminal mutations may change the token. When it changes, restart the
  // application's idle timer rather than compressing on the output path.
  const char *line = "repeated and compressible terminal history\r\n";
  for (size_t i = 0; i < 4000; i++) {
    spectrepro_terminal_vt_write(
        terminal,
        (const uint8_t *)line,
        strlen(line));
  }

  uint64_t new_activity;
  result = spectrepro_terminal_compression_activity(terminal, &new_activity);
  assert(result == SPECTREPRO_SUCCESS);
  if (new_activity != compression_activity) {
    compression_activity = new_activity;
    // Restart the application's compression idle timer here.
  }
  //! [compression-activity]

  // Simulate the idle timer and its short pending-work continuations.
  while (compression_idle_step(terminal)) {}

  spectrepro_terminal_free(terminal);
  return 0;
}
