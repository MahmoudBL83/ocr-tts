#include "wifi_manager.h"
#include <Arduino.h>
#include <algorithm>
#include <WiFi.h>

namespace {
  constexpr unsigned long kInitialBackoff = 1000;
  constexpr unsigned long kMaxBackoff = 32000;

  unsigned long nextAttempt = 0;
  unsigned long backoff = kInitialBackoff;
  bool eventConnected = false;

  void onWiFiEvent(WiFiEvent_t event) {
    switch (event) {
      case SYSTEM_EVENT_STA_GOT_IP:
        Serial.println("WiFi connected");
        nextAttempt = 0;
        backoff = kInitialBackoff;
        eventConnected = true;
        break;
      case SYSTEM_EVENT_STA_DISCONNECTED:
        Serial.println("WiFi disconnected, scheduling reconnect");
        eventConnected = false;
        nextAttempt = millis() + backoff;
        backoff = std::min(backoff * 2, kMaxBackoff);
        break;
      default:
        break;
    }
  }
}

void WifiManager::begin() {
  WiFi.onEvent(onWiFiEvent);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.printf("Attempting to connect to WiFi: %s\n", WIFI_SSID);
}

void WifiManager::loop() {
  if (isConnected()) {
    return;
  }

  if (nextAttempt && millis() < nextAttempt) {
    return;
  }

  Serial.println("Reconnecting to WiFi...");
  WiFi.disconnect();
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  nextAttempt = millis() + backoff;
  backoff = std::min(backoff * 2, kMaxBackoff);
}

bool WifiManager::isConnected() {
  return WiFi.status() == WL_CONNECTED && eventConnected;
}
