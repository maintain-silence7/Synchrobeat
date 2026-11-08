import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
import 'core/network/supabase_client.dart';
import 'features/player/audio_handler.dart';
import 'features/player/playback_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock status bar and navigation bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0F12),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize backend (skipped when placeholder keys are in use).
  final hasSupabaseConfig =
      !AppConstants.supabaseUrl.contains('placeholder') &&
      !AppConstants.supabaseAnonKey.contains('placeholder');
  if (hasSupabaseConfig) {
    try {
      await SupabaseService.initialize();
    } catch (e) {
      debugPrint('Supabase init failed, continuing offline: $e');
    }
  } else {
    debugPrint('Supabase keys not set, running in offline demo mode.');
  }

  // Initialize dependencies
  await initDependencies();

  // Seed the starter vault + prime the clock-skew estimator (no-op on failure)
  await bootstrapDemoMode();

  // Background audio (Android/iOS/macOS only; other platforms use just_audio)
  if (isAudioServicePlatform) {
    await initAudioService(sl<PlaybackService>());
  }

  runApp(const SynchroBeatApp());
}
