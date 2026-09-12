#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <spectrepro/vt.h>

int main() {
  SpectreProOscParser parser;
  if (spectrepro_osc_new(NULL, &parser) != SPECTREPRO_SUCCESS) {
    return 1;
  }
  
  // Setup change window title command to change the title to "hello"
  spectrepro_osc_next(parser, '0');
  spectrepro_osc_next(parser, ';');
  const char *title = "hello";
  for (size_t i = 0; i < strlen(title); i++) {
    spectrepro_osc_next(parser, title[i]);
  }
  
  // End parsing and get command
  SpectreProOscCommand command = spectrepro_osc_end(parser, 0);
  
  // Get and print command type
  SpectreProOscCommandType type = spectrepro_osc_command_type(command);
  printf("Command type: %d\n", type);
  
  // Extract and print the title
  if (spectrepro_osc_command_data(command, SPECTREPRO_OSC_DATA_CHANGE_WINDOW_TITLE_STR, &title)) {
    printf("Extracted title: %s\n", title);
  } else {
    printf("Failed to extract title\n");
  }
  
  spectrepro_osc_free(parser);
  return 0;
}
