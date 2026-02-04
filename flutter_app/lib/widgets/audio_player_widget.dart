import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/audio_player_provider.dart';
import '../utils/error_messages.dart';

class AudioPlayerWidget extends ConsumerWidget {
  final String requestId;
  final List<String> audioUrls;

  const AudioPlayerWidget({super.key, required this.requestId, required this.audioUrls});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final hasAudio = audioUrls.isNotEmpty;
    final isCurrentRequest = state.requestId == requestId;
    final isLoading = isCurrentRequest && state.status == AudioPlaybackStatus.loading;
    final isPlaying = isCurrentRequest && state.status == AudioPlaybackStatus.playing;
    final isPaused = isCurrentRequest && state.status == AudioPlaybackStatus.paused;
    final isError = isCurrentRequest && state.status == AudioPlaybackStatus.error;
    final segmentProgress = state.duration.inMilliseconds > 0
        ? state.position.inMilliseconds / state.duration.inMilliseconds
        : 0.0;
    final overallProgress = state.totalSegments > 0
        ? ((((state.currentSegment > 0 ? state.currentSegment - 1 : 0) + segmentProgress) /
                    state.totalSegments)
                .clamp(0.0, 1.0))
            .toDouble()
        : 0.0;
    final percentLabel = (overallProgress * 100).toStringAsFixed(0);

    Widget icon;
    if (!hasAudio) {
      icon = const Icon(Icons.play_arrow);
    } else if (isLoading) {
      icon = const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (isPlaying) {
      icon = const Icon(Icons.pause);
    } else if (isPaused) {
      icon = const Icon(Icons.play_arrow);
    } else if (isError) {
      icon = const Icon(Icons.error);
    } else {
      icon = const Icon(Icons.play_arrow);
    }

    final playbackError = state.errorMessage != null
      ? formatFriendlyError(state.errorMessage, fallback: 'Playback failed. Tap to retry.')
      : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: icon,
              onPressed: hasAudio
                  ? () {
                      if (isCurrentRequest && isPlaying) {
                        notifier.pause();
                      } else if (isCurrentRequest && isPaused) {
                        notifier.resume();
                      } else {
                        notifier.play(requestId, audioUrls);
                      }
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: hasAudio && isCurrentRequest && state.status != AudioPlaybackStatus.idle
                  ? () => notifier.stop()
                  : null,
            ),
            Expanded(
              child: LinearProgressIndicator(value: overallProgress),
            ),
            const SizedBox(width: 8),
            Text('$percentLabel%'),
          ],
        ),
        if (state.totalSegments > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
            child: Text(
              'Segment ${state.currentSegment}/${state.totalSegments}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        if (playbackError != null && isCurrentRequest)
          Text(playbackError, style: const TextStyle(color: Colors.redAccent)),
      ],
    );
  }
}
