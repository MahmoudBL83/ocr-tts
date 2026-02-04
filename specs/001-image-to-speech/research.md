# Research: Image-to-Speech OCR Pipeline

**Feature Branch**: `001-image-to-speech`  
**Created**: 2026-02-04  
**Status**: Complete

## Overview

This document consolidates research findings for technology decisions required to implement the Image-to-Speech OCR pipeline. Each decision includes rationale and alternatives considered.

---

## 1. OCR Service Selection

### Decision: **Google Cloud Vision API**

### Rationale
- **Accuracy**: 95-99% on clear documents, exceeds the 90% requirement (SC-003)
- **Speed**: 1-3 seconds per page, well under the 30-second processing goal
- **Free tier**: 1,000 images/month permanently free (sufficient for MVP)
- **Node.js SDK**: Well-maintained `@google-cloud/vision` package with TypeScript support
- **Reliability**: Managed service with SLA, no infrastructure to maintain

### Alternatives Considered

| Option | Why Rejected |
|--------|--------------|
| **Tesseract.js** | Lower accuracy (85-95%), slower (3-15s), CPU-intensive on server |
| **AWS Textract** | Free tier expires after 3 months; more complex pricing for basic OCR |

### Implementation Notes
- Use `DOCUMENT_TEXT_DETECTION` for dense document text
- Configure service account credentials via `GOOGLE_APPLICATION_CREDENTIALS`
- Handle confidence scores for quality metrics logging

---

## 2. TTS Service Selection

### Decision: **AWS Polly**

### Rationale
- **Free tier**: 5M characters/month permanently free for Standard voices
- **Voice quality**: Neural voices provide natural English speech
- **Node.js SDK**: Modern AWS SDK v3 with excellent TypeScript support
- **MP3 output**: Native MP3 synthesis without conversion step
- **Processing speed**: 2-5 seconds for 1 minute of audio (well under 15s goal)
- **Cost predictability**: Can cache and replay audio without extra charges

### Alternatives Considered

| Option | Why Rejected |
|--------|--------------|
| **Google Cloud TTS** | Smaller free tier (4M chars for WaveNet), already using GCP for OCR |
| **Mozilla/Coqui TTS** | Python-based (not Node.js native), project abandoned, requires GPU |
| **Azure Cognitive TTS** | Smallest free tier (0.5M chars), higher base pricing |

### Implementation Notes
- Use Neural voices for natural sound quality
- Configure output format: MP3, 24kHz sample rate (~800KB/min)
- Character limit per request: 3000 chars; split longer text into chunks
- Use `@aws-sdk/client-polly` package

### Audio Segmentation Strategy
For text >3000 characters:
1. Split text at sentence boundaries
2. Generate separate audio segments
3. Store as `{request_id}_part1.mp3`, `{request_id}_part2.mp3`, etc.
4. Record segment count in Firestore for ESP32 sequential playback

---

## 3. ESP32 Audio Architecture

### Decision: **ESP32-WROVER with ESP32-audioI2S library**

### Rationale
- **PSRAM requirement**: ESP32-audioI2S requires PSRAM for reliable streaming; WROVER has 4MB PSRAM
- **Library maturity**: Purpose-built for ESP32, active maintenance, 2.6k GitHub stars
- **HTTPS streaming**: Single-call `audio.connecttohost(url)` handles buffering automatically
- **MP3 support**: Native MP3 decoding without external libraries

### Hardware Change
**⚠️ IMPORTANT**: Original spec mentioned ESP32-WROOM-32, but research indicates ESP32-WROVER is required for reliable audio streaming with PSRAM. Update hardware recommendation.

### Alternatives Considered

| Option | Why Rejected |
|--------|--------------|
| **ESP8266Audio on WROOM-32** | Possible but requires download-to-SPIFFS pattern, more complex buffering |
| **Direct DAC output** | Lower audio quality than I2S; I2S DAC boards (MAX98357A) are inexpensive |

### WiFi Reconnection Pattern
- Use event-based reconnection via `WiFi.onEvent()`
- Events: `WIFI_STA_CONNECTED`, `WIFI_STA_GOT_IP`, `WIFI_STA_DISCONNECTED`
- Exponential backoff: 1s → 2s → 4s → 8s → 16s → restart ESP

### Firebase Access Pattern
Server generates signed download URLs stored in Firestore. ESP32:
1. Polls Firestore for `completed` status with matching device_id
2. Reads `audio_urls` array from document
3. Downloads each segment via HTTPS GET (no Firebase SDK needed)
4. Updates status to `delivered` via Firestore REST API

---

## 4. Flutter App Architecture

### Decision: **Riverpod 3.x for State Management**

### Rationale
- **Firebase streams**: First-class `StreamProvider` for Firestore real-time listeners
- **Compile-time safety**: Provider errors caught at compile time
- **Testability**: Easy provider overrides for mocking Firebase in tests
- **AsyncValue**: Built-in pattern for loading/error/data states
- **Auto-dispose**: Automatic cleanup of Firestore listeners when widget unmounts

### Alternatives Considered

| Option | Why Rejected |
|--------|--------------|
| **Provider** | Less type-safe, manual dispose management for streams |
| **Bloc** | More boilerplate for simple use cases; overkill for this app |

### Additional Package Decisions

| Need | Package | Rationale |
|------|---------|-----------|
| **Camera** | `camera` v0.11.x | Full control for document capture, live preview, resolution control |
| **Token Storage** | `flutter_secure_storage` v10.x | OS-level encryption (Keychain/EncryptedSharedPreferences) |
| **Image Compression** | `flutter_image_compress` v2.4.x | Native platform compression, maintains quality for OCR |
| **Firebase** | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage` | Official Firebase packages |

### Image Compression Settings
For OCR optimization:
- Quality: 90%
- Min dimension: 2048px (maintains text clarity)
- Format: JPEG
- Max file size: 5MB

---

## 5. Firebase Schema Design

### Decision: **Firestore + Storage with User-Scoped Paths**

### Firestore Collections

```
users/
  {user_id}/
    devices/
      {device_id}/
        pairing_code: string
        friendly_name: string
        last_seen: timestamp
        
requests/
  {request_id}/
    owner_user_id: string
    target_device_id: string
    status: "pending" | "processing" | "completed" | "delivered" | "error"
    created_at: timestamp
    updated_at: timestamp
    image_url: string
    audio_urls: string[]  // Array for segments
    segment_count: number
    extracted_text_length: number
    error_message: string | null
```

### Storage Paths

```
images/{user_id}/{request_id}.jpg
audio/{user_id}/{request_id}_part1.mp3
audio/{user_id}/{request_id}_part2.mp3
...
```

### Firestore Indexes Required

```json
{
  "indexes": [
    {
      "collectionGroup": "requests",
      "fields": [
        { "fieldPath": "target_device_id", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "created_at", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "requests", 
      "fields": [
        { "fieldPath": "owner_user_id", "order": "ASCENDING" },
        { "fieldPath": "created_at", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

## 6. Authentication Strategy

### Decision: **Firebase Auth with Custom JWT for ESP32**

### Flutter App
- Firebase Auth SDK handles user sign-in (email/password)
- Firebase ID tokens used for Firestore/Storage access
- Token refresh handled automatically by SDK

### Node.js Server
- Firebase Admin SDK verifies ID tokens
- Service account for Firestore/Storage access
- Generates signed download URLs for audio files

### ESP32 Device
- Device credentials stored in flash (device_id + secret)
- Server validates device credentials via API endpoint
- Signed URLs for audio download (7-day expiry, refreshed on each request)

### 6-Digit Pairing Flow
1. ESP32 generates unique 6-digit code on first boot
2. Code displayed on serial output (for initial setup)
3. User enters code in Flutter app
4. App calls server to link device_id to user account
5. Device begins monitoring for audio files targeting its ID

---

## Summary of Technology Stack

| Component | Technology | Version |
|-----------|------------|---------|
| **Flutter App** | Flutter/Dart | 3.x |
| **State Management** | Riverpod | 3.x |
| **Camera** | camera | 0.11.x |
| **Secure Storage** | flutter_secure_storage | 10.x |
| **Image Compression** | flutter_image_compress | 2.4.x |
| **Node.js Server** | Node.js/TypeScript | 20 LTS / 5.x |
| **OCR** | Google Cloud Vision | Latest |
| **TTS** | AWS Polly | Latest |
| **ESP32 Board** | ESP32-WROVER | (with PSRAM) |
| **ESP32 Framework** | Arduino | 2.x |
| **Audio Library** | ESP32-audioI2S | Latest |
| **I2S DAC** | MAX98357A | - |
| **Database** | Cloud Firestore | Latest |
| **Storage** | Firebase Storage | Latest |
| **Auth** | Firebase Auth | Latest |

---

## Open Questions Resolved

| Question | Resolution |
|----------|------------|
| Which OCR service? | Google Cloud Vision (accuracy, free tier) |
| Which TTS service? | AWS Polly (free tier, native MP3, Node.js SDK) |
| ESP32 board variant? | ESP32-WROVER (PSRAM required for audio streaming) |
| Audio library? | ESP32-audioI2S (purpose-built, HTTPS streaming) |
| State management? | Riverpod (streams, type safety, testability) |
| Firebase access from ESP32? | Signed URLs via Firestore, no SDK needed |
