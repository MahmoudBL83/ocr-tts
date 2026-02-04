import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/processing_request_model.dart';
import '../providers/auth_provider.dart';
import '../services/request_service.dart';

final requestProvider = StreamProvider.autoDispose<List<ProcessingRequestModel>>((ref) {
  final user = ref.watch(authProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return RequestService().watchRequestsForUser(user.userId);
});
