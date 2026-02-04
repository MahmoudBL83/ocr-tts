# Firebase Contract: Image-to-Speech OCR Pipeline

This document defines the contracts for Firebase interactions between components.
Each component (Flutter App, Node.js Server, ESP32) must adhere to these contracts.

---

## Firestore Document Schemas

### Collection: `users/{user_id}`

**Writers**: Flutter App (on signup)  
**Readers**: Flutter App, Node.js Server

```typescript
interface User {
  user_id: string;           // Firebase Auth UID (matches document ID)
  email: string;             // User's email address
  display_name?: string;     // Optional display name
  created_at: Timestamp;     // Account creation time
  paired_device_id?: string; // Currently paired ESP32 device ID
}
```

**Example Document**:
```json
{
  "user_id": "abc123xyz",
  "email": "user@example.com",
  "display_name": "John Doe",
  "created_at": "2026-02-04T10:30:00Z",
  "paired_device_id": "esp32-def456"
}
```

---

### Collection: `devices/{device_id}`

**Writers**: ESP32 (heartbeat, registration), Node.js Server (pairing)  
**Readers**: Flutter App, Node.js Server, ESP32

```typescript
interface Device {
  device_id: string;         // Unique device identifier (matches document ID)
  pairing_code: string;      // 6-digit code for pairing (e.g., "123456")
  friendly_name?: string;    // User-assigned name
  owner_user_id?: string;    // User who owns this device (null if unpaired)
  last_seen: Timestamp;      // Last heartbeat from device
  firmware_version?: string; // Current firmware version
  is_online: boolean;        // Whether device is currently connected
}
```

**Example Document**:
```json
{
  "device_id": "esp32-def456",
  "pairing_code": "123456",
  "friendly_name": "Kitchen Speaker",
  "owner_user_id": "abc123xyz",
  "last_seen": "2026-02-04T14:25:00Z",
  "firmware_version": "1.0.0",
  "is_online": true
}
```

---

### Collection: `requests/{request_id}`

**Writers**: Flutter App (create), Node.js Server (process), ESP32 (deliver)  
**Readers**: Flutter App, Node.js Server, ESP32

```typescript
type RequestStatus = 'pending' | 'processing' | 'completed' | 'delivered' | 'error';

interface ProcessingRequest {
  request_id: string;              // Unique request ID (matches document ID)
  owner_user_id: string;           // User who created request
  target_device_id: string;        // ESP32 device to play audio on
  status: RequestStatus;           // Current processing status
  created_at: Timestamp;           // Request creation time
  updated_at: Timestamp;           // Last status update time
  
  // Image data (set on create)
  image_url: string;               // Firebase Storage download URL
  image_size_bytes?: number;       // Original image file size
  
  // Processing data (set by server)
  processing_started_at?: Timestamp;
  processing_completed_at?: Timestamp;
  extracted_text_length?: number;  // Character count of OCR result
  
  // Audio data (set by server when completed)
  audio_urls?: string[];           // Array of audio segment URLs
  segment_count?: number;          // Number of audio segments
  
  // Delivery data (set by ESP32)
  delivered_at?: Timestamp;        // When ESP32 finished playback
  
  // Error data (set by server on failure)
  error_message?: string;          // Human-readable error
  error_code?: string;             // Machine-readable error code
}
```

**Example Document (pending)**:
```json
{
  "request_id": "req-789xyz",
  "owner_user_id": "abc123xyz",
  "target_device_id": "esp32-def456",
  "status": "pending",
  "created_at": "2026-02-04T14:30:00Z",
  "updated_at": "2026-02-04T14:30:00Z",
  "image_url": "https://firebasestorage.googleapis.com/...",
  "image_size_bytes": 1245678
}
```

**Example Document (completed)**:
```json
{
  "request_id": "req-789xyz",
  "owner_user_id": "abc123xyz",
  "target_device_id": "esp32-def456",
  "status": "completed",
  "created_at": "2026-02-04T14:30:00Z",
  "updated_at": "2026-02-04T14:31:15Z",
  "image_url": "https://firebasestorage.googleapis.com/...",
  "image_size_bytes": 1245678,
  "processing_started_at": "2026-02-04T14:30:05Z",
  "processing_completed_at": "2026-02-04T14:31:15Z",
  "extracted_text_length": 2450,
  "audio_urls": [
    "https://firebasestorage.googleapis.com/.../req-789xyz_part1.mp3",
    "https://firebasestorage.googleapis.com/.../req-789xyz_part2.mp3"
  ],
  "segment_count": 2
}
```

**Example Document (error)**:
```json
{
  "request_id": "req-789xyz",
  "owner_user_id": "abc123xyz",
  "target_device_id": "esp32-def456",
  "status": "error",
  "created_at": "2026-02-04T14:30:00Z",
  "updated_at": "2026-02-04T14:30:45Z",
  "image_url": "https://firebasestorage.googleapis.com/...",
  "processing_started_at": "2026-02-04T14:30:05Z",
  "error_code": "OCR_FAILED",
  "error_message": "OCR service temporarily unavailable"
}
```

---

## Firebase Storage Paths

### Images

**Path**: `images/{user_id}/{request_id}.jpg`

**Writers**: Flutter App  
**Readers**: Node.js Server

**Constraints**:
- Max file size: 5MB (after compression)
- Format: JPEG only
- Content-Type: `image/jpeg`

**Metadata**:
```json
{
  "contentType": "image/jpeg",
  "customMetadata": {
    "request_id": "req-789xyz",
    "user_id": "abc123xyz",
    "original_size": "8500000"
  }
}
```

---

### Audio

**Path**: `audio/{user_id}/{request_id}_part{N}.mp3`

**Writers**: Node.js Server (via Admin SDK)  
**Readers**: Flutter App, ESP32

**Constraints**:
- Max file size per segment: 1MB
- Format: MP3
- Quality: ~800KB per minute of audio
- Content-Type: `audio/mpeg`

**Naming Convention**:
- Single segment: `{request_id}_part1.mp3`
- Multiple segments: `{request_id}_part1.mp3`, `{request_id}_part2.mp3`, etc.
- N is 1-indexed

**Metadata**:
```json
{
  "contentType": "audio/mpeg",
  "customMetadata": {
    "request_id": "req-789xyz",
    "user_id": "abc123xyz",
    "segment_number": "1",
    "total_segments": "2",
    "duration_ms": "45000"
  }
}
```

---

## Queries

### Server: Find Pending Requests

Used by Node.js server to find requests awaiting processing.

```typescript
// Query
db.collection('requests')
  .where('status', '==', 'pending')
  .orderBy('created_at', 'asc')
  .limit(10)
```

**Required Index**: `status ASC, created_at ASC`

---

### ESP32: Find Completed Requests for Device

Used by ESP32 to find audio ready for playback.

```typescript
// Query
db.collection('requests')
  .where('target_device_id', '==', deviceId)
  .where('status', '==', 'completed')
  .orderBy('created_at', 'asc')
  .limit(1)
```

**Required Index**: `target_device_id ASC, status ASC, created_at ASC`

---

### App: User's Request History

Used by Flutter app to display user's request history.

```typescript
// Query
db.collection('requests')
  .where('owner_user_id', '==', userId)
  .orderBy('created_at', 'desc')
  .limit(20)
```

**Required Index**: `owner_user_id ASC, created_at DESC`

---

## Status Transition Contracts

### Who Can Transition What

| From | To | Actor | Conditions |
|------|-----|-------|------------|
| (new) | `pending` | Flutter App | On image upload |
| `pending` | `processing` | Node.js Server | Server picks up request |
| `processing` | `completed` | Node.js Server | Audio generated successfully |
| `processing` | `error` | Node.js Server | OCR/TTS failed |
| `completed` | `delivered` | ESP32 | Audio playback finished |
| `error` | `pending` | Node.js Server | User requests retry via API |

### Transition Payloads

**pending → processing**:
```json
{
  "status": "processing",
  "updated_at": "<server_timestamp>",
  "processing_started_at": "<server_timestamp>"
}
```

**processing → completed**:
```json
{
  "status": "completed",
  "updated_at": "<server_timestamp>",
  "processing_completed_at": "<server_timestamp>",
  "extracted_text_length": 2450,
  "audio_urls": ["url1", "url2"],
  "segment_count": 2
}
```

**processing → error**:
```json
{
  "status": "error",
  "updated_at": "<server_timestamp>",
  "error_code": "OCR_FAILED",
  "error_message": "OCR service temporarily unavailable"
}
```

**completed → delivered**:
```json
{
  "status": "delivered",
  "updated_at": "<server_timestamp>",
  "delivered_at": "<server_timestamp>"
}
```
