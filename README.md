# Image-to-Speech OCR Pipeline

A multi-component proof-of-concept that lets visually impaired users capture text with a Flutter mobile app, run it through OCR+TTS on a Node.js backend, and stream the resulting audio to a paired ESP32 speaker. Firebase (Auth/Firestore/Storage) acts as the central sync layer for requests, devices, and files.

## Architecture overview

- **Flutter app (flutter_app/)**: Handles authentication, camera capture, compression, upload, request history, and mobile playback with Riverpod-managed state.
- **Node.js server (server/)**: Listens for `pending` Firestore requests, downloads images, calls Google Cloud Vision for OCR, uses AWS Polly for MP3 segments, uploads audio, and exposes retry/pairing endpoints.
- **ESP32 firmware (esp32/)**: Connects to WiFi, registers via Firebase REST APIs, streams completed audio segments through an I2S DAC (MAX98357A), and updates request status to `delivered`.
- **Firebase config (firebase/)**: Security rules, indexes, and emulator settings needed by every component.

## Getting started

1. **Firebase setup (firebase/)**
   - Configure a project, enable Firestore + Storage + Auth, and copy the contracts from `specs/001-image-to-speech/contracts/` into `firebase/`.
   - Start the emulators with `firebase emulators:start`.

2. **Server**
   ```bash
   cd server
   npm install
   cp .env.example .env            # add Firebase/AWS creds
   npm run dev
   ```

3. **Flutter app**
   ```bash
   cd flutter_app
   flutter pub get
   flutterfire configure --project=<your-project>
   flutter run
   ```

4. **ESP32 (PlatformIO)**
   ```bash
   cd esp32
   pio run
   pio run --target upload
   pio device monitor --baud 115200
   ```

## Testing & Validation

- **Flutter**: `flutter test` (unit/widget) and `flutter test integration_test/` after setting up Firebase emulators.
- **Server**: `npm test` (unit + integration) once the emulator is running.
- **ESP32**: `pio test` or `pio device monitor` to observe pairing codes + logs.
- **Quickstart flow**: Manually follow `specs/001-image-to-speech/quickstart.md` to ensure the end-to-end pipeline works.

## Useful references

- Feature planning + architecture: `specs/001-image-to-speech/plan.md`
- Entity definitions and validation: `specs/001-image-to-speech/data-model.md`
- Contracts: Firestore/Storage rules (`specs/001-image-to-speech/contracts/firebase-contract.md`) and REST endpoints (`specs/001-image-to-speech/contracts/server-api.yaml`).
- Research rationale: `specs/001-image-to-speech/research.md`
- Task list: `specs/001-image-to-speech/tasks.md`

## Next steps

1. Finish Phase 7 polish items in the task list (`specs/001-image-to-speech/tasks.md`).
2. Add README sections to each component (Flutter, Server, ESP32) describing how to configure required secrets/credentials.
3. Validate Firebase emulator + device pairing flows end to end.
