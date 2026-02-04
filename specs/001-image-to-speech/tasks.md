# Implementation Tasks: Image-to-Speech OCR Pipeline

**Feature Branch**: `001-image-to-speech`  
**Created**: 2026-02-04  
**Source**: [spec.md](spec.md), [plan.md](plan.md), [data-model.md](data-model.md)

---

## Quick Reference

**Total Tasks**: 62  
**User Stories**: 4 (mapped from spec.md)  
**Parallel Opportunities**: 24 tasks marked [P]

| User Story | Priority | Task Range | Description |
|------------|----------|------------|-------------|
| US1 | P1 | T019-T030 | Capture and Upload Image (Flutter) |
| US2 | P1 | T031-T039 | OCR and TTS Processing (Server) |
| US3 | P2 | T040-T048 | ESP32 Audio Playback (Firmware) |
| US4 | P3 | T049-T056 | View Processing Status/History + Mobile Playback (Flutter) |

---

## Phase 1: Setup

**Goal**: Create project structure and initialize all three components

- [ ] T001 [P] Create Flutter app project structure with `flutter create flutter_app`
- [ ] T002 [P] Create Node.js server project structure in `server/`
- [ ] T003 [P] Create PlatformIO ESP32 project structure in `esp32/`
- [ ] T004 [P] Create Firebase configuration directory in `firebase/`
- [ ] T005 Add Flutter dependencies to `flutter_app/pubspec.yaml` (firebase_core, firebase_auth, cloud_firestore, firebase_storage, camera, flutter_secure_storage, flutter_image_compress, flutter_riverpod)
- [ ] T006 Add Node.js dependencies to `server/package.json` (express, firebase-admin, @google-cloud/vision, @aws-sdk/client-polly, typescript)
- [ ] T007 Add PlatformIO libraries to `esp32/platformio.ini` (WiFiManager, Firebase_ESP_Client, ESP32-audioI2S)
- [ ] T008 Create TypeScript configuration in `server/tsconfig.json`

**Checkpoint**: All three projects can build/compile without errors

---

## Phase 2: Foundational (Blocking)

**Goal**: Core shared infrastructure that all user stories depend on

### Firebase Configuration

- [ ] T009 [P] Create Firestore security rules in `firebase/firestore.rules` per contracts/firebase-contract.md
- [ ] T010 [P] Create Storage security rules in `firebase/storage.rules` per contracts/firebase-contract.md
- [ ] T011 [P] Create Firebase emulator config in `firebase/firebase.json`
- [ ] T012 Create composite indexes in `firebase/firestore.indexes.json` per data-model.md

### Flutter App Foundation

- [ ] T013 Configure Firebase initialization in `flutter_app/lib/main.dart`
- [ ] T014 [P] Create User model in `flutter_app/lib/models/user_model.dart` per data-model.md

### Server Foundation

- [ ] T015 [P] Create Express server entry point in `server/src/index.ts`
- [ ] T016 [P] Configure Firebase Admin SDK in `server/src/config/firebase.ts`
- [ ] T017 [P] Create health check endpoint in `server/src/routes/health.ts` per server-api.yaml
- [ ] T018 Create JWT authentication middleware in `server/src/middleware/auth.ts`

**Checkpoint**: Firebase emulators start, server runs, Flutter app connects to Firebase

---

## Phase 3: User Story 1 - Capture and Upload Image (Priority: P1)

**Goal**: User can sign in, capture an image with camera, and upload it to Firebase Storage with status tracking

**Independent Test**: Sign in with email/password → Capture image → Verify image appears in Firebase Storage → Verify ProcessingRequest document created in Firestore with status "pending"

### Models for User Story 1

- [ ] T019 [P] [US1] Create Device model in `flutter_app/lib/models/device_model.dart` per data-model.md
- [ ] T020 [P] [US1] Create ProcessingRequest model in `flutter_app/lib/models/processing_request_model.dart` per data-model.md

### Services for User Story 1

- [ ] T021 [US1] Implement AuthService with email/password sign-in in `flutter_app/lib/services/auth_service.dart`
- [ ] T021a [US1] Implement JWT token refresh logic in AuthService with automatic renewal before expiry (per FR-002)
- [ ] T022 [US1] Implement ImageService for camera capture and compression in `flutter_app/lib/services/image_service.dart` (max 5MB, JPEG)
- [ ] T023 [US1] Implement StorageService for Firebase Storage uploads in `flutter_app/lib/services/storage_service.dart` (path: images/{user_id}/{request_id}.jpg)
- [ ] T024 [US1] Implement RequestService for Firestore CRUD in `flutter_app/lib/services/request_service.dart`

### State Management for User Story 1

- [ ] T025 [US1] Create AuthProvider with Riverpod in `flutter_app/lib/providers/auth_provider.dart`
- [ ] T026 [US1] Create RequestProvider with Riverpod in `flutter_app/lib/providers/request_provider.dart`

### UI for User Story 1

- [ ] T027 [US1] Create LoginScreen with email/password form in `flutter_app/lib/screens/login_screen.dart`
- [ ] T028 [US1] Create CameraScreen with capture button in `flutter_app/lib/screens/camera_screen.dart`
- [ ] T029 [US1] Create UploadProgressWidget in `flutter_app/lib/widgets/upload_progress_widget.dart`
- [ ] T030 [US1] Create HomeScreen with camera access and device status in `flutter_app/lib/screens/home_screen.dart`

**Checkpoint**: User Story 1 is complete - User can capture image and it uploads to Firebase with pending status

---

## Phase 4: User Story 2 - OCR and TTS Processing (Priority: P1)

**Goal**: Server picks up pending requests, performs OCR with Google Cloud Vision, generates audio with AWS Polly, uploads audio segments to Firebase Storage

**Independent Test**: Create test request document in Firestore with status "pending" → Server picks up request → Verify OCR extracts text → Verify audio files appear in Firebase Storage → Verify request status changes to "completed"

### Models for User Story 2

- [ ] T031 [P] [US2] Create ProcessingRequest TypeScript interface in `server/src/models/request.model.ts` per data-model.md
- [ ] T032 [P] [US2] Create AudioSegment TypeScript interface in `server/src/models/audio-segment.model.ts`

### Services for User Story 2

- [ ] T033 [US2] Implement OCRService with Google Cloud Vision in `server/src/services/ocr.service.ts`
- [ ] T034 [US2] Implement TTSService with AWS Polly in `server/src/services/tts.service.ts` (English, neural voice, ~800KB/min)
- [ ] T035 [US2] Implement StorageService for Firebase Storage uploads in `server/src/services/storage.service.ts` (path: audio/{user_id}/{request_id}_part{N}.mp3)
- [ ] T036 [US2] Implement RequestService for Firestore operations in `server/src/services/request.service.ts`

### Workers for User Story 2

- [ ] T037 [US2] Implement ProcessingWorker with Firestore listener in `server/src/workers/processing.worker.ts` (listen to status="pending")
- [ ] T038 [US2] Implement audio segmentation logic in `server/src/utils/audio-segmenter.ts` (split at <1MB per segment)

### API Endpoints for User Story 2

- [ ] T039 [US2] Implement POST /requests/{requestId}/retry in `server/src/routes/requests.ts` per server-api.yaml

**Checkpoint**: User Story 2 is complete - Pending requests are processed, OCR + TTS runs, audio uploaded to Firebase

---

## Phase 5: User Story 3 - ESP32 Audio Playback (Priority: P2)

**Goal**: ESP32 device connects to WiFi, registers with Firebase, displays pairing code, listens for completed audio, streams and plays audio on speaker

**Independent Test**: Power on ESP32 → Note pairing code from serial → Pair via API → Create completed request in Firestore → ESP32 downloads and plays audio

### Core ESP32 Implementation

- [ ] T040 [P] [US3] Implement WiFi connection manager in `esp32/src/wifi_manager.cpp` with WiFiManager library
- [ ] T041 [P] [US3] Implement device registration and heartbeat in `esp32/src/firebase_client.cpp`
- [ ] T042 [US3] Generate and display 6-digit pairing code in `esp32/src/pairing.cpp` (serial output per spec)
- [ ] T043 [US3] Implement Firestore listener for completed requests in `esp32/src/request_listener.cpp` (query: target_device_id + status="completed")
- [ ] T044 [US3] Implement audio streaming and I2S playback in `esp32/src/audio_player.cpp` (MAX98357A DAC)
- [ ] T044a [US3] Implement exponential backoff retry logic for failed audio downloads in `esp32/src/audio_player.cpp` (per FR-035)
- [ ] T044b [US3] Implement WiFi reconnection with auto-resume in `esp32/src/wifi_manager.cpp` (per FR-034)
- [ ] T045 [US3] Implement main loop and status updates in `esp32/src/main.cpp`

### Server Device Pairing Endpoints

- [ ] T046 [US3] Implement POST /devices/pair in `server/src/routes/devices.ts` per server-api.yaml
- [ ] T047 [US3] Implement POST /devices/unpair in `server/src/routes/devices.ts` per server-api.yaml
- [ ] T048 [US3] Implement GET /devices/status in `server/src/routes/devices.ts` per server-api.yaml

**Checkpoint**: User Story 3 is complete - ESP32 receives and plays audio from completed processing requests

---

## Phase 6: User Story 4 - View Processing Status and History (Priority: P3)

**Goal**: User can view list of past processing requests with status, retry failed requests, and track real-time status updates

**Independent Test**: Create multiple requests with various statuses → Open history screen → Verify all requests display with correct status → Retry a failed request → Verify status changes to pending

### Services for User Story 4

- [x] T049 [US4] Add real-time Firestore stream to RequestService in `flutter_app/lib/services/request_service.dart`
- [x] T049a [P] [US4] Implement AudioPlayerService for mobile playback in `flutter_app/lib/services/audio_player_service.dart` (download from Firebase Storage, play locally)
- [x] T049b [US4] Create AudioPlayerProvider with Riverpod in `flutter_app/lib/providers/audio_player_provider.dart` (play/pause/stop state)

### UI for User Story 4

- [x] T050 [US4] Create HistoryScreen with request list in `flutter_app/lib/screens/history_screen.dart`
- [x] T051 [US4] Create RequestStatusCard widget in `flutter_app/lib/widgets/request_status_card.dart` (status color coding)
- [x] T051a [US4] Add play button to RequestStatusCard for mobile audio preview in `flutter_app/lib/widgets/request_status_card.dart`
- [x] T052 [US4] Add retry button and error handling to RequestStatusCard in `flutter_app/lib/widgets/request_status_card.dart`
- [x] T052a [US4] Create AudioPlayerWidget with play/pause controls in `flutter_app/lib/widgets/audio_player_widget.dart` (progress bar, current segment indicator)

**Checkpoint**: User Story 4 is complete - User can view history and retry failed requests

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements, documentation, and validation

- [x] T057 [P] Add error handling and user-friendly messages across all Flutter screens
- [x] T058 [P] Add server error logging with structured JSON logs
- [x] T059 [P] Add ESP32 error recovery and reconnection logic
- [x] T060 Create README.md with setup instructions in project root
- [ ] T061 Run quickstart.md validation - test full end-to-end flow
- [ ] T062 Code cleanup and remove debug console.logs

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - **BLOCKS all user stories**
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
- **Polish (Phase 7)**: Depends on all desired user stories being complete

### User Story Dependencies

```
                     ┌─────────────────────────────┐
                     │  Phase 1: Setup             │
                     └─────────────┬───────────────┘
                                   │
                     ┌─────────────▼───────────────┐
                     │  Phase 2: Foundational      │
                     │  (BLOCKING - must complete) │
                     └─────────────┬───────────────┘
                                   │
          ┌────────────────────────┼────────────────────────┐
          │                        │                        │
          ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   US1: Capture  │    │   US2: Server   │    │   US3: ESP32    │
│   (P1) Flutter  │    │   (P1) OCR/TTS  │    │   (P2) Audio    │
└────────┬────────┘    └────────┬────────┘    └────────┬────────┘
         │                      │                      │
         │              ┌───────┴───────┐              │
         │              │               │              │
         └──────────────┼───────────────┼──────────────┘
                        │               │
                        ▼               ▼
              ┌─────────────────────────────────┐
              │   US4: History (P3) Flutter     │
              │   (Optional - can run parallel) │
              └─────────────────────────────────┘
```

**Note**: US1, US2, and US3 can run in parallel after Foundational phase if team capacity allows. US4 depends on UI foundation from US1.

### Within Each User Story

1. Models before services
2. Services before providers/workers
3. Providers/workers before UI/endpoints
4. Core implementation before integration

### Parallel Opportunities

**Phase 1** (all [P]): T001, T002, T003, T004 can run simultaneously

**Phase 2** (partial [P]): T009, T010, T011, T014, T015, T016, T017 can run simultaneously

**Phase 3 (US1)**: T019, T020 can run simultaneously (models)

**Phase 4 (US2)**: T031, T032 can run simultaneously (models)

**Phase 5 (US3)**: T040, T041 can run simultaneously (ESP32 modules)

---

## Parallel Example: Phase 1 Setup

```bash
# All four project structures can be created simultaneously:
Task T001: "Create Flutter app project structure with flutter create flutter_app"
Task T002: "Create Node.js server project structure in server/"
Task T003: "Create PlatformIO ESP32 project structure in esp32/"
Task T004: "Create Firebase configuration directory in firebase/"
```

---

## Parallel Example: User Story 2 Models

```bash
# Both server models can be created simultaneously:
Task T031: "Create ProcessingRequest TypeScript interface in server/src/models/request.model.ts"
Task T032: "Create AudioSegment TypeScript interface in server/src/models/audio-segment.model.ts"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2 Only)

1. ✅ Complete Phase 1: Setup
2. ✅ Complete Phase 2: Foundational (CRITICAL)
3. ✅ Complete Phase 3: User Story 1 (Capture/Upload)
4. ✅ Complete Phase 4: User Story 2 (OCR/TTS Processing)
5. **STOP and VALIDATE**: Test image capture → upload → OCR → audio generation
6. Deploy/demo if ready (manual audio playback test)

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test capture/upload → Foundation works ✓
3. Add User Story 2 → Test OCR/TTS pipeline → Core pipeline works ✓ (MVP!)
4. Add User Story 3 → Test ESP32 playback → Full IoT flow works ✓
5. Add User Story 4 → Test history/retry → Complete feature ✓

### Parallel Team Strategy

With multiple developers:

1. **Week 1**: Team completes Setup + Foundational together
2. **Week 2**: Once Foundational is done:
   - Developer A: User Story 1 (Flutter capture/upload)
   - Developer B: User Story 2 (Server OCR/TTS)
   - Developer C: User Story 3 (ESP32 firmware)
3. **Week 3**: 
   - Developer A: User Story 4 (Flutter history)
   - Developer B: Integration testing US1 + US2
   - Developer C: Integration testing US2 + US3
4. Stories complete and integrate for end-to-end demo

---

## Notes

- **[P]** tasks = different files, no dependencies on incomplete tasks
- **[US#]** label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests pass at each checkpoint before moving to next phase
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- **Hardware**: ESP32-WROVER required (not WROOM) - needs PSRAM for audio library
- **TTS Output**: ~800KB/min, segments split at <1MB per file
