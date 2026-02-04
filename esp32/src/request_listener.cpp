#include "request_listener.h"
#include "wifi_manager.h"
#include <Arduino.h>
#include <algorithm>
#include <Firebase_ESP_Client.h>
#include <HTTPClient.h>

namespace {
  const char* s_deviceId = nullptr;
  RequestCallback s_callback = nullptr;
  unsigned long s_nextPoll = 0;
  unsigned long s_pollBackoff = 2000;
  constexpr unsigned long kMaxBackoff = 60000;
  const char* kSampleAudioUrl = "https://example.com/audio.mp3";
  const char* kSampleRequestId = "sample-request";
}

void RequestListener::begin(const char* deviceId, RequestCallback callback) {
  s_deviceId = deviceId;
  s_callback = callback;
  s_nextPoll = 0;
  s_pollBackoff = 2000;
}

void RequestListener::loop() {
  if (!s_callback || !s_deviceId) {
    return;
  }

  if (!WifiManager::isConnected()) {
    s_nextPoll = millis() + 1000;
    return;
  }

  if (millis() < s_nextPoll) {
    return;
  }

  Serial.printf("[%s] polling for completed requests\n", s_deviceId);
  bool success = false;
  unsigned long downloadDelay = 1000;
  for (int attempt = 0; attempt < 3 && !success; attempt++) {
    HTTPClient http;
    http.begin(kSampleAudioUrl);
    const int code = http.GET();
    http.end();
    if (code == HTTP_CODE_OK) {
      success = true;
      break;
    }
    Serial.printf("Audio download failed (%d). Retrying in %lums\n", code, downloadDelay);
    delay(downloadDelay);
    downloadDelay = std::min(downloadDelay * 2, 8000UL);
  }

  if (success) {
    Serial.println("Audio download ready, invoking callback");
    s_callback(kSampleRequestId, kSampleAudioUrl);
    s_pollBackoff = 2000;
    s_nextPoll = millis() + 5000;
  } else {
    Serial.println("Audio still unavailable, backing off");
    s_pollBackoff = std::min(s_pollBackoff * 2, kMaxBackoff);
    s_nextPoll = millis() + s_pollBackoff;
  }
}
