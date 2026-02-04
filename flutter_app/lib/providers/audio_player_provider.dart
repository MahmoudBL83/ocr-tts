import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio_player_service.dart';

enum AudioPlaybackStatus { idle, loading, playing, paused, error }

class AudioPlayerState {
  final String? requestId;
  final AudioPlaybackStatus status;
  final Duration position;
  final Duration duration;
  final String? errorMessage;
  final int currentSegment;
  final int totalSegments;

  const AudioPlayerState({
    this.requestId,
    this.status = AudioPlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
    this.currentSegment = 0,
    this.totalSegments = 0,
  });

  AudioPlayerState copyWith({
    String? requestId,
    AudioPlaybackStatus? status,
    Duration? position,
    Duration? duration,
    String? errorMessage,
    int? currentSegment,
    int? totalSegments,
  }) {
    return AudioPlayerState(
      requestId: requestId ?? this.requestId,
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: errorMessage ?? this.errorMessage,
      currentSegment: currentSegment ?? this.currentSegment,
      totalSegments: totalSegments ?? this.totalSegments,
    );
  }
}

class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  final AudioPlayerService _service;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  final List<String> _queue = [];
  int _currentIndex = 0;
  bool _intentionalStop = false;

  AudioPlayerNotifier([AudioPlayerService? service])
      : _service = service ?? AudioPlayerService(),
        super(const AudioPlayerState()) {
    _stateSub = _service.onPlayerStateChanged.listen(_onPlayerStateChanged);
    _positionSub = _service.onPositionChanged.listen(_onPositionChanged);
    _durationSub = _service.onDurationChanged.listen(_onDurationChanged);
  }

  void _onPlayerStateChanged(PlayerState playerState) {
    if (_queue.isEmpty) return;
    if (playerState == PlayerState.completed) {
      if (_intentionalStop) return;
      if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
        state = state.copyWith(
          currentSegment: _currentIndex + 1,
          status: AudioPlaybackStatus.loading,
          position: Duration.zero,
          duration: Duration.zero,
        );
        _startCurrentSegment();
      } else {
        _clearQueue();
      }
    } else if (playerState == PlayerState.playing) {
      state = state.copyWith(status: AudioPlaybackStatus.playing);
    } else if (playerState == PlayerState.paused) {
      state = state.copyWith(status: AudioPlaybackStatus.paused);
    } else if (playerState == PlayerState.stopped) {
      if (!_intentionalStop) {
        _clearQueue();
      }
    }
  }

  void _onPositionChanged(Duration position) {
    state = state.copyWith(position: position);
  }

  void _onDurationChanged(Duration? duration) {
    if (duration != null) {
      state = state.copyWith(duration: duration);
    }
  }

  Future<void> _startCurrentSegment() async {
    if (_queue.isEmpty || _currentIndex >= _queue.length) return;
    final url = _queue[_currentIndex];
    try {
      await _service.play(url);
    } catch (error) {
      state = state.copyWith(status: AudioPlaybackStatus.error, errorMessage: error.toString());
      _clearQueue();
    }
  }

  void _clearQueue() {
    state = state.copyWith(
      status: AudioPlaybackStatus.idle,
      requestId: null,
      position: Duration.zero,
      duration: Duration.zero,
      currentSegment: 0,
      totalSegments: 0,
      errorMessage: null,
    );
    _queue.clear();
    _currentIndex = 0;
    _intentionalStop = false;
  }

  Future<void> play(String requestId, List<String> urls) async {
    if (urls.isEmpty) return;
    _queue
      ..clear()
      ..addAll(urls);
    _currentIndex = 0;
    _intentionalStop = false;
    state = state.copyWith(
      status: AudioPlaybackStatus.loading,
      requestId: requestId,
      currentSegment: 1,
      totalSegments: urls.length,
      position: Duration.zero,
      duration: Duration.zero,
      errorMessage: null,
    );
    _startCurrentSegment();
  }

  Future<void> pause() async {
    if (state.status != AudioPlaybackStatus.playing) return;
    await _service.pause();
    state = state.copyWith(status: AudioPlaybackStatus.paused);
  }

  Future<void> stop() async {
    _intentionalStop = true;
    await _service.stop();
    _clearQueue();
  }

  Future<void> resume() async {
    if (state.status != AudioPlaybackStatus.paused) return;
    try {
      await _service.resume();
      state = state.copyWith(status: AudioPlaybackStatus.playing);
    } catch (error) {
      state = state.copyWith(status: AudioPlaybackStatus.error, errorMessage: error.toString());
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }
}

final audioPlayerProvider = StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  (ref) => AudioPlayerNotifier(),
);
