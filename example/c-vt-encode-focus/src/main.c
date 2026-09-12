#include <stdio.h>
#include <spectrepro/vt.h>

//! [focus-encode]
int main() {
  char buf[8];
  size_t written = 0;

  SpectreProResult result = spectrepro_focus_encode(
      SPECTREPRO_FOCUS_GAINED, buf, sizeof(buf), &written);

  if (result == SPECTREPRO_SUCCESS) {
    printf("Encoded %zu bytes: ", written);
    fwrite(buf, 1, written, stdout);
    printf("\n");
  }

  return 0;
}
//! [focus-encode]
