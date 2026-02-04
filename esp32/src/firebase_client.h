#pragma once

class FirebaseClient {
 public:
  static void begin();
  static bool updateHeartbeat(const char* deviceId);
};
