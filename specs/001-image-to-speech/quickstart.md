# Quickstart: Image-to-Speech OCR Pipeline

**Feature Branch**: `001-image-to-speech`  
**Created**: 2026-02-04

This guide gets you up and running with the development environment for all three components.

---

## Prerequisites

### Required Software

| Tool | Version | Purpose |
|------|---------|---------|
| Node.js | 20 LTS | Server runtime |
| Flutter | 3.x | Mobile app SDK |
| Dart | 3.x | Flutter language |
| PlatformIO | Latest | ESP32 development |
| Firebase CLI | Latest | Firebase project management |
| Docker | Latest | Server containerization |
| VS Code | Latest | Recommended IDE |

### Cloud Accounts

- [ ] **Firebase** account with project created
- [ ] **Google Cloud** account (for Vision API)
- [ ] **AWS** account (for Polly TTS)

---

## 1. Firebase Project Setup

### Create Project

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Create new project (or use existing)
firebase projects:create ocr-pipeline-dev

# Initialize Firebase in the project root
firebase init
# Select: Firestore, Storage, Emulators
```

### Configure Emulators

Edit `firebase.json`:

```json
{
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "storage": { "port": 9199 },
    "ui": { "port": 4000 }
  }
}
```

### Deploy Security Rules

```bash
# Copy rules from contracts
cp specs/001-image-to-speech/contracts/firebase-contract.md firebase/

# Deploy rules
firebase deploy --only firestore:rules,storage:rules
```

---

## 2. Server Setup (Node.js)

### Install Dependencies

```bash
cd server

# Initialize project
npm init -y

# Install production dependencies
npm install express firebase-admin @google-cloud/vision @aws-sdk/client-polly typescript ts-node

# Install dev dependencies
npm install -D @types/node @types/express jest ts-jest @types/jest
```

### Configure Environment

Create `server/.env`:

```env
# Firebase
GOOGLE_APPLICATION_CREDENTIALS=./service-account.json
FIREBASE_PROJECT_ID=ocr-pipeline-dev

# Google Cloud Vision (same service account)
# No additional config needed if GOOGLE_APPLICATION_CREDENTIALS is set

# AWS Polly
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-1

# Server
PORT=3000
NODE_ENV=development
```

### Download Service Account

1. Go to Firebase Console → Project Settings → Service Accounts
2. Generate new private key
3. Save as `server/service-account.json`
4. Add to `.gitignore`

### Run Development Server

```bash
# Start Firebase emulators (in separate terminal)
firebase emulators:start

# Run server
npm run dev
```

---

## 3. Flutter App Setup

### Install Dependencies

```bash
cd flutter_app

# Create Flutter project
flutter create .

# Add dependencies
flutter pub add firebase_core firebase_auth cloud_firestore firebase_storage
flutter pub add camera flutter_secure_storage flutter_image_compress
flutter pub add flutter_riverpod

# Add dev dependencies
flutter pub add --dev mockito build_runner
```

### Configure Firebase

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for Flutter
flutterfire configure --project=ocr-pipeline-dev
```

This generates:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist` (if iOS enabled)

### Android Permissions

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    
    <application ...>
        <!-- ... -->
    </application>
</manifest>
```

### Run Development Build

```bash
# Connect Android device or start emulator
flutter devices

# Run app
flutter run
```

---

## 4. ESP32 Setup

### Hardware Requirements

| Component | Description |
|-----------|-------------|
| ESP32-WROVER | Board with PSRAM (required for audio streaming) |
| MAX98357A | I2S DAC amplifier module |
| Speaker | 3W-5W speaker, 4-8 ohm |
| Wiring | Jumper wires for connections |

### Wiring Diagram

```
ESP32-WROVER        MAX98357A
-----------         ---------
GPIO 25 (BCLK)  --> BCLK
GPIO 26 (LRC)   --> LRC
GPIO 22 (DOUT)  --> DIN
3.3V            --> VIN
GND             --> GND
                --> Speaker +/-
```

### Install PlatformIO

```bash
# VS Code extension
code --install-extension platformio.platformio-ide

# Or CLI
pip install platformio
```

### Project Setup

```bash
cd esp32

# Initialize PlatformIO project
pio init --board esp32dev

# Install libraries
pio pkg install --library "schreibfaul1/ESP32-audioI2S"
pio pkg install --library "bblanchon/ArduinoJson"
```

### Configure WiFi and Firebase

Create `esp32/src/config.h`:

```cpp
#ifndef CONFIG_H
#define CONFIG_H

// WiFi Configuration
#define WIFI_SSID "your-wifi-ssid"
#define WIFI_PASSWORD "your-wifi-password"

// Firebase Configuration
#define FIREBASE_PROJECT_ID "ocr-pipeline-dev"
#define FIRESTORE_URL "https://firestore.googleapis.com/v1/projects/ocr-pipeline-dev/databases/(default)/documents"

// Device Configuration
#define DEVICE_ID "esp32-unique-id"

// Audio Pins
#define I2S_BCLK 25
#define I2S_LRC 26
#define I2S_DOUT 22

#endif
```

### Build and Upload

```bash
# Build
pio run

# Upload
pio run --target upload

# Monitor serial output (see pairing code)
pio device monitor --baud 115200
```

---

## 5. Running the Full Stack

### Start All Services

```bash
# Terminal 1: Firebase Emulators
firebase emulators:start

# Terminal 2: Node.js Server
cd server && npm run dev

# Terminal 3: Flutter App
cd flutter_app && flutter run

# Terminal 4: ESP32 Serial Monitor
cd esp32 && pio device monitor
```

### Verify Connectivity

1. **Firebase Emulator UI**: http://localhost:4000
2. **Server Health**: http://localhost:3000/v1/health
3. **Flutter App**: Should show login screen
4. **ESP32 Serial**: Should show WiFi connected + pairing code

---

## 6. Testing

### Run Unit Tests

```bash
# Server tests
cd server && npm test

# Flutter tests
cd flutter_app && flutter test

# ESP32 tests
cd esp32 && pio test
```

### Run Integration Tests

```bash
# Start Firebase emulators
firebase emulators:start

# Run server integration tests
cd server && npm run test:integration

# Run Flutter integration tests
cd flutter_app && flutter test integration_test/
```

---

## 7. Common Issues

### Server

| Issue | Solution |
|-------|----------|
| `GOOGLE_APPLICATION_CREDENTIALS not found` | Ensure service-account.json exists and path is correct |
| `AWS credentials not configured` | Check .env file has valid AWS keys |
| `Firebase emulator connection refused` | Start emulators before server |

### Flutter

| Issue | Solution |
|-------|----------|
| `Camera permission denied` | Check AndroidManifest.xml permissions |
| `Firebase initialization failed` | Run `flutterfire configure` again |
| `Plugin not found` | Run `flutter clean && flutter pub get` |

### ESP32

| Issue | Solution |
|-------|----------|
| `WiFi connection failed` | Verify SSID/password in config.h |
| `Audio not playing` | Check I2S pin connections |
| `PSRAM not detected` | Ensure using ESP32-WROVER (not WROOM) |
| `Build fails with memory error` | WROVER with PSRAM required for audioI2S |

---

## 8. Project Structure Reference

```
ocr/
├── specs/
│   └── 001-image-to-speech/
│       ├── spec.md
│       ├── plan.md
│       ├── research.md
│       ├── data-model.md
│       ├── quickstart.md          # This file
│       └── contracts/
│           ├── server-api.yaml
│           └── firebase-contract.md
├── flutter_app/
│   ├── lib/
│   ├── test/
│   └── pubspec.yaml
├── server/
│   ├── src/
│   ├── tests/
│   └── package.json
├── esp32/
│   ├── src/
│   ├── include/
│   └── platformio.ini
├── firebase/
│   ├── firestore.rules
│   ├── storage.rules
│   └── firebase.json
└── .specify/
```

---

## Next Steps

1. Complete `/speckit.tasks` to generate implementation tasks
2. Set up CI/CD pipelines
3. Configure staging Firebase project
4. Order ESP32-WROVER hardware if needed
