import 'package:flutter_test/flutter_test.dart';
import 'package:synchrobeat_app/core/constants/app_constants.dart';
import 'package:synchrobeat_app/features/sync/sync_playback_controller.dart';
import 'package:synchrobeat_app/features/sync/time_sync_service.dart';

void main() {
  group('TimeSyncService.offsetFromRoundTrip', () {
    test('zero offset when server clock equals client clock', () {
      // t0 = 1000, outbound 10ms, return 10ms, server processing instant.
      const t0 = 1000, t1 = 1010, t2 = 1010, t3 = 1020;
      expect(TimeSyncService.offsetFromRoundTrip(t0, t1, t2, t3), 0);
    });

    test('server 250ms ahead of client', () {
      // True offset +250: server stamps are client + 250.
      const t0 = 1000, t1 = 1260, t2 = 1260, t3 = 1020;
      expect(TimeSyncService.offsetFromRoundTrip(t0, t1, t2, t3), 250);
    });

    test('server 180ms behind client', () {
      const t0 = 1000, t1 = 830, t2 = 830, t3 = 1020;
      expect(TimeSyncService.offsetFromRoundTrip(t0, t1, t2, t3), -180);
    });

    test('moving average converges within the window', () {
      final sync = TimeSyncService();
      // Feed five samples all claiming +100ms.
      for (var i = 0; i < 5; i++) {
        sync.recordOffset(100);
      }
      expect(sync.currentOffsetMs, 100);
      sync.dispose();
    });
  });

  group('SyncPlaybackController.classifyDrift', () {
    test('under tier 1 → no action', () {
      expect(SyncPlaybackController.classifyDrift(0), DriftAction.none);
      expect(
        SyncPlaybackController.classifyDrift(
          AppConstants.tier1DriftThresholdMs - 1,
        ),
        DriftAction.none,
      );
      expect(
        SyncPlaybackController.classifyDrift(
          -(AppConstants.tier1DriftThresholdMs - 1),
        ),
        DriftAction.none,
      );
    });

    test('tier 1–2 band → rate warp in the correct direction', () {
      // Client ahead (positive drift) → slow down.
      expect(SyncPlaybackController.classifyDrift(150), DriftAction.warpSlower);
      // Client behind (negative drift) → speed up.
      expect(SyncPlaybackController.classifyDrift(-150), DriftAction.warpFaster);
      expect(
        SyncPlaybackController.classifyDrift(AppConstants.tier2DriftThresholdMs),
        DriftAction.warpSlower,
      );
    });

    test('beyond tier 2 → hard seek', () {
      expect(
        SyncPlaybackController.classifyDrift(
          AppConstants.tier2DriftThresholdMs + 1,
        ),
        DriftAction.hardSeek,
      );
      expect(SyncPlaybackController.classifyDrift(-2000), DriftAction.hardSeek);
    });

    test('warp rates match the spec constants', () {
      expect(SyncPlaybackController.rateFor(DriftAction.warpFaster),
          AppConstants.rateWarpFast);
      expect(SyncPlaybackController.rateFor(DriftAction.warpSlower),
          AppConstants.rateWarpSlow);
      expect(SyncPlaybackController.rateFor(DriftAction.none), 1.0);
    });
  });
}
