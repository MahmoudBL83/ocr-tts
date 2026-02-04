import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const _defaultFriendlyMessage = 'Something went wrong. Please try again.';

String formatFriendlyError(Object? error, {String? fallback}) {
  if (error == null) return fallback ?? _defaultFriendlyMessage;

  if (error is FirebaseException) {
    return error.message?.trim().isNotEmpty == true ? error.message! : (fallback ?? _defaultFriendlyMessage);
  }

  final raw = error is String ? error : error.toString();
  if (raw.isEmpty) return fallback ?? _defaultFriendlyMessage;

  final normalized = raw.replaceAll('[', '').replaceAll(']', '').trim();
  if (normalized.contains('NETWORK_REQUEST_FAILED') || normalized.contains('Network error')) {
    return 'Unable to reach the service. Check your connection and try again.';
  }
  if (normalized.contains('401') || normalized.toLowerCase().contains('unauthorized')) {
    return 'Authentication failed. Please sign in again.';
  }

  return normalized;
}

void showFriendlyErrorSnackBar(BuildContext context, Object? error, {String? fallback}) {
  final message = formatFriendlyError(error, fallback: fallback);
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
