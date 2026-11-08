import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/constants/app_constants.dart';
import 'time_sync_service.dart';

enum DriftAction { none, warpFaster, warpSlower, hardSeek }

class SyncStatus {
  const SyncStatus({required this.driftMs, required this.action});
  final int driftMs;
  final DriftAction action;

  bool get locked => action == DriftAction.none;
}

/// Drift correction engine (SRS §3.4 / PRD §5).
///
/// During synchronized playback every client knows the epoch at which the
/// track started on the server ([scheduledStartEpoch]). The expected playhead
/// is `(estimatedServerTime - scheduledStartEpoch) + startPosition`. Every 3
/// seconds the actual playhead is compared against the expectation:
///
/// * |drift| < 100 ms        → do nothing
/// * 100–350 ms              → temporary 1.05× / 0.95× playback-rate warp
/// * |drift| > 350 ms        → atomic hard seek to the expected position
class SyncPlaybackController {
  SyncPlaybackController(this._player, this._timeSync);

  final AudioPlayer _player;
  final TimeSyncService _timeSync;

  Timer? _driftTimer;
  DateTime? _scheduledStartEpoch;
  Duration _startPosition = Duration.zero;

  final ValueNotifier<SyncStatus> status =
      ValueNotifier(const SyncStatus(driftMs: 0, action: DriftAction.none));

  static DriftAction classifyDrift(int driftMs) {
    final magnitude = driftMs.abs();
    if (magnitude < AppConstants.tier1DriftThresholdMs) {
      return DriftAction.none;
    }
    if (magnitude <= AppConstants.tier2DriftThresholdMs) {
      // Positive drift → client is ahead → slow down; negative → catch up.
      return driftMs > 0 ? DriftAction.warpSlower : DriftAction.warpFaster;
    }
    return DriftAction.hardSeek;
  }

  static double rateFor(DriftAction action) => switch (action) {
        DriftAction.warpFaster => AppConstants.rateWarpFast,
        DriftAction.warpSlower => AppConstants.rateWarpSlow,
        _ => 1.0,
      };

  Duration get expectedPlayhead {
    final start = _scheduledStartEpoch;
    if (start == null) return _startPosition;
    final elapsed = _timeSync.estimatedServerTime.difference(start);
    final position = _startPosition + elapsed;
    return position.isNegative ? Duration.zero : position;
  }

  /// Schedules playback to begin exactly [at] (server-aligned). Used for
  /// PLAY_SCHEDULED broadcasts: all clients call this with the same epoch
  /// and start within milliseconds of each other.
  Future<void> schedulePlay({
    required Duration fromPosition,
    DateTime? at,
    Duration leadTime = const Duration(
      milliseconds: AppConstants.scheduleDelayMs,
    ),
  }) async {
    final triggerEpoch = at ?? _timeSync.estimatedServerTime.add(leadTime);
    _scheduledStartEpoch = triggerEpoch;
    _startPosition = fromPosition;

    await _player.seek(fromPosition);
    await _player.setSpeed(1.0);

    final delay = triggerEpoch.difference(_timeSync.estimatedServerTime);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    await _player.play();
    startDriftMonitor();
  }

  void schedulePause() {
    stopDriftMonitor();
    _player.pause();
  }

  /// Re-anchors the expected playhead to [position] right now (used after a
  /// seek while playing) so the 3s drift monitor keeps measuring correctly.
  void reposition(Duration position) {
    _startPosition = position;
    _scheduledStartEpoch = _timeSync.estimatedServerTime;
  }

  void startDriftMonitor() {
    _driftTimer?.cancel();
    _driftTimer = Timer.periodic(
      const Duration(seconds: AppConstants.syncDriftCheckIntervalSec),
      (_) => _checkDrift(),
    );
  }

  void stopDriftMonitor() {
    _driftTimer?.cancel();
    _driftTimer = null;
    status.value = const SyncStatus(driftMs: 0, action: DriftAction.none);
    _player.setSpeed(1.0);
  }

  Future<void> _checkDrift() async {
    if (_scheduledStartEpoch == null || !_player.playing) return;
    final driftMs =
        _player.position.inMilliseconds - expectedPlayhead.inMilliseconds;
    final action = classifyDrift(driftMs);
    status.value = SyncStatus(driftMs: driftMs, action: action);

    switch (action) {
      case DriftAction.none:
        if (_player.speed != 1.0) await _player.setSpeed(1.0);
      case DriftAction.warpFaster:
      case DriftAction.warpSlower:
        final rate = rateFor(action);
        if (_player.speed != rate) await _player.setSpeed(rate);
      case DriftAction.hardSeek:
        await _player.setSpeed(1.0);
        await _player.seek(expectedPlayhead);
    }
  }

  void reset() {
    stopDriftMonitor();
    _scheduledStartEpoch = null;
    _startPosition = Duration.zero;
  }

  void dispose() {
    stopDriftMonitor();
    status.dispose();
  }
}
