import 'package:flutter/material.dart';

class UploadProgressWidget extends StatelessWidget {
  final double progress;

  const UploadProgressWidget({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Uploading image…', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
      ],
    );
  }
}
