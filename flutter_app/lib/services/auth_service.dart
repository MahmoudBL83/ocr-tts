import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _secureStorage = FlutterSecureStorage();
  static const _tokenKey = 'id_token';

  static Future<User?> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _persistToken(credential.user);
    return credential.user;
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    await _secureStorage.delete(key: _tokenKey);
  }

  static Future<void> _persistToken(User? user) async {
    if (user == null) return;
    final idToken = await user.getIdToken();
    await cacheToken(idToken);
  }

  static Future<String?> getIdToken({bool refresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final idToken = await user.getIdToken(refresh);
    await cacheToken(idToken);
    return idToken;
  }

  static Future<void> cacheToken(String? token) async {
    if (token == null) return;
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  static Future<void> refreshToken() async {
    await getIdToken(refresh: true);
  }
}
