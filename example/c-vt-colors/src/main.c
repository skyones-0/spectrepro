#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <spectrepro/vt.h>

//! [colors-set-defaults]
/// Set up a dark color theme with custom palette entries.
void set_color_theme(SpectreProTerminal terminal) {
  // Set default foreground (light gray) and background (dark)
  SpectreProColorRgb fg = { .r = 0xDD, .g = 0xDD, .b = 0xDD };
  SpectreProColorRgb bg = { .r = 0x1E, .g = 0x1E, .b = 0x2E };
  SpectreProColorRgb cursor = { .r = 0xF5, .g = 0xE0, .b = 0xDC };

  spectrepro_terminal_set(terminal, SPECTREPRO_TERMINAL_OPT_COLOR_FOREGROUND, &fg);
  spectrepro_terminal_set(terminal, SPECTREPRO_TERMINAL_OPT_COLOR_BACKGROUND, &bg);
  spectrepro_terminal_set(terminal, SPECTREPRO_TERMINAL_OPT_COLOR_CURSOR, &cursor);

  // Set a custom palette — start from the built-in default and override
  // the first 8 entries with a custom dark theme.
  SpectreProColorRgb palette[256];
  spectrepro_terminal_get(terminal, SPECTREPRO_TERMINAL_DATA_COLOR_PALETTE, palette);

  palette[SPECTREPRO_COLOR_NAMED_BLACK]   = (SpectreProColorRgb){ 0x45, 0x47, 0x5A };
  palette[SPECTREPRO_COLOR_NAMED_RED]     = (SpectreProColorRgb){ 0xF3, 0x8B, 0xA8 };
  palette[SPECTREPRO_COLOR_NAMED_GREEN]   = (SpectreProColorRgb){ 0xA6, 0xE3, 0xA1 };
  palette[SPECTREPRO_COLOR_NAMED_YELLOW]  = (SpectreProColorRgb){ 0xF9, 0xE2, 0xAF };
  palette[SPECTREPRO_COLOR_NAMED_BLUE]    = (SpectreProColorRgb){ 0x89, 0xB4, 0xFA };
  palette[SPECTREPRO_COLOR_NAMED_MAGENTA] = (SpectreProColorRgb){ 0xF5, 0xC2, 0xE7 };
  palette[SPECTREPRO_COLOR_NAMED_CYAN]    = (SpectreProColorRgb){ 0x94, 0xE2, 0xD5 };
  palette[SPECTREPRO_COLOR_NAMED_WHITE]   = (SpectreProColorRgb){ 0xBA, 0xC2, 0xDE };

  spectrepro_terminal_set(terminal, SPECTREPRO_TERMINAL_OPT_COLOR_PALETTE, palette);
}
//! [colors-set-defaults]

//! [colors-read]
/// Print the effective and default values for a color, showing how
/// OSC overrides layer on top of defaults.
void print_color(SpectreProTerminal terminal,
                 const char* name,
                 SpectreProTerminalData effective_data,
                 SpectreProTerminalData default_data) {
  SpectreProColorRgb color;

  SpectreProResult res = spectrepro_terminal_get(terminal, effective_data, &color);
  if (res == SPECTREPRO_SUCCESS) {
    printf("  %-12s effective: #%02X%02X%02X", name, color.r, color.g, color.b);
  } else {
    printf("  %-12s effective: (not set)", name);
  }

  res = spectrepro_terminal_get(terminal, default_data, &color);
  if (res == SPECTREPRO_SUCCESS) {
    printf("  default: #%02X%02X%02X\n", color.r, color.g, color.b);
  } else {
    printf("  default: (not set)\n");
  }
}

void print_all_colors(SpectreProTerminal terminal, const char* label) {
  printf("%s:\n", label);
  print_color(terminal, "foreground",
      SPECTREPRO_TERMINAL_DATA_COLOR_FOREGROUND,
      SPECTREPRO_TERMINAL_DATA_COLOR_FOREGROUND_DEFAULT);
  print_color(terminal, "background",
      SPECTREPRO_TERMINAL_DATA_COLOR_BACKGROUND,
      SPECTREPRO_TERMINAL_DATA_COLOR_BACKGROUND_DEFAULT);
  print_color(terminal, "cursor",
      SPECTREPRO_TERMINAL_DATA_COLOR_CURSOR,
      SPECTREPRO_TERMINAL_DATA_COLOR_CURSOR_DEFAULT);

  // Show palette index 0 (black) as an example
  SpectreProColorRgb palette[256];
  spectrepro_terminal_get(terminal, SPECTREPRO_TERMINAL_DATA_COLOR_PALETTE, palette);
  printf("  %-12s effective: #%02X%02X%02X", "palette[0]",
      palette[0].r, palette[0].g, palette[0].b);

  spectrepro_terminal_get(terminal, SPECTREPRO_TERMINAL_DATA_COLOR_PALETTE_DEFAULT,
      palette);
  printf("  default: #%02X%02X%02X\n", palette[0].r, palette[0].g, palette[0].b);
}
//! [colors-read]

//! [colors-main]
int main() {
  // Create a terminal
  SpectreProTerminal terminal = NULL;
  if (spectrepro_terminal_new(NULL, &terminal, 80, 24) != SPECTREPRO_SUCCESS) {
    fprintf(stderr, "Failed to create terminal\n");
    return 1;
  }

  // Before setting any colors, everything is unset
  print_all_colors(terminal, "Before setting defaults");

  // Set our color theme defaults
  set_color_theme(terminal);
  print_all_colors(terminal, "\nAfter setting defaults");

  // Simulate an OSC override (e.g. a program running inside the
  // terminal changes the foreground via OSC 10)
  const char* osc_fg = "\x1B]10;rgb:FF/00/00\x1B\\";
  spectrepro_terminal_vt_write(terminal, (const uint8_t*)osc_fg,
                            strlen(osc_fg));
  print_all_colors(terminal, "\nAfter OSC foreground override");

  // Clear the foreground default — the OSC override is still active
  spectrepro_terminal_set(terminal, SPECTREPRO_TERMINAL_OPT_COLOR_FOREGROUND, NULL);
  print_all_colors(terminal, "\nAfter clearing foreground default");

  spectrepro_terminal_free(terminal);
  return 0;
}
//! [colors-main]
