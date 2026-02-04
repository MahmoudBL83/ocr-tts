import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/processing_request_model.dart';

class RequestService {
  final _requests = FirebaseFirestore.instance.collection('requests');

  Future<void> createRequest(ProcessingRequestModel request) async {
    await _requests.doc(request.requestId).set(request.toJson());
  }

  Stream<List<ProcessingRequestModel>> watchRequestsForUser(String userId) {
    return _requests
        .where('owner_user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ProcessingRequestModel.fromJson(doc.data())).toList());
  }

  Future<void> resetToPending(String requestId) async {
    final now = DateTime.now().toIso8601String();
    await _requests.doc(requestId).set(
      {
        'status': 'pending',
        'updated_at': now,
        'error_message': FieldValue.delete(),
        'error_code': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
  }
}
