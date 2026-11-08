# SynchroBeat

SynchroBeat — Multi-Platform Synchronized Group Audio Streaming.
Flutter client for Android, iOS, Windows, Linux and Web backed by Supabase
(PostgreSQL, Auth, Realtime), Cloudflare R2 and `just_audio`.

> Current state: **offline demo mode**. The app runs fully on-device with a
> seeded starter vault, local auth and the full sync engine (unit-tested).
> Cloud sync/uploads activate when Supabase/R2 credentials are provided.

## Quick start

```bash
flutter pub get
flutter run -d windows   # or -d chrome / -d <android-device>
```

Sign in with the seeded demo account (also one tap on the login screen):

```
demo@synchrobeat.app / demo1234
```

On first launch the app synthesizes three starter tracks into your Communal
Vault (no copyrighted material) and primes the NTP-style clock-skew estimator.

## What works today

- Email/password auth with secure session persistence + profile/avatar editing
- Vault: browse/search/sort tracks, upload your own (MP3/M4A/WAV/FLAC ≤ 100 MB)
  with ID3 metadata + cover art extraction, delete your own uploads
- Playback: mini player docked above navigation, full-screen player with scrubber,
  lock-screen handler for Android/iOS (`audio_service`)
- Rooms: create/join 6-character code rooms, deep link `/join/:code`,
  shared reorderable queue, tap-to-play, host handover on leave
- Sync engine: moving-average clock-offset estimation, 60s resync, 3s drift
  monitor with 100 ms / 350 ms correction tiers (unit-tested)
- Presence avatars with DJ badge, host transfer, ephemeral emoji reactions

## Enabling the real backend

1. Create the Supabase project and run `supabase/migrations/20261014_init_schema_and_rls.sql`.
2. Deploy the edge function `supabase/functions/get-upload-url` and set the R2 credentials as function secrets.
3. Launch with real values:

```bash
flutter run --dart-define=SUPABASE_URL=https://<project>.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=<anon-key> \
            --dart-define=R2_PUBLIC_BASE_URL=https://audio.synchrobeat.app
```

4. Replace `LocalAuthRepository` / `LocalTrackRepository` / `LocalRoomRepository`
   with Supabase-backed implementations (registries are centralized in
   `lib/core/di/injection.dart`).
