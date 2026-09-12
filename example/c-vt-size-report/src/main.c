#include <stdio.h>
#include <spectrepro/vt.h>

//! [size-report-encode]
int main() {
  SpectreProSizeReportSize size = {
    .rows = 24,
    .columns = 80,
    .cell_width = 9,
    .cell_height = 18,
  };

  char buf[64];
  size_t written = 0;

  SpectreProResult result = spectrepro_size_report_encode(
      SPECTREPRO_SIZE_REPORT_MODE_2048, size, buf, sizeof(buf), &written);

  if (result == SPECTREPRO_SUCCESS) {
    printf("Encoded %zu bytes: ", written);
    fwrite(buf, 1, written, stdout);
    printf("\n");
  }

  return 0;
}
//! [size-report-encode]
