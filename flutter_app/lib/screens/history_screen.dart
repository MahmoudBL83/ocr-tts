import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/request_provider.dart';
import '../utils/error_messages.dart';
import '../widgets/request_status_card.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Request history')),
      body: requests.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No requests yet.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => RequestStatusCard(request: items[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final message = formatFriendlyError(error, fallback: 'Unable to load your history right now.');
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.refresh(requestProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
