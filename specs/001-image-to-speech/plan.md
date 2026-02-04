# Implementation Plan: Image-to-Speech OCR Pipeline

**Branch**: `001-image-to-speech` | **Date**: 2026-02-04 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-image-to-speech/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Build a distributed IoT system enabling visually impaired users to capture images of text via Flutter app, process through OCR and TTS on a Node.js server, and play the resulting audio on a paired ESP32 speaker device. The system uses Firebase as the central communication hub with JWT authentication and user-device pairing via 6-digit codes.

## Technical Context

**Language/Version**: 
- Flutter App: Dart 3.x / Flutter 3.x
- Node.js Server: Node.js 20 LTS / TypeScript 5.x
- ESP32: C++ (Arduino framework)

**Primary Dependencies**:
- Flutter: `firebase_core`, `firebase_auth`, `firebase_storage`, `cloud_firestore`, `camera`, `flutter_secure_storage`, `flutter_riverpod`, `flutter_image_compress`
- Node.js: `firebase-admin`, `@google-cloud/vision` (OCR), `@aws-sdk/client-polly` (TTS), `express`
- ESP32: `WiFi.h`, `HTTPClient.h`, `ESP32-audioI2S`

**Storage**: Firebase Firestore (metadata) + Firebase Storage (images/audio files)

**Testing**:
- Flutter: `flutter_test`, `mockito`, Firebase Emulator
- Node.js: `jest`, `supertest`, Firebase Emulator
- ESP32: PlatformIO unit tests with mock HTTP

**Target Platform**:
- Flutter: Android 8+ (primary), iOS 13+ (secondary)
- Node.js: Linux container (Docker), deployable to Cloud Run
- ESP32: ESP32-WROVER with PSRAM + I2S DAC (MAX98357A)

**Project Type**: Multi-component IoT (mobile + server + embedded)

**Performance Goals**:
- Image upload: <5 seconds for 5MB compressed image
- OCR processing: <30 seconds for standard document
- TTS generation: <15 seconds for 1 minute of audio
- End-to-end: <2 minutes from capture to playback (per SC-002)

**Constraints**:
- Audio file size: <1MB per segment (ESP32 memory limit)
- Audio quality: ~800KB/min MP3 (per clarification)
- ESP32 RAM: ~520KB total, ~200KB available for audio buffer
- WiFi required for all components

**Scale/Scope**:
- 50 requests/hour throughput (per SC-005)
- Single user per ESP32 device
- English language only (initial release)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Component Isolation | ✅ PASS | Three independent components: Flutter app, Node.js server, ESP32 - each with own codebase and test suite |
| II. Firebase as Central Hub | ✅ PASS | All components communicate exclusively via Firebase Storage and Firestore; no direct connections |
| III. Async Processing Pipeline | ✅ PASS | Status state machine defined: pending → processing → completed → delivered; timestamps at each stage |
| IV. Error Resilience & Retry Logic | ✅ PASS | FR-012, FR-022, FR-034, FR-035 specify retry logic and error handling for each component |
| V. Embedded Device Constraints | ✅ PASS | Audio <1MB per segment; MP3 compression; streaming support for long text via segmentation |
| VI. Test-First with Mocking | ✅ PASS | Test strategy includes mocking Firebase SDK, OCR/TTS APIs; Firebase Emulator for integration |
| VII. Observability & Logging | ✅ PASS | FR-025 requires request_id in logs; metrics stored in Firebase per constitution |

**Gate Result**: ✅ ALL PRINCIPLES PASS - Proceed to Phase 0 Research

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Multi-component IoT structure (Flutter + Node.js + ESP32)

flutter_app/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── processing_request.dart
│   │   ├── device.dart
│   │   └── user.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── firebase_service.dart
│   │   ├── camera_service.dart
│   │   └── device_pairing_service.dart
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── camera_screen.dart
│   │   ├── history_screen.dart
│   │   └── device_pairing_screen.dart
│   └── widgets/
│       ├── upload_progress.dart
│       └── request_status_card.dart
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
├── pubspec.yaml
└── android/

server/
├── src/
│   ├── index.ts
│   ├── models/
│   │   ├── processing-request.ts
│   │   └── device.ts
│   ├── services/
│   │   ├── firebase.service.ts
│   │   ├── ocr.service.ts
│   │   ├── tts.service.ts
│   │   └── queue.service.ts
│   ├── workers/
│   │   └── processing-worker.ts
│   └── utils/
│       ├── logger.ts
│       └── audio-splitter.ts
├── tests/
│   ├── unit/
│   ├── integration/
│   └── contract/
├── package.json
├── tsconfig.json
└── Dockerfile

esp32/
├── src/
│   ├── main.cpp
│   ├── wifi_manager.cpp
│   ├── firebase_client.cpp
│   ├── audio_player.cpp
│   └── config.h
├── include/
│   ├── wifi_manager.h
│   ├── firebase_client.h
│   └── audio_player.h
├── test/
│   └── test_main.cpp
└── platformio.ini

firebase/
├── firestore.rules
├── storage.rules
├── firestore.indexes.json
└── firebase.json
```

**Structure Decision**: Multi-component IoT structure selected. Three independent codebases (flutter_app/, server/, esp32/) per Constitution Principle I (Component Isolation), plus shared Firebase configuration (firebase/). Each component has its own test directory and can be developed, tested, and deployed independently.

## Complexity Tracking

> **No violations identified.** All design decisions align with constitution principles.

## Constitution Re-Check (Post-Design)

*Re-evaluated after Phase 1 design completion.*

| Principle | Status | Post-Design Evidence |
|-----------|--------|----------------------|
| I. Component Isolation | ✅ PASS | [data-model.md](data-model.md) defines per-component responsibilities; [contracts/](contracts/) defines interfaces |
| II. Firebase as Central Hub | ✅ PASS | [firebase-contract.md](contracts/firebase-contract.md) documents all Firestore/Storage interactions |
| III. Async Processing Pipeline | ✅ PASS | Status transitions documented in data-model.md; timestamps at each stage |
| IV. Error Resilience & Retry Logic | ✅ PASS | Error codes defined in data-model.md; retry API in server-api.yaml |
| V. Embedded Device Constraints | ✅ PASS | [research.md](research.md) confirms ESP32-WROVER with PSRAM required; audio segmentation defined |
| VI. Test-First with Mocking | ✅ PASS | [quickstart.md](quickstart.md) documents test setup for all components |
| VII. Observability & Logging | ✅ PASS | request_id included in all Firestore documents; metrics fields defined |

**Post-Design Gate Result**: ✅ ALL PRINCIPLES PASS - Ready for `/speckit.tasks`

## Hardware Update

⚠️ **Important change from spec**: Research determined that **ESP32-WROVER** (with PSRAM) is required instead of ESP32-WROOM-32. The ESP32-audioI2S library requires PSRAM for reliable audio streaming. See [research.md](research.md) for details.

## Technology Decisions Summary

| Category | Decision | Rationale |
|----------|----------|-----------|
| OCR Service | Google Cloud Vision | 95%+ accuracy, generous free tier, excellent Node.js SDK |
| TTS Service | AWS Polly | 5M chars/month free, native MP3 output, natural voices |
| State Management | Riverpod 3.x | First-class streams for Firestore listeners, type-safe |
| ESP32 Audio | ESP32-audioI2S | Purpose-built library, HTTPS streaming, active maintenance |
| ESP32 Board | ESP32-WROVER | PSRAM required for audio buffering |

## Generated Artifacts

| Artifact | Path | Description |
|----------|------|-------------|
| Research | [research.md](research.md) | Technology decisions and rationale |
| Data Model | [data-model.md](data-model.md) | Entity schemas, Firebase structure, security rules |
| Server API | [contracts/server-api.yaml](contracts/server-api.yaml) | OpenAPI spec for device pairing and retry endpoints |
| Firebase Contract | [contracts/firebase-contract.md](contracts/firebase-contract.md) | Firestore/Storage schemas and queries |
| Quickstart | [quickstart.md](quickstart.md) | Development environment setup guide |

## Next Steps

1. Run `/speckit.tasks` to generate implementation task list
2. Order ESP32-WROVER hardware if using WROOM currently
3. Set up Firebase project and cloud service accounts
4. Begin implementation following task list
