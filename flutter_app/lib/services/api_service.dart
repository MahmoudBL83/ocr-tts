import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// API Service to communicate with the backend server
class ApiService {
  // Vercel deployment URL - update if your URL is different
  static const String baseUrl = 'https://ocr-tts.vercel.app/v1';
  
  final FirebaseAuth _auth;

  ApiService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  /// Get the current user's Firebase ID token for authentication
  Future<String?> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Trigger processing for a request
  /// This tells the server to start OCR + TTS processing
  Future<bool> processRequest(String requestId) async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/requests/$requestId/process'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error']?['message'] ?? 'Processing request failed');
    }
  }

  /// Retry a failed request
  Future<bool> retryRequest(String requestId) async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/requests/$requestId/retry'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error']?['message'] ?? 'Retry request failed');
    }
  }

  /// Check server health
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
