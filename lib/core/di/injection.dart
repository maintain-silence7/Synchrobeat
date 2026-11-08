import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_client.dart';
import '../../features/auth/auth_bloc.dart';
import '../../features/auth/auth_repository.dart';
import '../../features/player/playback_service.dart';
import '../../features/room/local_room_repository.dart';
import '../../features/sync/sync_playback_controller.dart';
import '../../features/sync/time_sync_service.dart';
import '../../features/vault/demo_seeder.dart';
import '../../features/vault/local_track_repository.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ── External services ─────────────────────────────────────────────
  sl.registerLazySingleton<SupabaseClient>(() => SupabaseService.client);
  sl.registerLazySingleton<Dio>(() => Dio());
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(
      // v10+: Android uses Keystore-backed AES-GCM ciphers by default and
      // auto-migrates any legacy EncryptedSharedPreferences data.
      aOptions: AndroidOptions(),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );

  // ── Auth ──────────────────────────────────────────────────────────
  sl.registerLazySingleton<AuthRepository>(
    () => LocalAuthRepository(sl<FlutterSecureStorage>()),
  );
  sl.registerLazySingleton<AuthBloc>(
    () => AuthBloc(sl<AuthRepository>())..add(const AppStarted()),
  );

  // ── Vault (communal audio library) ────────────────────────────────
  sl.registerLazySingleton<LocalTrackRepository>(() => LocalTrackRepository());

  // ── Playback + sync engine ────────────────────────────────────────
  sl.registerLazySingleton<PlaybackService>(() => PlaybackService());
  sl.registerLazySingleton<TimeSyncService>(() => TimeSyncService());
  sl.registerLazySingleton<SyncPlaybackController>(
    () => SyncPlaybackController(
      sl<PlaybackService>().player,
      sl<TimeSyncService>(),
    ),
  );

  // ── Rooms ─────────────────────────────────────────────────────────
  sl.registerLazySingleton<LocalRoomRepository>(
    () => LocalRoomRepository(
      sl<PlaybackService>(),
      sl<TimeSyncService>(),
      sl<SyncPlaybackController>(),
    ),
  );

  // ── Demo content ──────────────────────────────────────────────────
  sl.registerLazySingleton<DemoSeeder>(
    () => DemoSeeder(sl<LocalTrackRepository>()),
  );
}

/// Seeds the offline demo vault and primes the clock-skew estimator.
/// Safe to call in tests/unsupported environments (failures are swallowed).
Future<void> bootstrapDemoMode() async {
  try {
    final seeder = sl<DemoSeeder>();
    await seeder.seedIfEmpty();
  } catch (e) {
    debugPrint('Demo seed skipped: $e');
  }
  try {
    final sync = sl<TimeSyncService>();
    await sync.performHandshake();
    sync.startPeriodicResync();
  } catch (e) {
    debugPrint('Time sync priming skipped: $e');
  }
}
