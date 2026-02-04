#pragma once

#include <functional>

using RequestCallback = std::function<void(const char* requestId, const char* audioUrl)>;

class RequestListener {
 public:
  static void begin(const char* deviceId, RequestCallback callback);
  static void loop();
};
