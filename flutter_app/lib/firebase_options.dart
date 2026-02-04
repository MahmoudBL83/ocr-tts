// File generated manually - update with your Firebase project settings
// After running `flutterfire configure`, this file will be auto-updated
// For now, fill in the values from Firebase Console

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ============================================================
  // Firebase configuration for ocr-tts-ad7d6 project
  // ============================================================

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAWU1QKxRQJgApG3Ta75BttiloVKgDZcAY',
    appId: '1:471080148167:android:c0d7db0a9e4055e12db2e2',
    messagingSenderId: '471080148167',
    projectId: 'ocr-tts-ad7d6',
    storageBucket: 'ocr-tts-ad7d6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAWU1QKxRQJgApG3Ta75BttiloVKgDZcAY',
    appId: '1:471080148167:android:c0d7db0a9e4055e12db2e2',  // Update if you add iOS app
    messagingSenderId: '471080148167',
    projectId: 'ocr-tts-ad7d6',
    storageBucket: 'ocr-tts-ad7d6.firebasestorage.app',
    iosBundleId: 'com.example.flutterApp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAWU1QKxRQJgApG3Ta75BttiloVKgDZcAY',
    appId: '1:471080148167:android:c0d7db0a9e4055e12db2e2',  // Update if you add Web app
    messagingSenderId: '471080148167',
    projectId: 'ocr-tts-ad7d6',
    authDomain: 'ocr-tts-ad7d6.firebaseapp.com',
    storageBucket: 'ocr-tts-ad7d6.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAWU1QKxRQJgApG3Ta75BttiloVKgDZcAY',
    appId: '1:471080148167:android:c0d7db0a9e4055e12db2e2',
    messagingSenderId: '471080148167',
    projectId: 'ocr-tts-ad7d6',
    storageBucket: 'ocr-tts-ad7d6.firebasestorage.app',
    iosBundleId: 'com.example.flutterApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAWU1QKxRQJgApG3Ta75BttiloVKgDZcAY',
    appId: '1:471080148167:android:c0d7db0a9e4055e12db2e2',
    messagingSenderId: '471080148167',
    projectId: 'ocr-tts-ad7d6',
    storageBucket: 'ocr-tts-ad7d6.firebasestorage.app',
  );
}
