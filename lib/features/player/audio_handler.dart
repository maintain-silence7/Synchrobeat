import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../vault/track.dart';
import 'playback_service.dart';

/// Lock-screen / notification bridge for Android & iOS (initialized only on
/// those platforms in main.dart; no-op elsewhere).
class AudioPlayerHandler extends BaseAudioHandler {
  AudioPlayerHandler(this._service) {
    final player = _service.player;
    _service.currentTrack.addListener(_publishMediaItem);
    player.playbackEventStream.listen((_) => _broadcastState());
    player.processingStateStream.listen((_) => _broadcastState());
    _publishMediaItem();
    _broadcastState();
  }

  final PlaybackService _service;

  AudioPlayer get _player => _service.player;

  void _publishMediaItem() {
    final Track? track = _service.currentTrack.value;
    mediaItem.add(track == null
        ? null
        : MediaItem(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration,
            artUri: track.artworkPath != null
                ? Uri.file(track.artworkPath!)
                : null,
          ));
  }

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _service.skipNext();

  @override
  Future<void> skipToPrevious() => _service.skipPrevious();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }
}

/// Configures the audio session for media playback and initializes the
/// background handler. Call only on Android / iOS / macOS.
Future<AudioPlayerHandler?> initAudioService(PlaybackService service) async {
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    return await AudioService.init(
      builder: () => AudioPlayerHandler(service),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.synchrobeat.audio',
        androidNotificationChannelName: 'SynchroBeat Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    debugPrint('audio_service unavailable on this platform: $e');
    return null;
  }
}

/// Web/desktop helper kept for parity: browsers rely on the OS media keys
/// via the audioplayers stack; nothing to register here.
bool get isAudioServicePlatform =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
