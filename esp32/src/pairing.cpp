#include "pairing.h"
#include <esp_random.h>
#include <stdio.h>

void Pairing::setup() {
  char buffer[7];
  for (int i = 0; i < 6; ++i) {
    buffer[i] = '0' + (esp_random() % 10);
  }
  buffer[6] = '\0';
  Serial.print("Pairing code: ");
  Serial.println(buffer);
}
