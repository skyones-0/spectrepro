#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <spectrepro/vt.h>

//! [mouse-encode]
int main() {
  // Create encoder
  SpectreProMouseEncoder encoder;
  SpectreProResult result = spectrepro_mouse_encoder_new(NULL, &encoder);
  assert(result == SPECTREPRO_SUCCESS);

  // Configure SGR format with normal tracking
  spectrepro_mouse_encoder_setopt(encoder, SPECTREPRO_MOUSE_ENCODER_OPT_EVENT,
      &(SpectreProMouseTrackingMode){SPECTREPRO_MOUSE_TRACKING_NORMAL});
  spectrepro_mouse_encoder_setopt(encoder, SPECTREPRO_MOUSE_ENCODER_OPT_FORMAT,
      &(SpectreProMouseFormat){SPECTREPRO_MOUSE_FORMAT_SGR});

  // Set terminal geometry for coordinate mapping
  spectrepro_mouse_encoder_setopt(encoder, SPECTREPRO_MOUSE_ENCODER_OPT_SIZE,
      &(SpectreProMouseEncoderSize){
          .size = sizeof(SpectreProMouseEncoderSize),
          .screen_width = 800, .screen_height = 600,
          .cell_width = 10, .cell_height = 20,
      });

  // Create and configure a left button press event
  SpectreProMouseEvent event;
  result = spectrepro_mouse_event_new(NULL, &event);
  assert(result == SPECTREPRO_SUCCESS);
  spectrepro_mouse_event_set_action(event, SPECTREPRO_MOUSE_ACTION_PRESS);
  spectrepro_mouse_event_set_button(event, SPECTREPRO_MOUSE_BUTTON_LEFT);
  spectrepro_mouse_event_set_position(event,
      (SpectreProMousePosition){.x = 50.0f, .y = 40.0f});

  // Encode the mouse event
  char buf[128];
  size_t written = 0;
  result = spectrepro_mouse_encoder_encode(encoder, event,
      buf, sizeof(buf), &written);
  assert(result == SPECTREPRO_SUCCESS);

  // Use the encoded sequence (e.g., write to terminal)
  fwrite(buf, 1, written, stdout);

  // Cleanup
  spectrepro_mouse_event_free(event);
  spectrepro_mouse_encoder_free(encoder);
  return 0;
}
//! [mouse-encode]
