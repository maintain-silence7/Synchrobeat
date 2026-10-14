```markdown
# Engineering Task Breakdown: SynchroBeat (Flutter Edition)

**Project:** SynchroBeat — Cross-Platform Synchronized Group Audio Streaming  
**Target Clients:** iOS, Android, Web  
**Primary Tech Stack:** Flutter, Supabase (PostgreSQL, Auth, Realtime), Cloudflare R2, `just_audio`, `audio_service`  
**Tracking Notation:** `[ ]` Open, `[x]` Completed, `[P]` In Progress

---

## Phase 1: Environment Setup, Architecture & Database Foundation

### 1.1 Project Initialization & Cross-Platform Config
- [x] Initialize base Flutter project with target platforms enabled:
  ```bash
  flutter create --org com.synchrobeat --platforms=android,ios,web synchrobeat_app
  ```
- [x] Add core production dependencies to `pubspec.yaml`:
  * Architecture & State: `flutter_bloc`, `get_it`, `equatable`
  * Navigation: `go_router`
  * Backend/Auth/Storage: `supabase_flutter`, `dio`, `uuid`
  * Audio Engine: `just_audio`, `audio_service`, `just_audio_web`, `audio_session`
  * Native & Media: `file_picker`, `audiotags`, `flutter_secure_storage`
  * UI & Utilities: `cached_network_image`, `reorderables`, `flutter_animate`, `google_fonts`
- [x] Configure Android target:
  * Set `minSdkVersion = 21` (API 29 recommended target) and enable multidex in `android/app/build.gradle`.
  * Add native audio foreground service declarations in `AndroidManifest.xml`:
    * `android.permission.FOREGROUND_SERVICE`
    * `android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK`
    * `android.permission.WAKE_LOCK`
  * Configure `AudioServiceActivity`, `AudioService`, and `MediaButtonReceiver`.
- [x] Configure iOS target:
  * Enable background audio capability in `ios/Runner/Info.plist`:
    * `UIBackgroundModes` -> `audio`, `fetch`, `remote-notification`
  * Set target iOS deployment version to $\ge 15.0$ in `Podfile`.
  * Configure `AVAudioSessionCategoryPlayback` in `AppDelegate.swift`.
- [x] Configure Web target:
  * Add standard Web AudioContext auto-unlock listener and MediaSession bindings in `web/index.html`.
  * Add `manifest.json`.

### 1.2 Backend & Database Setup (Supabase)
- [x] Provision Supabase instance and run schema DDL (`supabase/migrations/20261014_init_schema_and_rls.sql`):
  * Table: `profiles`
  * Table: `tracks`
  * Table: `rooms`
  * Table: `room_queue`
- [x] Implement Row Level Security (RLS) policies:
  * Enable read access for authenticated users across active rooms and communal tracks.
  * Restrict track deletion to original `uploader_id`.
  * Restrict room playhead state mutations to the current `host_id`.
- [x] Enable Supabase Realtime replication on `rooms` and `room_queue` tables.
- [x] Set up Cloudflare R2 bucket with appropriate CORS policies (`supabase/r2-cors.json`) and Edge Function (`supabase/functions/get-upload-url/index.ts`) allowing presigned `PUT` and `GET` requests.

---

## Phase 2: Authentication & Communal Vault Pipeline

### 2.1 Authentication Flow

* [ ] Create `AuthRepository` implementing:
* Email/Password sign-up and sign-in.
* Google OAuth sign-in flow.
* Session restoration via secure token persistence.


* [ ] Build UI Screens:
* `LoginScreen` & `RegisterScreen` with input validation.
* `ProfileSetupScreen` (display name, default avatar selection).


* [ ] Implement `AuthBloc` / state machine to manage user session transitions in `GoRouter`.

### 2.2 Local File Picker & ID3 Extraction

* [ ] Implement `MediaIngestionService`:
* Integrate `file_picker` to filter for audio extensions: `.mp3`, `.m4a`, `.wav`, `.flac`.
* Add file-size check ensuring file is $\le 100\text{ MB}$.


* [ ] Implement client-side ID3 parser:
* Read title, artist, album, duration, and embedded cover art bytes using `audiotags`.
* Provide fallback logic: use raw file name if ID3 title is null; default artist to `"Unknown Artist"`.



### 2.3 Cloudflare R2 Upload Pipeline

* [ ] Build backend Edge Function / RPC endpoint to generate pre-signed S3/R2 `PUT` URLs.
* [ ] Implement `UploadRepository` via `Dio`:
* Upload audio binary via `PUT` with stream progress callbacks (`onSendProgress`).
* Optional: Upload extracted cover art image to an `/artworks` subfolder.


* [ ] Write committed track metadata to the Supabase `tracks` table upon completed upload.
* [ ] Build UI Screens:
* `VaultScreen`: Paginated list of group tracks with search, sorting, and uploader tags.
* `UploadModal`: File selection dialog, upload progress bar, and metadata editor.



---

## Phase 3: Native Audio Engine & Background Service

### 3.1 Audio Subsystem Configuration

* [ ] Implement `AudioPlayerHandler` subclassing `BaseAudioHandler` from `audio_service`:
* Wrap internal instance of `just_audio.AudioPlayer`.
* Map `PlaybackState` events (Playing, Paused, Buffering, Position, Speed).
* Map `MediaItem` metadata (Title, Artist, Album, Art URI, Duration).


* [ ] Implement lock-screen and notification controls:
* Android notification with `MediaStyle` notification action buttons (Play, Pause, Skip, Scrubber).
* iOS `MPNowPlayingInfoCenter` updates and `MPRemoteCommandCenter` action handlers.
* Web `navigator.mediaSession` metadata actions.



### 3.2 Basic Playback UI

* [ ] Build `MiniPlayer` widget (docked bottom sheet showing track title, play/pause toggle, and mini progress bar).
* [ ] Build `FullPlayerModal`:
* Full-resolution album art display.
* Real-time scrubber slider with elapsed and remaining time labels.
* Play, Pause, Previous, Next buttons.
* Active audio route indicator (Headphones / Bluetooth / Speaker).



---

## Phase 4: Room Orchestration & Real-Time Sync Engine

### 4.1 Room Creation & Join Management

* [ ] Implement room lifecycle RPCs:
* Generate unique 6-character alphanumeric room codes (`room_code`).
* Validate connection capacity (enforce hard limit: max 10 concurrent participants).
* Dynamic host handover if active host ungracefully leaves room.


* [ ] Build UI Screens:
* `CreateRoomScreen` (displays code, copies shareable deep link `https://synchrobeat.app/join/XXXXXX`).
* `JoinRoomScreen` (6-character code input field with auto-submit).


* [ ] Integrate deep linking via `app_links` or standard Flutter engine deep link hooks.

### 4.2 Clock Skew Calibration Service (NTP-Style)

* [ ] Build client-side `TimeSyncService`:
* Execute a 3-way ping-pong handshake over WebSockets upon joining a room:

$$\Delta t = \frac{(t_1 - t_0) + (t_2 - t_3)}{2}$$


* Compute running moving average over 5 ping cycles to filter network jitter.
* Implement recurring 60-second background sync to prevent local clock drift.
* Expose helper method: `DateTime get estimatedServerTime`.



### 4.3 Real-Time State Transmission & Drift Correction

* [ ] Set up Supabase Realtime channel dedicated to the active `room_id`.
* [ ] Define event dispatchers & listeners:
* `PLAY_SCHEDULED`: Host broadcasts intent with `trigger_epoch_ms = CurrentServerTime + 500ms`.
* `PAUSE_IMMEDIATE`: Immediate stop triggered across all clients.
* `SEEK_SCHEDULED`: Repositions playhead and schedules coordinated restart.


* [ ] Implement `SyncPlaybackController`:
* Compute delay $\text{TargetTime} - \text{EstimatedServerTime}$; set precision timer to trigger `just_audio.play()`.
* Build periodic drift monitor (runs every 3 seconds during playback):
* $\vert{}\text{Drift}\vert{} < 100\text{ ms}$: Do nothing.
* $100\text{ ms} \le \vert{}\text{Drift}\vert{} \le 350\text{ ms}$: Temporarily adjust `playbackRate` to $1.05\times$ or $0.95\times$.
* $\vert{}\text{Drift}\vert{} > 350\text{ ms}$: Invoke atomic hard seek to current playhead.





---

## Phase 5: Collaborative Queue & Polish

### 5.1 Shared Queue Implementation

* [ ] Implement `QueueRepository`:
* Append track from Vault to room's queue (`room_queue` table).
* Reorder queue items by updating `position` index.
* Remove track from queue.


* [ ] Build `QueueDrawer` / `QueueScreen`:
* Reorderable list view using `reorderables` or Flutter's `ReorderableListView`.
* Live UI updates subscribed to `room_queue` PostgreSQL changes via Realtime channels.
* Automatic advance: schedule next track in queue when current song reaches terminal duration.



### 5.2 Social Features & Lightweight Interactions

* [ ] Implement Presence system:
* Display horizontal row of active participant avatars in the room.
* Visual badge differentiating the current `Host / DJ`.
* Context menu on participant avatar allowing Host to transfer the DJ role.


* [ ] Implement ephemeral floating emoji reactions:
* Tap-to-send emoji bar (🔥, 💃, 🎧, 💔).
* Broadcast ephemeral event through WebSocket broadcast channel (bypass DB persistence).
* Render animated floating icons overlaying the player screen using `flutter_animate`.



---

## Phase 6: QA, Performance Optimization & Deployment

### 6.1 Testing & Performance Hardening

* [ ] Run network latency benchmark tests:
* Simulate $150\text{ ms} - 300\text{ ms}$ ping variations using network throttling tools to verify drift correction.


* [ ] Verify audio lifecycle across OS power states:
* Android Doze mode and screen locks.
* iOS backgrounding and lock screen interruptions.
* Browser tab transitions and audio ducking during phone calls.


* [ ] Perform security review:
* Ensure Cloudflare R2 bucket credentials are not bundled in client binaries; verify pre-signed URL workflow.
* Validate PostgreSQL RLS policies against unauthorized playhead mutation tests.



### 6.2 Deployment & Release Configuration

* [ ] Android Release:
* Generate upload keystore and configure `key.properties`.
* Build release App Bundle: `flutter build appbundle`.


* [ ] iOS Release:
* Configure provisioning profiles and App IDs in Apple Developer portal.
* Build IPA: `flutter build ipa`.


* [ ] Web Release:
* Build optimized release: `flutter build web --wasm` (or standard CanvasKit/HTML renderers).
* Deploy web build to Cloudflare Pages or Vercel.



```

<FollowUp label="Want me to generate the full TimeSyncService Dart class for clock skew calculation?" query="Write the complete TimeSyncService Dart class for Flutter to handle NTP-style clock sync and drift calculation."/>

```