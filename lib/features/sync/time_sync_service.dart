import 'dart:async';

import 'package:flutter/foundation.dart';

/// NTP-style clock skew estimation.
///
/// Each ping exchange yields:
///   Δt = ((t₁ - t₀) + (t₂ - t₃)) / 2
/// where t₀/t₃ are local send/receive times and t₁/t₂ are the server's
/// receive/send timestamps. A moving average over the last [_window] pings
/// filters network jitter.
///
/// In offline/demo mode there is no remote server, so the handshake resolves
/// to ~0ms skew (loopback). When a Supabase RPC endpoint is configured, the
/// transport can be swapped in without changing this math.
class TimeSyncService extends ChangeNotifier {
  static const int _window = 5;

  final List<int> _offsets = [];
  int _currentOffsetMs = 0;
  Timer? _resyncTimer;

  static int offsetFromRoundTrip(int t0, int t1, int t2, int t3) =>
      ((t1 - t0) + (t2 - t3)) ~/ 2;

  int get currentOffsetMs => _currentOffsetMs;

  /// Server-aligned estimate of "now".
  DateTime get estimatedServerTime =>
      DateTime.now().add(Duration(milliseconds: _currentOffsetMs));

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  /// Records one ping sample and recomputes the moving average.
  void recordSample(int t0, int t1, int t2, int t3) {
    _pushOffset(offsetFromRoundTrip(t0, t1, t2, t3));
  }

  void recordOffset(int offsetMs) => _pushOffset(offsetMs);

  void _pushOffset(int offsetMs) {
    _offsets.add(offsetMs);
    if (_offsets.length > _window) _offsets.removeAt(0);
    final avg = _offsets.reduce((a, b) => a + b) / _offsets.length;
    _currentOffsetMs = avg.round();
    notifyListeners();
  }

  /// Performs the 3-way handshake [pings] times. In demo mode the "server"
  /// is the loopback clock, so offsets converge to ~0 with a tiny synthetic
  /// jitter to exercise the averaging path.
  Future<void> performHandshake({int pings = _window}) async {
    for (var i = 0; i < pings; i++) {
      final t0 = _nowMs;
      // Simulated round trip (16–40ms) around a zero true offset.
      final outbound = 8 + (i * 7 % 17);
      final returnDelay = 8 + (i * 11 % 21);
      await Future<void>.delayed(Duration(milliseconds: outbound + returnDelay));
      final t1 = t0 + outbound;
      final t2 = t1;
      final t3 = t0 + outbound + returnDelay;
      recordSample(t0, t1, t2, t3);
    }
  }

  /// SRS §3.4: recurring sync to keep the skew estimate fresh.
  void startPeriodicResync({int intervalSeconds = 60}) {
    _resyncTimer?.cancel();
    _resyncTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      performHandshake();
    });
  }

  void stopPeriodicResync() {
    _resyncTimer?.cancel();
    _resyncTimer = null;
  }

  @override
  void dispose() {
    stopPeriodicResync();
    super.dispose();
  }
}
