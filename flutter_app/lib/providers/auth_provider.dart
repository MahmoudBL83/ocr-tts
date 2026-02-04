import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>(
  (ref) => AuthNotifier(),
);

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  late final StreamSubscription<User?> _subscription;

  AuthNotifier() : super(const AsyncValue.loading()) {
    _subscription = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> signIn(String email, String password) async {
    try {
      await AuthService.signIn(email, password);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      await AuthService.signUp(email, password);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await AuthService.signInWithGoogle();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await AuthService.signOut();
  }

  Future<void> refreshToken() async {
    await AuthService.refreshToken();
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      state = const AsyncValue.data(null);
      return;
    }

    final token = await user.getIdToken();
    await AuthService.cacheToken(token);
    state = AsyncValue.data(
      UserModel(
        userId: user.uid,
        email: user.email ?? 'unknown',
        displayName: user.displayName,
      ),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
