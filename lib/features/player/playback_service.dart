import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../vault/track.dart';

/// Central playback engine. Wraps a single [AudioPlayer], tracks the queue
/// context (vault list or room queue order) and auto-advances on completion.
class PlaybackService {
  PlaybackService() {
    _processingSub = _player.processingStateStream.listen(_onProcessingState);
  }

  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<ProcessingState> _processingSub;

  /// Track the user tapped / room is playing. Null when idle.
  final ValueNotifier<Track?> currentTrack = ValueNotifier(null);

  /// Ordered context used for skip next/previous (e.g. the vault list).
  final ValueNotifier<List<Track>> contextQueue = ValueNotifier(const []);

  /// True while a scheduled (synchronized) start is pending.
  bool scheduledStartPending = false;

  /// Set false when a room is driving the queue (the room repository owns
  /// auto-advance); true for vault-only listening sessions.
  bool autoAdvanceFromContext = true;

  final StreamController<Track> _completedController =
      StreamController<Track>.broadcast();

  /// Emits when a track reaches its end — rooms use this to auto-advance.
  Stream<Track> get trackCompleted => _completedController.stream;

  AudioPlayer get player => _player;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<double> get speedStream => _player.speedStream;

  Future<void> playTrack(Track track, {List<Track>? context}) async {
    currentTrack.value = track;
    if (context != null) contextQueue.value = List.of(context);
    try {
      await _player.setFilePath(track.filePath);
      await _player.setSpeed(1.0);
      await _player.play();
    } catch (e) {
      debugPrint('Playback failed for ${track.title}: $e');
    }
  }

  /// Sets the source and seeks to [position] without starting playback.
  Future<void> prepare(Track track, Duration position) async {
    currentTrack.value = track;
    try {
      await _player.setFilePath(track.filePath);
      await _player.setSpeed(1.0);
      await _player.seek(position);
    } catch (e) {
      debugPrint('Playback prepare failed for ${track.title}: $e');
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  Future<void> toggle() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  int get _currentIndex {
    final current = currentTrack.value;
    if (current == null) return -1;
    return contextQueue.value.indexWhere((t) => t.id == current.id);
  }

  Future<void> skipNext({bool auto = false}) async {
    final queue = contextQueue.value;
    final index = _currentIndex;
    if (index >= 0 && index < queue.length - 1) {
      await playTrack(queue[index + 1]);
    } else if (auto && index >= 0 && index == queue.length - 1 && queue.isNotEmpty) {
      // End of context: stop cleanly.
      await _player.stop();
      currentTrack.value = null;
    }
  }

  Future<void> skipPrevious() async {
    // Standard behavior: restart the track if we're past 3 seconds.
    if (_player.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    final queue = contextQueue.value;
    final index = _currentIndex;
    if (index > 0) {
      await playTrack(queue[index - 1]);
    } else {
      await seek(Duration.zero);
    }
  }

  void _onProcessingState(ProcessingState state) {
    if (state == ProcessingState.completed) {
      final finished = currentTrack.value;
      if (finished != null) _completedController.add(finished);
      if (autoAdvanceFromContext) {
        // Vault listening session: advance within the tapped list context.
        skipNext(auto: true);
      }
    }
  }

  Future<void> dispose() async {
    await _processingSub.cancel();
    await _completedController.close();
    await _player.dispose();
  }
}
