#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <spectrepro/vt.h>

//! [key-encode]
int main() {
  // Create encoder
  SpectreProKeyEncoder encoder;
  SpectreProResult result = spectrepro_key_encoder_new(NULL, &encoder);
  assert(result == SPECTREPRO_SUCCESS);

  // Enable Kitty keyboard protocol with all features
  spectrepro_key_encoder_setopt(encoder, SPECTREPRO_KEY_ENCODER_OPT_KITTY_FLAGS,
                             &(uint8_t){SPECTREPRO_KITTY_KEY_ALL});

  // Create and configure key event for Ctrl+C press
  SpectreProKeyEvent event;
  result = spectrepro_key_event_new(NULL, &event);
  assert(result == SPECTREPRO_SUCCESS);
  spectrepro_key_event_set_action(event, SPECTREPRO_KEY_ACTION_PRESS);
  spectrepro_key_event_set_key(event, SPECTREPRO_KEY_C);
  spectrepro_key_event_set_mods(event, SPECTREPRO_MODS_CTRL);

  // Encode the key event
  char buf[128];
  size_t written = 0;
  result = spectrepro_key_encoder_encode(encoder, event, buf, sizeof(buf), &written);
  assert(result == SPECTREPRO_SUCCESS);

  // Use the encoded sequence (e.g., write to terminal)
  fwrite(buf, 1, written, stdout);

  // Cleanup
  spectrepro_key_event_free(event);
  spectrepro_key_encoder_free(encoder);
  return 0;
}
//! [key-encode]
