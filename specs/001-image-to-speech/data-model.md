# Data Model: Image-to-Speech OCR Pipeline

**Feature Branch**: `001-image-to-speech`  
**Created**: 2026-02-04  
**Source**: [spec.md](spec.md) Key Entities + [research.md](research.md) Firebase Schema

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                           Firebase                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐       1:1        ┌──────────┐                     │
│  │   User   │─────────────────▶│  Device  │                     │
│  └──────────┘                  └──────────┘                     │
│       │                             ▲                            │
│       │ 1:N                         │                            │
│       ▼                             │ target                     │
│  ┌──────────────────┐               │                            │
│  │ ProcessingRequest │──────────────┘                            │
│  └──────────────────┘                                            │
│       │                                                          │
│       │ 1:N                                                      │
│       ▼                                                          │
│  ┌──────────────────┐                                            │
│  │   AudioSegment   │  (virtual - stored as array in request)   │
│  └──────────────────┘                                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Entities

### 1. User

Represents an authenticated app user.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `user_id` | string | ✅ | Firebase Auth UID (primary key) |
| `email` | string | ✅ | User's email address |
| `display_name` | string | ❌ | User's display name |
| `created_at` | timestamp | ✅ | Account creation time |
| `paired_device_id` | string | ❌ | Currently paired ESP32 device ID |

**Firestore Path**: `users/{user_id}`

**Validation Rules**:
- `email`: Valid email format
- `user_id`: Must match Firebase Auth UID
- `paired_device_id`: Must reference existing device if set

**State Transitions**: N/A (static entity)

---

### 2. Device

Represents a registered ESP32 playback device.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `device_id` | string | ✅ | Unique device identifier (primary key) |
| `pairing_code` | string | ✅ | 6-digit code for initial pairing |
| `friendly_name` | string | ❌ | User-assigned device name |
| `owner_user_id` | string | ❌ | User who owns this device (null if unpaired) |
| `last_seen` | timestamp | ✅ | Last heartbeat from device |
| `firmware_version` | string | ❌ | Current firmware version |
| `is_online` | boolean | ✅ | Whether device is currently connected |

**Firestore Path**: `devices/{device_id}`

**Validation Rules**:
- `pairing_code`: Exactly 6 numeric digits
- `device_id`: Alphanumeric, 8-32 characters
- `owner_user_id`: Must reference existing user if set

**State Transitions**:
```
[Unpaired] ──(user enters code)──▶ [Paired] ──(user unpairs)──▶ [Unpaired]
     │                                 │
     └──────(device reset)─────────────┘
```

---

### 3. ProcessingRequest

Represents a single image-to-speech conversion request.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `request_id` | string | ✅ | Unique request identifier (primary key) |
| `owner_user_id` | string | ✅ | User who created this request |
| `target_device_id` | string | ✅ | ESP32 device to play audio on |
| `status` | enum | ✅ | Current processing status |
| `created_at` | timestamp | ✅ | Request creation time |
| `updated_at` | timestamp | ✅ | Last status update time |
| `image_url` | string | ✅ | Firebase Storage URL for uploaded image |
| `image_size_bytes` | number | ❌ | Original image file size |
| `audio_urls` | string[] | ❌ | Firebase Storage URLs for audio segments |
| `segment_count` | number | ❌ | Number of audio segments (1 for short text) |
| `extracted_text_length` | number | ❌ | Character count of OCR result |
| `processing_started_at` | timestamp | ❌ | When server began processing |
| `processing_completed_at` | timestamp | ❌ | When audio generation finished |
| `delivered_at` | timestamp | ❌ | When ESP32 finished playback |
| `error_message` | string | ❌ | Error description if status is "error" |
| `error_code` | string | ❌ | Machine-readable error code |

**Firestore Path**: `requests/{request_id}`

**Status Enum Values**:
| Value | Description |
|-------|-------------|
| `pending` | Image uploaded, awaiting server processing |
| `processing` | Server is performing OCR/TTS |
| `completed` | Audio ready, awaiting ESP32 playback |
| `delivered` | ESP32 finished playing all segments |
| `error` | Processing failed (see error_message) |

**Validation Rules**:
- `status`: Must be one of the enum values
- `audio_urls`: Required when status is `completed` or `delivered`
- `error_message`: Required when status is `error`
- `target_device_id`: Must reference device owned by `owner_user_id`

**State Transitions**:
```
                    ┌─────────────────────────────────┐
                    │                                 │
                    ▼                                 │
[pending] ──(server picks up)──▶ [processing] ──(OCR/TTS fails)──▶ [error]
                                      │
                                      │ (success)
                                      ▼
                               [completed] ──(ESP32 plays)──▶ [delivered]
```

---

## Storage Paths

### Firebase Storage Structure

```
images/
└── {user_id}/
    └── {request_id}.jpg          # Uploaded image (JPEG, max 5MB compressed)

audio/
└── {user_id}/
    ├── {request_id}_part1.mp3    # First audio segment
    ├── {request_id}_part2.mp3    # Second segment (if text was long)
    └── {request_id}_part{N}.mp3  # Additional segments
```

### Path Conventions
- **Image format**: JPEG only (after compression)
- **Audio format**: MP3, ~800KB per minute
- **Segment naming**: `_part{N}` suffix where N starts at 1
- **User isolation**: All files scoped under `{user_id}/` directory

---

## Indexes

### Required Composite Indexes

```json
{
  "indexes": [
    {
      "collectionGroup": "requests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "target_device_id", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "created_at", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "requests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "owner_user_id", "order": "ASCENDING" },
        { "fieldPath": "created_at", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "requests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "created_at", "order": "ASCENDING" }
      ]
    }
  ]
}
```

### Index Usage
| Query | Index Used |
|-------|------------|
| ESP32: Find pending audio for my device | `target_device_id + status + created_at` |
| App: User's request history | `owner_user_id + created_at DESC` |
| Server: Find pending requests to process | `status + created_at` |

---

## Security Rules

### Firestore Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can read/write their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Devices: owner can read/write; unpaired devices can be claimed
    match /devices/{deviceId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        (resource.data.owner_user_id == null || 
         resource.data.owner_user_id == request.auth.uid);
    }
    
    // Requests: users can CRUD their own; devices can update status
    match /requests/{requestId} {
      allow read: if request.auth != null && 
        resource.data.owner_user_id == request.auth.uid;
      allow create: if request.auth != null && 
        request.resource.data.owner_user_id == request.auth.uid;
      allow update: if request.auth != null && 
        (resource.data.owner_user_id == request.auth.uid ||
         isDeviceUpdate());
      allow delete: if request.auth != null && 
        resource.data.owner_user_id == request.auth.uid;
    }
    
    function isDeviceUpdate() {
      // Allow device to update only status and delivered_at
      return request.resource.data.diff(resource.data).affectedKeys()
        .hasOnly(['status', 'delivered_at', 'updated_at']);
    }
  }
}
```

### Storage Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Images: user can upload to their own folder
    match /images/{userId}/{fileName} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId
        && request.resource.size < 5 * 1024 * 1024  // 5MB max
        && request.resource.contentType.matches('image/.*');
    }
    
    // Audio: server writes, user and device read
    match /audio/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if false;  // Only server (admin SDK) can write
    }
  }
}
```

---

## Error Codes

| Code | Description | Recovery |
|------|-------------|----------|
| `OCR_FAILED` | OCR service returned error | Retry request |
| `OCR_NO_TEXT` | No text detected in image | Upload clearer image |
| `TTS_FAILED` | TTS service returned error | Retry request |
| `TTS_TOO_LONG` | Text exceeds maximum length | Reduce text (internal) |
| `UPLOAD_FAILED` | Image upload to storage failed | Retry upload |
| `DEVICE_OFFLINE` | Target device not responding | Wait for device to reconnect |
| `DEVICE_NOT_FOUND` | Target device ID doesn't exist | Re-pair device |
