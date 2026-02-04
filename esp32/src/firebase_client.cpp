#include "firebase_client.h"
#include <Firebase_ESP_Client.h>
#include <WiFi.h>

FirebaseData fbData;

void FirebaseClient::begin() {
  Firebase.begin(FIREBASE_DATABASE_URL, FIREBASE_API_KEY);
}

bool FirebaseClient::updateHeartbeat(const char* deviceId) {
  FirebaseJson json;
  json.set("is_online", true);
  json.set("last_seen", millis());
  return Firebase.RTDB.setJSON(&fbData, "/devices/", json);
}
