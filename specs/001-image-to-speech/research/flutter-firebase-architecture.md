# Flutter + Firebase Architecture Research

## Executive Summary

This document provides research findings on best practices for Flutter app architecture with Firebase integration for an image-to-speech application requiring:
- Flutter 3.x with Dart 3.x
- JWT-based authentication with Firebase Auth
- Real-time status updates via Firestore listeners
- Camera capture with image compression
- Secure token storage

---

## 1. State Management Choice Analysis

### Options Evaluated

| Solution | Popularity | Learning Curve | Firebase Integration | Testability |
|----------|------------|----------------|---------------------|-------------|
| **Provider** | 10.9k likes, 1.08M downloads | Low | Good | Good |
| **Riverpod** | 2.8k likes, 1.15M downloads | Medium | Excellent | Excellent |
| **Bloc** | High adoption | Medium-High | Good | Excellent |

### **Recommendation: Riverpod 3.x**

**Rationale:**

1. **Compile-time Safety**: Unlike Provider, Riverpod doesn't depend on the widget tree - providers are global and accessible anywhere, eliminating `ProviderNotFoundException` errors at runtime.

2. **Excellent for Real-time Streams**: Riverpod has first-class support for `StreamProvider`, perfect for Firestore listeners:
   ```dart
   final authStateChangesProvider = StreamProvider.autoDispose<User?>((ref) {
     final firebaseAuth = ref.watch(firebaseAuthProvider);
     return firebaseAuth.authStateChanges();
   });
   ```

3. **Built-in Async Handling**: `AsyncValue` pattern elegantly handles loading/error/data states - critical for Firebase operations:
   ```dart
   return authStateAsync.when(
     data: (user) => user != null ? HomePage() : SignInPage(),
     loading: () => const CircularProgressIndicator(),
     error: (err, stack) => Text('Error: $err'),
   );
   ```

4. **Auto-dispose & Caching**: `autoDispose` modifier automatically cleans up Firestore listeners when widgets are unmounted, preventing memory leaks.

5. **Testability**: Providers can be easily overridden in tests without mocking frameworks:
   ```dart
   await tester.pumpWidget(
     ProviderScope(
       overrides: [
         authRepositoryProvider.overrideWithValue(MockAuthRepository())
       ],
       child: MyApp(),
     ),
   );
   ```

6. **Code Generation** (Optional): `riverpod_generator` package reduces boilerplate with `@riverpod` annotations.

**Why NOT Provider:**
- Widget tree dependency can cause runtime errors
- Less elegant async handling
- No built-in caching mechanism

**Why NOT Bloc:**
- More boilerplate (events, states, blocs)
- Overkill for this use case
- Riverpod 3.x covers the same patterns more concisely

---

## 2. Firebase Listeners Structure for Real-time Updates

### Best Practices for Firestore Real-time Listeners

#### Stream Provider Pattern (Recommended)
```dart
// Define a stream provider for job status updates
final jobStatusProvider = StreamProvider.autoDispose.family<JobStatus, String>((ref, jobId) {
  return FirebaseFirestore.instance
      .collection('jobs')
      .doc(jobId)
      .snapshots()
      .map((doc) => JobStatus.fromFirestore(doc));
});
```

#### Key Implementation Guidelines

1. **Use `autoDispose`**: Always use `autoDispose` for Firestore streams to automatically cancel subscriptions when widgets unmount:
   ```dart
   final statusStream = StreamProvider.autoDispose<ProcessingStatus>((ref) {
     return FirebaseFirestore.instance
         .collection('processing_jobs')
         .where('userId', isEqualTo: currentUserId)
         .snapshots();
   });
   ```

2. **Handle Metadata Changes**: For accurate status tracking:
   ```dart
   FirebaseFirestore.instance
       .collection('jobs')
       .doc(jobId)
       .snapshots(includeMetadataChanges: true)
   ```

3. **Detach Listeners Properly**: With Riverpod's `autoDispose`, this is automatic. For manual control:
   ```dart
   ref.onDispose(() {
     subscription?.cancel();
   });
   ```

4. **Use `docChanges()` for Efficiency**: When tracking changes in collections:
   ```dart
   snapshot.docChanges().forEach((change) {
     if (change.type == DocumentChangeType.modified) {
       // Handle status update
     }
   });
   ```

5. **Offline Support**: Enable persistence for offline-first experience:
   ```dart
   // Already enabled by default on mobile
   // For web:
   await FirebaseFirestore.instance.enablePersistence();
   ```

6. **Error Handling**: Always handle stream errors:
   ```dart
   return statusAsync.when(
     data: (status) => StatusWidget(status),
     loading: () => LoadingSpinner(),
     error: (error, stack) => ErrorWidget(error),
   );
   ```

#### Recommended Structure
```
lib/
├── providers/
│   ├── firebase_providers.dart      # Core Firebase instances
│   ├── auth_providers.dart          # Auth state streams
│   └── job_status_providers.dart    # Real-time job status
├── repositories/
│   └── job_repository.dart          # Firestore operations
└── services/
    └── processing_service.dart      # Business logic
```

---

## 3. Secure JWT Token Storage

### **Recommendation: `flutter_secure_storage` v10.x**

| Package | Security Level | Platform Support | Downloads | Recommendation |
|---------|---------------|------------------|-----------|----------------|
| **flutter_secure_storage** | High (OS-level) | All platforms | 1.67M | ✅ **Recommended** |
| hive_flutter | Medium (AES) | All platforms | 378k | For non-sensitive data |
| shared_preferences | Low (plain text) | All platforms | N/A | ❌ Never for tokens |

#### Why `flutter_secure_storage`:

1. **Platform-Native Security**:
   - **iOS**: Uses Keychain (hardware-backed encryption)
   - **Android**: Encrypted SharedPreferences with Tink library (AES-GCM)
   - **Windows/macOS/Linux**: Platform-appropriate secure storage

2. **Encryption Options** (Android):
   | Option | Key Cipher | Storage Cipher | Biometric | Min API |
   |--------|-----------|----------------|-----------|---------|
   | Default `AndroidOptions()` | RSA-OAEP | AES-GCM | No | 23 |
   | `AndroidOptions.biometric(enforceBiometrics: false)` | AES-GCM | AES-GCM | Optional | 23 |
   | `AndroidOptions.biometric(enforceBiometrics: true)` | AES-GCM | AES-GCM | Required | 28 |

3. **Usage Pattern for JWT Tokens**:
   ```dart
   final storage = FlutterSecureStorage(
     aOptions: AndroidOptions(
       encryptedSharedPreferences: true,
     ),
     iOptions: IOSOptions(
       accessibility: KeychainAccessibility.first_unlock_this_device,
     ),
   );
   
   // Store token
   await storage.write(key: 'firebase_id_token', value: idToken);
   
   // Retrieve token
   final token = await storage.read(key: 'firebase_id_token');
   
   // Delete on logout
   await storage.delete(key: 'firebase_id_token');
   ```

4. **iOS Configuration Required**:
   Add to `ios/Runner/DebugProfile.entitlements` and `Release.entitlements`:
   ```xml
   <key>keychain-access-groups</key>
   <array/>
   ```

#### Firebase Auth Token Considerations

Firebase Auth manages ID tokens internally, but you may need secure storage for:
- Custom backend JWT tokens
- Refresh tokens for custom auth systems
- Session identifiers

**Firebase ID Token Access:**
```dart
// Get current ID token (Firebase manages refresh automatically)
final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

// Force refresh if needed
final freshToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);

// Listen for token changes
FirebaseAuth.instance.idTokenChanges().listen((user) async {
  if (user != null) {
    final token = await user.getIdToken();
    // Token refreshed, update backend if needed
  }
});
```

---

## 4. Camera Package Selection

### Options Compared

| Package | Use Case | Control Level | Document Capture | Platform Support |
|---------|----------|---------------|------------------|------------------|
| **camera** | Full control | High | Excellent | iOS, Android, Web |
| **image_picker** | Quick selection | Low | Good | All platforms |

### **Recommendation: `camera` Package (v0.11.x)**

**Rationale for Document Capture:**

1. **Fine-grained Control**: 
   - Direct resolution control (`ResolutionPreset.max`, `ResolutionPreset.high`)
   - Focus control for document clarity
   - Exposure adjustments

2. **Live Preview**: Essential for aligning documents properly:
   ```dart
   CameraController controller = CameraController(
     cameras.first,
     ResolutionPreset.high,  // Use high for document quality
     enableAudio: false,     // Not needed for documents
   );
   ```

3. **CameraX Support** (Android): The `camera_android_camerax` package provides better device compatibility and automatic resolution selection.

4. **Image Streaming**: Access to raw image frames for real-time processing:
   ```dart
   controller.startImageStream((CameraImage image) {
     // Process frame for edge detection, etc.
   });
   ```

#### Implementation Pattern:
```dart
class DocumentCaptureScreen extends ConsumerStatefulWidget {
  @override
  _DocumentCaptureScreenState createState() => _DocumentCaptureScreenState();
}

class _DocumentCaptureScreenState extends ConsumerState<DocumentCaptureScreen>
    with WidgetsBindingObserver {
  late CameraController _controller;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller.initialize();
  }

  Future<void> _captureDocument() async {
    try {
      final XFile image = await _controller.takePicture();
      // Process image...
    } catch (e) {
      // Handle error
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle lifecycle - critical for camera resources
    if (state == AppLifecycleState.inactive) {
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }
}
```

#### When to use `image_picker`:
- Simple gallery selection
- Quick prototyping
- When camera preview isn't needed
- Cross-platform consistency is priority over quality

---

## 5. Image Compression Before Upload

### **Recommendation: `flutter_image_compress` v2.4.x**

| Package | Native Performance | Formats | Quality Control | Platform Support |
|---------|-------------------|---------|-----------------|------------------|
| **flutter_image_compress** | ✅ Native (fast) | JPEG, PNG, WebP, HEIC | Excellent | iOS, Android, macOS, Web |
| image (Dart) | ❌ Slow (Dart isolates) | Many | Good | All |

#### Why `flutter_image_compress`:

1. **Native Performance**: Uses platform-native compression (Kotlin/ObjC) - significantly faster than pure Dart:
   > "For unknown reasons, image compression in Dart language is not efficient, even in release version. Using isolate does not solve the problem."

2. **Flexible Compression Methods**:
   ```dart
   // Method 1: Compress file and get Uint8List (memory)
   final result = await FlutterImageCompress.compressWithFile(
     file.path,
     minWidth: 1920,
     minHeight: 1080,
     quality: 85,
     format: CompressFormat.jpeg,
   );

   // Method 2: Compress and save to file
   final compressedFile = await FlutterImageCompress.compressAndGetFile(
     file.path,
     targetPath,
     quality: 85,
   );

   // Method 3: Compress from memory
   final compressed = await FlutterImageCompress.compressWithList(
     imageBytes,
     minHeight: 1920,
     minWidth: 1080,
     quality: 85,
   );
   ```

3. **Smart Scaling**:
   - `minWidth`/`minHeight` are constraints, not exact targets
   - Maintains aspect ratio automatically
   - Only downscales (never upscales if source is smaller)

4. **EXIF Handling**:
   ```dart
   // Preserve EXIF data if needed (except orientation)
   final result = await FlutterImageCompress.compressWithFile(
     file.path,
     keepExif: true,  // Default is false
   );
   ```

#### Recommended Compression Strategy for OCR Documents:

```dart
class ImageCompressionService {
  /// Compress document image for upload
  /// Optimized for OCR readability while reducing size
  Future<Uint8List?> compressForOCR(File imageFile) async {
    return await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 2048,      // Good resolution for text clarity
      minHeight: 2048,
      quality: 90,         // High quality for OCR accuracy
      format: CompressFormat.jpeg,
      autoCorrectionAngle: true,  // Fix rotation
    );
  }

  /// Compress for preview/thumbnail
  Future<Uint8List?> compressForPreview(File imageFile) async {
    return await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 512,
      minHeight: 512,
      quality: 70,
      format: CompressFormat.jpeg,
    );
  }
}
```

#### Size Expectations:
- Original camera photo: 3-8 MB
- Compressed for OCR (quality 90, 2048px): 200-500 KB
- Compressed for preview (quality 70, 512px): 30-80 KB

---

## Architecture Recommendation Summary

### Recommended Package Versions (as of Feb 2026)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^3.2.1
  riverpod_annotation: ^2.x.x  # Optional: for code generation
  
  # Firebase
  firebase_core: ^latest
  firebase_auth: ^latest
  cloud_firestore: ^latest
  
  # Camera & Image Processing
  camera: ^0.11.3
  flutter_image_compress: ^2.4.0
  
  # Secure Storage
  flutter_secure_storage: ^10.0.0

dev_dependencies:
  riverpod_generator: ^2.x.x  # Optional
  build_runner: ^2.x.x        # If using code generation
```

### Architecture Layers (Riverpod-based)

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  (Widgets, Screens, ConsumerWidget, ConsumerStateful)   │
└─────────────────────────────┬───────────────────────────┘
                              │ ref.watch / ref.read
┌─────────────────────────────▼───────────────────────────┐
│                    Provider Layer                        │
│  (StateProvider, StreamProvider, FutureProvider,        │
│   AsyncNotifierProvider)                                 │
└─────────────────────────────┬───────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────┐
│                   Repository Layer                       │
│  (AuthRepository, JobRepository, StorageRepository)     │
└─────────────────────────────┬───────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────┐
│                    Data Sources                          │
│  (Firebase Auth, Firestore, Firebase Storage, Camera)   │
└─────────────────────────────────────────────────────────┘
```

### Key Patterns to Implement

1. **Auth State as StreamProvider** - Single source of truth for auth
2. **Job Status as StreamProvider.family** - Real-time updates per job
3. **Camera as Stateful Controller** - Lifecycle-aware implementation
4. **Secure Storage via Repository** - Abstracted token management
5. **Image Processing as Service** - Compression before upload

---

## References

- [Riverpod Documentation](https://riverpod.dev/)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [flutter_secure_storage on pub.dev](https://pub.dev/packages/flutter_secure_storage)
- [camera package on pub.dev](https://pub.dev/packages/camera)
- [flutter_image_compress on pub.dev](https://pub.dev/packages/flutter_image_compress)
- [Firebase Auth - Verify ID Tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
