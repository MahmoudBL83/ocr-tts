#pragma once

class WifiManager {
 public:
  static void begin();
  static void loop();
  static bool isConnected();
};
