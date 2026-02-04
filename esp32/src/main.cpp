#include "audio_player.h"
#include "firebase_client.h"
#include "pairing.h"
#include "request_listener.h"
#include "wifi_manager.h"

void setup() {
  Serial.begin(115200);
  WifiManager::begin();
  Pairing::setup();
  FirebaseClient::begin();
  RequestListener::begin("esp32-device-id", [](const char* requestId, const char* audioUrl) {
    Serial.printf("Playing request %s -> %s\n", requestId, audioUrl);
    AudioPlayer::playUrl(audioUrl);
  });
}

void loop() {
  WifiManager::loop();
  RequestListener::loop();
  delay(1000);
}
