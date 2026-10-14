/// Core Application Constants for SynchroBeat
class AppConstants {
  static const String appName = 'SynchroBeat';
  static const String appVersion = '1.0.0';

  // Supabase Configuration (Populate via environment variables or .env)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'placeholder-anon-key',
  );

  // Cloudflare R2 Public CDN / Custom Domain Base URL (Zero Egress)
  static const String r2PublicBaseUrl = String.fromEnvironment(
    'R2_PUBLIC_BASE_URL',
    defaultValue: 'https://audio.synchrobeat.app',
  );

  // Sync Parameters (SRS Section 3.4 & PRD Section 5)
  static const int syncPingIntervalSec = 60;
  static const int syncDriftCheckIntervalSec = 3;
  static const int scheduleDelayMs = 500;
  static const int tier1DriftThresholdMs = 100;
  static const int tier2DriftThresholdMs = 350;
  static const double rateWarpFast = 1.05;
  static const double rateWarpSlow = 0.95;

  // Vault Limits (SRS REQ-VLT-01)
  static const int maxFileSizeBytes = 100 * 1024 * 1024; // 100 MB
  static const List<String> supportedAudioExtensions = [
    'mp3',
    'm4a',
    'wav',
    'flac',
  ];

  // Room Bounds (SRS REQ-ROM-05)
  static const int maxRoomCapacity = 10;
  static const int recommendedRoomCapacity = 5;
  static const int roomCodeLength = 6;
  static const String deepLinkHost = 'synchrobeat.app';
}
