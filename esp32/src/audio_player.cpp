#include "audio_player.h"
#include "wifi_manager.h"
#include <Arduino.h>
#include <ESP32-audioI2S.h>

namespace {
AudioGeneratorMP3 *mp3;
AudioFileSourceHTTPStream *file;
AudioOutputI2S *out;
constexpr unsigned long kPlaybackTimeoutMs = 10000;
}

void AudioPlayer::playUrl(const char* url) {
  if (!url) return;
  delete mp3;
  delete file;
  delete out;

  unsigned long startWait = millis();
  while (!WifiManager::isConnected() && millis() - startWait < kPlaybackTimeoutMs) {
    WifiManager::loop();
    delay(250);
  }

  if (!WifiManager::isConnected()) {
    Serial.println("Audio playback blocked - WiFi offline");
    return;
  }

  file = new AudioFileSourceHTTPStream(url);
  out = new AudioOutputI2S(0, 1);
  mp3 = new AudioGeneratorMP3();
  mp3->begin(file, out);
}
