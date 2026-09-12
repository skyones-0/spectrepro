#include <stdio.h>
#include <spectrepro/vt.h>

//! [color-scheme-report-encode]
int main() {
  char buf[16];
  size_t written = 0;

  SpectreProResult result = spectrepro_color_scheme_report_encode(
      SPECTREPRO_COLOR_SCHEME_DARK, buf, sizeof(buf), &written);

  if (result == SPECTREPRO_SUCCESS) {
    printf("Encoded %zu bytes: ", written);
    fwrite(buf, 1, written, stdout);
    printf("\n");
  }

  return 0;
}
//! [color-scheme-report-encode]
