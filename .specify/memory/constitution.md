<!--
  ============================================================================
  SYNC IMPACT REPORT
  ============================================================================
  Version Change: N/A → 1.0.0 (Initial Constitution)
  
  Added Principles:
    - I. Component Isolation (Flutter, Node.js Server, ESP32)
    - II. Firebase as Central Hub
    - III. Async Processing Pipeline
    - IV. Error Resilience & Retry Logic
    - V. Embedded Device Constraints
    - VI. Test-First with Mocking
    - VII. Observability & Logging
  
  Added Sections:
    - Technology Stack Requirements
    - Data Flow Architecture
    - Governance
  
  Templates Requiring Updates:
    ✅ plan-template.md - Compatible (uses generic Constitution Check)
    ✅ spec-template.md - Compatible (uses generic structure)
    ✅ tasks-template.md - Compatible (uses generic task phases)
  
  Follow-up TODOs: None
  ============================================================================
-->

# OCR-to-Speech IoT Platform Constitution

## Core Principles

### I. Component Isolation

Each component of the system (Flutter App, Node.js Server, ESP32 Device) MUST be independently deployable and testable.

- **Flutter App**: Handles ONLY image capture, Firebase upload, and audio playback status display
- **Node.js Server**: Handles ONLY image retrieval, OCR processing, TTS conversion, and audio storage
- **ESP32 Microcontroller**: Handles ONLY audio retrieval from Firebase and speaker playback
- Components communicate EXCLUSIVELY through Firebase (no direct connections between app and ESP32)
- Each component MUST have its own test suite that can run without other components

### II. Firebase as Central Hub

Firebase serves as the SINGLE source of truth and the ONLY communication channel between all system components.

- **Firebase Storage**: MUST store images (input) and audio files (output)
- **Firebase Realtime Database/Firestore**: MUST track processing status and metadata
- All file uploads MUST include metadata: timestamp, device ID, processing status
- Audio files MUST be stored with predictable naming: `audio/{request_id}.mp3`
- Image files MUST be stored with predictable naming: `images/{request_id}.{ext}`
- Database MUST maintain state machine: `pending → processing → completed → delivered`

### III. Async Processing Pipeline

The OCR-to-TTS pipeline MUST be fully asynchronous with clear status transitions.

- Flutter App uploads image and sets status to `pending`, then polls/listens for completion
- Node.js Server watches for `pending` items, processes, and updates to `completed`
- ESP32 watches for `completed` items targeting its device ID
- Each stage MUST update Firebase with processing timestamps
- Pipeline stages MUST be idempotent (safe to retry on failure)
- Maximum processing time per stage MUST be defined and enforced (timeout handling)

### IV. Error Resilience & Retry Logic

All network operations and processing steps MUST handle failures gracefully.

- **Flutter App**: MUST retry image uploads with exponential backoff (max 3 attempts)
- **Node.js Server**: MUST mark failed OCR/TTS as `error` with reason; MUST support manual retry
- **ESP32**: MUST handle WiFi disconnections and audio download failures gracefully
- All components MUST implement connection health checks
- Failed items MUST NOT block the processing queue
- Error states MUST be visible in Firebase for debugging

### V. Embedded Device Constraints

ESP32 has limited resources; all audio and communication MUST respect these constraints.

- Audio files MUST be compressed (MP3 or similar) to minimize download size
- Audio file size SHOULD NOT exceed 1MB per request (adjust based on ESP32 memory)
- ESP32 MUST stream audio if file size exceeds available RAM
- WiFi credentials MUST be configurable (not hardcoded)
- ESP32 MUST support OTA updates for firmware
- Audio sample rate and quality MUST be balanced for ESP32 DAC capabilities

### VI. Test-First with Mocking

Each component MUST be testable in isolation using mocks for external dependencies.

- Flutter tests MUST mock Firebase SDK calls
- Node.js tests MUST mock Firebase Admin SDK, OCR API, and TTS API
- ESP32 tests MUST use simulated WiFi and mock HTTP responses
- Integration tests MUST use Firebase Emulator Suite
- Contract tests MUST verify Firebase document schema compatibility between components
- E2E tests MUST run with real Firebase (staging project) before production deploy

### VII. Observability & Logging

All components MUST provide structured logging for debugging the distributed pipeline.

- **Flutter App**: Log image capture events, upload status, Firebase listeners
- **Node.js Server**: Log OCR results (character count, confidence), TTS duration, processing time
- **ESP32**: Log WiFi status, download progress, playback events
- All logs MUST include `request_id` for cross-component tracing
- Firebase MUST store processing metrics: image size, OCR duration, audio duration
- Errors MUST be logged with full stack traces and context

## Technology Stack Requirements

### Flutter App
- **Framework**: Flutter 3.x with Dart
- **State Management**: Provider, Riverpod, or Bloc (choose one, document choice)
- **Camera**: `camera` or `image_picker` package
- **Firebase**: `firebase_core`, `firebase_storage`, `cloud_firestore`
- **Platform**: Android (primary), iOS (if required)

### Node.js Server
- **Runtime**: Node.js 18+ LTS
- **Framework**: Express.js or Fastify for HTTP endpoints (if needed)
- **Firebase**: `firebase-admin` SDK
- **OCR**: Tesseract.js, Google Cloud Vision, or AWS Textract (document choice)
- **TTS**: Google Cloud TTS, AWS Polly, or Mozilla TTS (document choice)
- **Deployment**: Docker container, deployable to Cloud Run, AWS Lambda, or VPS

### ESP32 Microcontroller
- **Board**: ESP32 with DAC or I2S audio output
- **Framework**: Arduino or ESP-IDF
- **Audio**: I2S driver or DAC with audio library
- **WiFi**: ESP32 WiFi library with reconnection logic
- **HTTP**: HTTPClient or WiFiClient for Firebase REST API

### Firebase Configuration
- **Project**: Single Firebase project with staging and production environments
- **Security Rules**: MUST restrict access by authenticated users/devices
- **Indexes**: MUST be defined for status-based queries

## Data Flow Architecture

```
┌─────────────────┐     ┌─────────────────────────────────────┐     ┌─────────────────┐
│   Flutter App   │     │           Firebase                  │     │  Node.js Server │
│                 │     │                                     │     │                 │
│  1. Capture     │────▶│  images/{id}.jpg                   │◀────│  3. Download    │
│     Image       │     │  status: pending                    │     │     Image       │
│                 │     │                                     │     │                 │
│  6. Show Done   │◀────│  status: completed                  │────▶│  4. OCR → Text  │
│                 │     │  audio/{id}.mp3                     │     │  5. TTS → Audio │
└─────────────────┘     │                                     │     │     Upload      │
                        │                                     │     └─────────────────┘
                        │                                     │
┌─────────────────┐     │                                     │
│      ESP32      │     │                                     │
│                 │◀────│  7. Watch completed + device_id     │
│  8. Download    │     │  8. Stream audio/{id}.mp3           │
│     & Play      │     │  9. Update: delivered               │
└─────────────────┘     └─────────────────────────────────────┘
```

## Governance

This constitution supersedes all other development practices for this project. All contributions MUST comply with these principles.

**Amendment Process**:
1. Propose change with rationale in a dedicated issue/PR
2. Document impact on existing components
3. Update affected templates and documentation
4. Version bump follows semantic versioning:
   - MAJOR: Breaking changes to Firebase schema or component contracts
   - MINOR: New principles or expanded guidance
   - PATCH: Clarifications and typo fixes

**Compliance Verification**:
- All PRs MUST reference applicable principles in the description
- Code reviews MUST verify principle adherence
- Integration tests MUST pass before merge
- Firebase schema changes require cross-component compatibility verification

**Version**: 1.0.0 | **Ratified**: 2026-02-04 | **Last Amended**: 2026-02-04
