import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/processing_request_model.dart';
import '../providers/audio_player_provider.dart';
import '../services/request_service.dart';
import '../utils/error_messages.dart';
import 'audio_player_widget.dart';

class RequestStatusCard extends ConsumerWidget {
  final ProcessingRequestModel request;

  const RequestStatusCard({super.key, required this.request});

  Color get _statusColor {
    switch (request.status) {
      case ProcessingStatus.pending:
        return Colors.orange;
      case ProcessingStatus.processing:
        return Colors.blue;
      case ProcessingStatus.completed:
        return Colors.green;
      case ProcessingStatus.delivered:
        return Colors.teal;
      case ProcessingStatus.error:
      default:
        return Colors.red;
    }
  }

  String get _statusLabel => request.status.name;

  Future<void> _retry() async {
    await RequestService().resetToPending(request.requestId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendlyError = request.errorMessage != null
        ? formatFriendlyError(request.errorMessage, fallback: 'An error occurred while processing this request.')
        : null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(_statusLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(request.createdAt.toLocal().toString().split('.').first, style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Target device: ${request.targetDeviceId}'),
            if (friendlyError != null) ...[
              const SizedBox(height: 4),
              Text(friendlyError, style: const TextStyle(color: Colors.redAccent)),
            ],
            if (request.status == ProcessingStatus.completed && (request.audioUrls?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              AudioPlayerWidget(requestId: request.requestId, audioUrls: request.audioUrls!),
            ],
            if (request.status == ProcessingStatus.error)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _retry,
                  child: const Text('Retry'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
