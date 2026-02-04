# ESP32 Audio Playback over WiFi: Research Findings

**Date**: 2026-02-04  
**Context**: Image-to-Speech OCR Pipeline - ESP32 Speaker Component  
**Target Hardware**: ESP32-WROOM-32 with I2S DAC (MAX98357A or PCM5102)

---

## Executive Summary

For the ESP32 speaker component that downloads MP3 files (<1MB) from Firebase Storage and plays them via I2S DAC, the recommended approach is:

- **Audio Library**: ESP32-audioI2S (schreibfaul1) - the clear winner for this use case
- **Streaming**: Direct HTTPS streaming with built-in buffering
- **WiFi**: Event-based reconnection using `WiFi.onEvent()`
- **Firebase**: Public download URLs or signed URLs (no Firebase SDK needed)

---

## 1. Audio Library Comparison

### Recommendation: **ESP32-audioI2S** (schreibfaul1)

| Criteria | ESP32-audioI2S | ESP8266Audio |
|----------|---------------|--------------|
| **ESP32 Optimization** | ✅ Purpose-built for ESP32 | ⚠️ Originally for ESP8266, ported |
| **PSRAM Support** | ✅ Built-in, required | ⚠️ Optional external SPI RAM |
| **HTTPS Streaming** | ✅ Native `connecttohost()` | ✅ `AudioFileSourceHTTPStream` |
| **MP3 Decoding** | ✅ HELIX decoder, efficient | ✅ libMAD port |
| **I2S DAC Support** | ✅ MAX98357A, PCM5102, CS4344 | ✅ Various I2S DACs |
| **Active Maintenance** | ✅ Very active (commits weekly) | ✅ Active |
| **Stars/Community** | 1.5k stars | 2.3k stars |
| **Auto-reconnection** | ✅ Built-in stream retry | ❌ Manual handling |
| **Buffer Management** | ✅ Automatic with PSRAM | ⚠️ Manual `AudioFileSourceBuffer` |

### ESP32-audioI2S Advantages

1. **Single-call streaming**: `audio.connecttohost(url)` handles everything
2. **Automatic buffering**: Uses PSRAM for ~1MB input buffer
3. **Connection recovery**: Built-in retry on stream loss
4. **48kHz output**: Always outputs at 48kHz regardless of source (good for consistent DAC operation)
5. **Callback events**: Rich event system (`audio_info`, `audio_eof`, etc.)
6. **Arduino IDE compatible**: Works with standard Arduino IDE and PlatformIO

### Critical Requirement: PSRAM

> ⚠️ **ESP32-audioI2S requires PSRAM**. The standard ESP32-WROOM-32 does NOT have PSRAM. 
> 
> **Options**:
> 1. Use **ESP32-WROVER** (has 4MB PSRAM) - Recommended
> 2. Use ESP8266Audio with manual buffering (limited to ~6KB buffer on WROOM-32)
> 3. Download file to SPIFFS first, then play locally

### Fallback: ESP8266Audio (if PSRAM not available)

If using ESP32-WROOM-32 without PSRAM:
- Use `AudioFileSourceBuffer` with 4-8KB buffer
- For files <1MB, consider downloading to SPIFFS first, then playing locally
- May experience dropouts on higher bitrate streams

---

## 2. Streaming/Buffering MP3 from HTTPS

### ESP32-audioI2S Approach (Recommended)

```cpp
#include "Audio.h"

Audio audio;

void setup() {
    audio.setPinout(I2S_BCLK, I2S_LRC, I2S_DOUT);
    audio.setVolume(21);  // 0-21
    
    // Direct HTTPS streaming
    audio.connecttohost("https://firebasestorage.googleapis.com/v0/b/...");
}

void loop() {
    audio.loop();
    vTaskDelay(1);  // Yield to other tasks
}

// Callbacks
void audio_info(const char *info) {
    Serial.printf("Info: %s\n", info);
}

void audio_eof_mp3(const char *info) {
    Serial.println("Playback finished");
}
```

### ESP8266Audio Approach (Alternative)

```cpp
#include "AudioFileSourceHTTPStream.h"
#include "AudioFileSourceBuffer.h"
#include "AudioGeneratorMP3.h"
#include "AudioOutputI2S.h"

AudioGeneratorMP3 *mp3;
AudioFileSourceHTTPStream *file;
AudioFileSourceBuffer *buff;
AudioOutputI2S *out;

void setup() {
    file = new AudioFileSourceHTTPStream(url);
    buff = new AudioFileSourceBuffer(file, 4096);  // 4KB buffer
    out = new AudioOutputI2S();
    mp3 = new AudioGeneratorMP3();
    mp3->begin(buff, out);
}

void loop() {
    if (mp3->isRunning()) {
        if (!mp3->loop()) mp3->stop();
    }
}
```

### Download-First Approach (Most Reliable for <1MB files)

For files under 1MB, downloading to flash first ensures stutter-free playback:

```cpp
// 1. Download to SPIFFS
HTTPClient http;
http.begin(url);
int httpCode = http.GET();
if (httpCode == HTTP_CODE_OK) {
    File f = SPIFFS.open("/audio.mp3", "w");
    http.writeToStream(&f);
    f.close();
}
http.end();

// 2. Play from SPIFFS
audio.connecttoFS(SPIFFS, "/audio.mp3");
```

---

## 3. Memory Management for Audio Buffers

### ESP32-WROOM-32 Memory Constraints

| Memory Type | Total | Typically Available |
|------------|-------|---------------------|
| SRAM | 520KB | ~200KB for application |
| Flash (SPIFFS) | 4MB | 1-2MB for data |
| PSRAM | 0 | N/A (WROVER has 4MB) |

### Buffer Sizing Guidelines

**With PSRAM (ESP32-WROVER)**:
- Input buffer: ~1MB automatically managed by ESP32-audioI2S
- I2S DMA buffer: 8 x 1024 bytes (configurable)

**Without PSRAM (ESP32-WROOM-32)**:
- Input buffer: 4-8KB maximum (heap constrained)
- Recommend download-to-flash approach for files >100KB
- I2S DMA buffer: 8 x 512 bytes

### Memory-Safe Patterns

```cpp
// Check heap before allocation
size_t freeHeap = ESP.getFreeHeap();
if (freeHeap < 50000) {
    Serial.println("Low memory warning");
}

// Use stack-allocated buffers where possible
// Avoid frequent malloc/free during playback
// Pre-allocate audio objects in setup()
```

---

## 4. Firebase Storage Authentication from ESP32

### Option A: Public Download URLs (Simplest)

If Firebase Storage rules allow public read:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /audio/{allPaths=**} {
      allow read: if true;  // Public read
    }
  }
}
```

URL format:
```
https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media
```

Path must be URL-encoded:
```cpp
String encodedPath = urlencode("audio/user123/speech.mp3");
String url = "https://firebasestorage.googleapis.com/v0/b/myapp.appspot.com/o/" 
           + encodedPath + "?alt=media";
```

### Option B: Token-Based URLs (Recommended for Security)

Firebase Storage download URLs include a token:
```
https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media&token={uuid}
```

**Workflow**:
1. Node.js server generates download URL with `getDownloadURL()` or constructs it with token
2. Store URL in Firestore with the audio job metadata
3. ESP32 reads URL from Firestore and downloads directly

```cpp
// ESP32 reads URL from Firestore document (via REST API or Firebase library)
String audioUrl = getAudioUrlFromFirestore(jobId);
audio.connecttohost(audioUrl.c_str());
```

### Option C: Signed URLs (Time-Limited)

For temporary access, server generates signed URL:
```javascript
// Node.js server
const [url] = await file.getSignedUrl({
    action: 'read',
    expires: Date.now() + 15 * 60 * 1000  // 15 minutes
});
```

**Considerations**:
- Expires in 7 days maximum (typically set to minutes/hours)
- Longer URLs (may need larger buffers for HTTP headers)
- Good for one-time downloads

### ESP32 HTTPS Configuration

```cpp
#include <WiFiClientSecure.h>

WiFiClientSecure client;
client.setInsecure();  // Skip certificate verification (development only)

// For production, use certificate pinning:
// client.setCACert(firebase_root_cert);
```

### Firebase REST API for Firestore (Optional)

If ESP32 needs to query Firestore for audio URLs:

```cpp
String getAudioUrl(String jobId) {
    HTTPClient http;
    String firestoreUrl = "https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents/audioJobs/" + jobId;
    
    http.begin(firestoreUrl);
    http.addHeader("Authorization", "Bearer " + accessToken);
    
    int httpCode = http.GET();
    if (httpCode == HTTP_CODE_OK) {
        // Parse JSON response for audioUrl field
        String payload = http.getString();
        // Use ArduinoJson to extract audioUrl
    }
    http.end();
}
```

---

## 5. WiFi Reconnection Best Practices

### Recommended: Event-Based Reconnection

```cpp
#include <WiFi.h>

const char* ssid = "YOUR_SSID";
const char* password = "YOUR_PASSWORD";

void WiFiStationConnected(WiFiEvent_t event, WiFiEventInfo_t info) {
    Serial.println("Connected to AP!");
}

void WiFiGotIP(WiFiEvent_t event, WiFiEventInfo_t info) {
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    // Resume audio playback or pending operations
}

void WiFiStationDisconnected(WiFiEvent_t event, WiFiEventInfo_t info) {
    Serial.print("Disconnected. Reason: ");
    Serial.println(info.wifi_sta_disconnected.reason);
    
    // Pause audio if playing
    // audio.pauseResume();  // or stop gracefully
    
    // Attempt reconnection
    WiFi.begin(ssid, password);
}

void setup() {
    Serial.begin(115200);
    
    // Register event handlers BEFORE connecting
    WiFi.disconnect(true);  // Clear old config
    delay(1000);
    
    WiFi.onEvent(WiFiStationConnected, WiFiEvent_t::ARDUINO_EVENT_WIFI_STA_CONNECTED);
    WiFi.onEvent(WiFiGotIP, WiFiEvent_t::ARDUINO_EVENT_WIFI_STA_GOT_IP);
    WiFi.onEvent(WiFiStationDisconnected, WiFiEvent_t::ARDUINO_EVENT_WIFI_STA_DISCONNECTED);
    
    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid, password);
}
```

### Alternative: Polling-Based Reconnection

```cpp
unsigned long previousMillis = 0;
const unsigned long interval = 30000;  // Check every 30 seconds

void loop() {
    unsigned long currentMillis = millis();
    
    if ((WiFi.status() != WL_CONNECTED) && (currentMillis - previousMillis >= interval)) {
        Serial.println("Reconnecting to WiFi...");
        WiFi.disconnect();
        WiFi.reconnect();
        previousMillis = currentMillis;
    }
    
    audio.loop();
}
```

### Auto-Reconnect Setting

```cpp
// Enable automatic reconnection (simple cases)
WiFi.setAutoReconnect(true);
WiFi.persistent(true);
```

### Robust Reconnection Pattern

```cpp
void ensureWiFiConnected() {
    static unsigned long lastAttempt = 0;
    static int retryCount = 0;
    const int maxRetries = 10;
    const unsigned long retryDelay = 5000;
    
    if (WiFi.status() == WL_CONNECTED) {
        retryCount = 0;
        return;
    }
    
    if (millis() - lastAttempt < retryDelay) return;
    lastAttempt = millis();
    
    if (retryCount >= maxRetries) {
        Serial.println("Max retries reached, restarting...");
        ESP.restart();
    }
    
    Serial.printf("WiFi reconnect attempt %d/%d\n", retryCount + 1, maxRetries);
    WiFi.disconnect();
    WiFi.begin(ssid, password);
    retryCount++;
}
```

---

## 6. Complete Integration Example

```cpp
#include "Arduino.h"
#include "WiFi.h"
#include "Audio.h"

#define I2S_DOUT  25
#define I2S_BCLK  27
#define I2S_LRC   26

const char* ssid = "YOUR_SSID";
const char* password = "YOUR_PASSWORD";

Audio audio;
bool wifiConnected = false;
String pendingAudioUrl = "";

// WiFi Events
void WiFiGotIP(WiFiEvent_t event, WiFiEventInfo_t info) {
    Serial.println("WiFi connected");
    wifiConnected = true;
    
    if (pendingAudioUrl.length() > 0) {
        audio.connecttohost(pendingAudioUrl.c_str());
        pendingAudioUrl = "";
    }
}

void WiFiDisconnected(WiFiEvent_t event, WiFiEventInfo_t info) {
    Serial.println("WiFi lost");
    wifiConnected = false;
    WiFi.begin(ssid, password);
}

// Audio Events
void audio_info(const char *info) {
    Serial.printf("Audio: %s\n", info);
}

void audio_eof_mp3(const char *info) {
    Serial.println("Playback complete");
}

void playAudio(const char* url) {
    if (wifiConnected) {
        audio.connecttohost(url);
    } else {
        pendingAudioUrl = String(url);
        Serial.println("WiFi not ready, queued audio");
    }
}

void setup() {
    Serial.begin(115200);
    
    // WiFi setup with events
    WiFi.disconnect(true);
    WiFi.onEvent(WiFiGotIP, WiFiEvent_t::ARDUINO_EVENT_WIFI_STA_GOT_IP);
    WiFi.onEvent(WiFiDisconnected, WiFiEvent_t::ARDUINO_EVENT_WIFI_STA_DISCONNECTED);
    WiFi.begin(ssid, password);
    
    // Audio setup
    audio.setPinout(I2S_BCLK, I2S_LRC, I2S_DOUT);
    audio.setVolume(15);
}

void loop() {
    audio.loop();
    vTaskDelay(1);
}
```

---

## 7. Hardware Recommendations

### Recommended: ESP32-WROVER Module

For reliable audio streaming with ESP32-audioI2S:
- **ESP32-WROVER-B** or **ESP32-WROVER-E** (4MB PSRAM)
- Development boards: ESP32-WROVER-KIT, or generic WROVER dev board

### I2S DAC Options

| DAC | Pros | Cons |
|-----|------|------|
| **MAX98357A** | Built-in 3W amp, simple (3 wires) | Mono only |
| **PCM5102A** | High quality, stereo | No amp, needs external amp for speaker |
| **UDA1334A** | Good quality, Adafruit support | Stereo, needs amp |

### Wiring (MAX98357A)

| ESP32 | MAX98357A |
|-------|-----------|
| GPIO25 | DIN |
| GPIO27 | BCLK |
| GPIO26 | LRC |
| 5V | VIN |
| GND | GND |

---

## 8. Key Decisions for Implementation

1. **Use ESP32-WROVER** (not WROOM) for PSRAM support, or implement download-to-flash approach

2. **Use ESP32-audioI2S library** for simplest integration with HTTPS streaming

3. **Store download URLs in Firestore** - server writes URL, ESP32 reads via REST or Firebase library

4. **Implement event-based WiFi reconnection** for robust connection handling

5. **Consider download-to-SPIFFS** for files <1MB to ensure stutter-free playback on WROOM devices

6. **Use token-based Firebase URLs** (not public) for security, with URLs stored in Firestore jobs

---

## References

- ESP32-audioI2S: https://github.com/schreibfaul1/ESP32-audioI2S
- ESP32-audioI2S Wiki: https://github.com/schreibfaul1/ESP32-audioI2S/wiki
- ESP8266Audio: https://github.com/earlephilhower/ESP8266Audio
- Arduino-ESP32 WiFi API: https://docs.espressif.com/projects/arduino-esp32/en/latest/api/wifi.html
- Firebase Storage REST: https://firebase.google.com/docs/storage/web/download-files
