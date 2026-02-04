import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService([FirebaseStorage? storage]) : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadImage(String userId, String requestId, File file) async {
    final ref = _storage.ref().child('images/$userId/$requestId.jpg');
    final task = ref.putFile(file);
    await task.whenComplete(() {});
    return ref.getDownloadURL();
  }
}
