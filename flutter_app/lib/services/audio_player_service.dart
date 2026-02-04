import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayerService() {
    _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> play(String url) async {
    await _player.play(UrlSource(url));
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.resume();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  Stream<Duration?> get onDurationChanged => _player.onDurationChanged;

  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;
}
