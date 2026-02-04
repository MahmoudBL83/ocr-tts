# Feature Specification: Image-to-Speech OCR Pipeline

**Feature Branch**: `001-image-to-speech`  
**Created**: 2026-02-04  
**Status**: Draft  
**Input**: User description: "Build a Flutter app to capture images, upload to Firebase, process with OCR and TTS on Node.js server, and play audio on ESP32 via WiFi"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Capture and Upload Image (Priority: P1)

A visually impaired user opens the Flutter app on their Android phone and points the camera at a document, sign, or any text they want to read. They tap the capture button, and the app takes a photo and uploads it to Firebase. The user sees a confirmation that their image was submitted for processing.

**Why this priority**: This is the entry point of the entire pipeline. Without image capture and upload, no downstream processing can occur. This delivers immediate value by confirming the system is working.

**Independent Test**: Can be fully tested by capturing an image and verifying it appears in Firebase Storage with correct metadata. Delivers value: user knows their request was received.

**Acceptance Scenarios**:

1. **Given** the app is open with camera permission granted, **When** user taps the capture button, **Then** the camera takes a photo and displays a preview
2. **Given** a photo has been captured, **When** user confirms the upload, **Then** the image is uploaded to Firebase Storage and a processing request is created with status "pending"
3. **Given** the upload is in progress, **When** user views the app, **Then** they see an upload progress indicator
4. **Given** the upload completes successfully, **When** the confirmation appears, **Then** the user sees a unique request ID and "Processing..." status

---

### User Story 2 - Process Image with OCR and Generate Audio (Priority: P1)

The Node.js server detects a new pending image in Firebase, downloads it, performs OCR to extract text, converts the text to speech audio, and uploads the audio file back to Firebase. The processing status is updated to "completed" so downstream consumers know the audio is ready.

**Why this priority**: This is the core intelligence of the system - transforming images into audio. Without this, the pipeline delivers no value. Tied with US1 as essential for MVP.

**Independent Test**: Can be tested by manually uploading a test image to Firebase and verifying that audio file is generated and status changes to "completed". Delivers value: text is extracted and converted to audio.

**Acceptance Scenarios**:

1. **Given** an image with status "pending" exists in Firebase, **When** the server processes the queue, **Then** the server downloads the image and begins OCR processing
2. **Given** OCR processing completes, **When** text is extracted, **Then** the server converts the text to speech audio (MP3 format)
3. **Given** audio generation completes, **When** the audio file is ready, **Then** the server uploads it to Firebase Storage at a predictable path
4. **Given** all processing completes successfully, **When** the server updates Firebase, **Then** the request status changes to "completed" with the audio file URL
5. **Given** the image contains no readable text, **When** OCR completes, **Then** the server generates a brief audio message: "No text detected in image"

---

### User Story 3 - Play Audio on ESP32 Speaker (Priority: P2)

The ESP32 microcontroller monitors Firebase for completed audio files targeting its device. When new audio is available, the ESP32 downloads the audio file over WiFi and plays it through the connected speaker so the user can hear the text that was in their image.

**Why this priority**: This is the final output of the pipeline that delivers value to the user. Slightly lower priority than US1/US2 because audio can initially be played on the phone while ESP32 integration is developed.

**Independent Test**: Can be tested by manually uploading an audio file to Firebase and verifying ESP32 downloads and plays it. Delivers value: hands-free audio output on dedicated device.

**Acceptance Scenarios**:

1. **Given** ESP32 is powered on and connected to WiFi, **When** a new audio file with matching device ID is marked "completed", **Then** ESP32 downloads the audio file
2. **Given** the audio file is downloaded, **When** playback begins, **Then** the user hears the text through the ESP32 speaker
3. **Given** playback completes, **When** ESP32 updates Firebase, **Then** the request status changes to "delivered"
4. **Given** WiFi connection is lost during download, **When** connection is restored, **Then** ESP32 retries the download automatically

---

### User Story 4 - View Processing Status (Priority: P3)

The user wants to track what happened to their submitted images. They can view a history of their requests showing status (pending, processing, completed, delivered, error) and can replay audio for completed requests.

**Why this priority**: Enhances user experience but not critical for core functionality. Users can still use the system without status history.

**Independent Test**: Can be tested by submitting multiple images and viewing the status list. Delivers value: transparency and ability to replay audio.

**Acceptance Scenarios**:

1. **Given** user has submitted images previously, **When** they open the history view, **Then** they see a list of all requests with current status
2. **Given** a request has status "completed", **When** user taps on it, **Then** they can play the audio on their phone (before or instead of ESP32 playback)
3. **Given** audio is playing on the phone, **When** user taps pause/stop, **Then** playback pauses or stops with visual feedback
4. **Given** a request has status "error", **When** user views details, **Then** they see an error message explaining what went wrong

---

### Edge Cases

- What happens when the image is too large (>10MB)? The app compresses it before upload or shows an error.
- What happens when OCR extracts very long text (>5000 characters)? The server splits audio into sequential segments (<1MB each), ESP32 plays them in order with brief pauses between segments.
- What happens when Firebase is unreachable? The app queues the image locally and retries when connectivity returns.
- What happens when ESP32 loses WiFi mid-playback? Playback pauses; resumes or restarts when connected.
- What happens when multiple requests are pending? Server processes in FIFO order; ESP32 plays in FIFO order.
- What happens when image has no text? Server generates "No text detected" audio message.
- What happens when battery is low on ESP32? Device should still complete current playback before sleeping.

## Requirements *(mandatory)*

### Functional Requirements

#### Flutter App (Authentication & Image Capture)

- **FR-001**: App MUST authenticate users via JWT-based sign-in before accessing features
- **FR-002**: App MUST securely store and refresh JWT tokens
- **FR-003**: App MUST allow users to pair with their ESP32 device by entering a 6-digit code displayed on ESP32 serial output
- **FR-004**: App MUST request and handle camera permissions gracefully
- **FR-005**: App MUST display live camera preview before capture
- **FR-006**: App MUST allow user to capture an image with a single tap
- **FR-007**: App MUST display captured image preview before upload confirmation
- **FR-008**: App MUST compress images larger than 5MB before upload
- **FR-009**: App MUST upload images to Firebase Storage with unique identifiers
- **FR-010**: App MUST create a processing request record in Firebase with status "pending" and user's paired device ID as target
- **FR-011**: App MUST display upload progress to the user
- **FR-012**: App MUST handle upload failures with retry option
- **FR-013**: App MUST allow viewing processing status history (filtered by authenticated user)
- **FR-013a**: App MUST allow users to play completed audio on their mobile device (before or instead of ESP32 playback)
- **FR-013b**: App MUST provide play/pause/stop controls for mobile audio playback with visual progress indicator

#### Node.js Server (OCR & TTS Processing)

- **FR-014**: Server MUST validate JWT tokens for any authenticated API calls
- **FR-015**: Server MUST monitor Firebase for new "pending" requests
- **FR-016**: Server MUST download images from Firebase Storage for processing
- **FR-017**: Server MUST extract text from images using OCR
- **FR-018**: Server MUST convert extracted text to speech audio (MP3 format) using English natural-sounding voice (~800KB per minute)
- **FR-019**: Server MUST split long text into sequential audio segments (<1MB each) when total audio would exceed ESP32 buffer capacity
- **FR-020**: Server MUST upload generated audio to Firebase Storage
- **FR-021**: Server MUST update request status to "completed" with audio URL
- **FR-022**: Server MUST handle OCR failures gracefully and update status to "error"
- **FR-023**: Server MUST generate "No text detected" audio for empty OCR results
- **FR-024**: Server MUST process requests in first-in-first-out order
- **FR-025**: Server MUST log all processing steps with request ID for traceability

#### ESP32 Microcontroller (Audio Playback)

- **FR-026**: ESP32 MUST connect to configured WiFi network on startup
- **FR-027**: ESP32 MUST display a unique 6-digit pairing code on serial output for user to enter in app
- **FR-028**: ESP32 MUST authenticate with Firebase using device credentials
- **FR-029**: ESP32 MUST monitor Firebase for "completed" audio files targeting its device ID
- **FR-030**: ESP32 MUST download audio files from Firebase Storage
- **FR-031**: ESP32 MUST play audio segments sequentially with brief pauses between segments
- **FR-032**: ESP32 MUST play audio through connected speaker
- **FR-033**: ESP32 MUST update request status to "delivered" after all segments are played
- **FR-034**: ESP32 MUST automatically reconnect to WiFi if connection is lost
- **FR-035**: ESP32 MUST retry failed audio downloads with exponential backoff

#### Firebase (Central Data Hub)

- **FR-036**: Firebase MUST store images in Storage at path `images/{user_id}/{request_id}.{ext}`
- **FR-037**: Firebase MUST store audio files in Storage at path `audio/{user_id}/{request_id}_part{N}.mp3` (N=1,2,3... for segments)
- **FR-038**: Firebase MUST maintain request records with: id, status, timestamps, owner_user_id, target_device_id, image_url, audio_urls (array for segments), segment_count
- **FR-039**: Firebase MUST support status values: pending, processing, completed, delivered, error
- **FR-040**: Firebase MUST enforce security rules restricting access to user's own data
- **FR-041**: Firebase MUST maintain user-device pairing records (one ESP32 per user)

### Key Entities

- **ProcessingRequest**: Represents a single image-to-speech conversion request. Attributes: unique ID, status, creation timestamp, completion timestamp, owner user ID, target device ID (from user's paired device), image storage path, audio storage path, error message (if failed), extracted text length
- **Device**: Represents a registered ESP32 playback device paired to a user. Attributes: device ID, friendly name, owner user ID, last seen timestamp, WiFi status, 6-digit pairing code (for initial setup via serial output)
- **User**: Represents an authenticated app user. Attributes: user ID, email, JWT token claims, paired device ID (one default ESP32), request history

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can capture and submit an image for processing in under 30 seconds
- **SC-002**: End-to-end processing (image upload to audio playback) completes in under 2 minutes for standard documents
- **SC-003**: OCR correctly extracts 90% or more of readable text from clear document images
- **SC-004**: Audio playback on ESP32 begins within 10 seconds of status changing to "completed"
- **SC-005**: System successfully processes 50 requests per hour without degradation
- **SC-006**: 95% of submitted images result in successful audio generation (excluding user errors like blank images)
- **SC-007**: ESP32 reconnects to WiFi and resumes operation within 30 seconds of network restoration
- **SC-008**: Users can view their request history and replay audio from previous requests

## Assumptions

- Users have Android devices with functional cameras (iOS support may be added later)
- Users have reliable WiFi for both the Flutter app and ESP32 device
- Text in images is primarily in English (multi-language support can be added later)
- ESP32 has sufficient memory to buffer audio files under 1MB
- Firebase project is configured with appropriate security rules
- OCR and TTS services are available (cloud-based or self-hosted)

## Clarifications

### Session 2026-02-04

- Q: How should the Flutter app identify which ESP32 device should receive the audio output? → A: User-paired device - each user has one default ESP32 stored in their profile
- Q: What authentication mechanism should the mobile app use? → A: JWT signing for user authentication
- Q: What TTS voice language and quality should the system use? → A: English natural voice (~800KB/min), balancing quality with ESP32 buffer limits
- Q: How should the ESP32 device be initially paired with a user's account? → A: Manual 6-digit code entry - user types code shown on ESP32 serial output
- Q: What should happen when extracted text exceeds ESP32's audio buffer capacity? → A: Split into sequential audio segments (<1MB each), played in order with brief pauses
