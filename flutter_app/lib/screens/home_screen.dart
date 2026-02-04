import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../utils/error_messages.dart';
import '../widgets/upload_progress_widget.dart';
import 'camera_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          // User not logged in, show login screen directly
          return const LoginScreen();
        }
        // User is logged in, show home content
        return Scaffold(
          appBar: AppBar(
            title: const Text('Image-to-Speech'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => ref.read(authProvider.notifier).signOut(),
                tooltip: 'Sign out',
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, ${user.displayName ?? user.email}', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                const UploadProgressWidget(progress: 0.4),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CameraScreen())),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture image'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
                  icon: const Icon(Icons.history),
                  label: const Text('View history'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) {
        final message = formatFriendlyError(error, fallback: 'Unable to load your profile right now.');
        return Scaffold(
          appBar: AppBar(title: const Text('Image-to-Speech')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(authProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
