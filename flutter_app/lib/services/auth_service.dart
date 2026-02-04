import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _secureStorage = FlutterSecureStorage();
  static final _googleSignIn = GoogleSignIn();
  static const _tokenKey = 'id_token';

  static Future<User?> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _persistToken(credential.user);
    return credential.user;
  }

  static Future<User?> signUp(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _persistToken(credential.user);
    return credential.user;
  }

  static Future<User?> signInWithGoogle() async {
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    
    if (googleUser == null) {
      // User cancelled the sign-in
      return null;
    }

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the credential
    final userCredential = await _auth.signInWithCredential(credential);
    await _persistToken(userCredential.user);
    return userCredential.user;
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
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
