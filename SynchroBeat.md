```markdown
# SynchroBeat (Flutter Edition)

## 1. Document Control & Overview
* **Document Version:** 1.0.0
* **Target Audience:** Engineering, Product, UI/UX
* **Core Technology Stack:** Flutter (Multi-platform: iOS, Android, Web), Supabase, WebSockets

---

## 2. Product Summary & Problem Statement
Listening to music with friends remotely typically requires paid subscriptions (e.g., Spotify Premium for Spotify Jam) or screen-sharing audio with heavy compression and lag (e.g., Discord).

**SynchroBeat** solves this by providing a lightweight, cross-platform audio player built in **Flutter**. It allows small groups (4–5 friends) to upload their own audio files to a shared vault and listen together simultaneously with near-zero latency drift across iOS, Android, and modern Web browsers.

---

## 3. User Personas & Use Cases

### 3.1 Primary Personas
* **The Curator:** The friend with a large local collection of unreleased tracks, bootlegs, mixtapes, or high-res audio files who wants to share and listen together.
* **The Remote Group:** Friends who study, work, or hang out in voice chats and want a synchronized background soundtrack without platform lock-in.

### 3.2 Target Group Metrics
* **Concurrent Room Size:** 4 to 5 users (hard limit of 10 users to maintain low-latency sync).
* **Network Target:** Broadband, 4G, and standard 5G connections.

---

## 4. System Architecture & Tech Stack


```

┌────────────────────────────────────────────────────────┐
│                   Flutter Client App                   │
│   (iOS / Android via just_audio + audio_service, Web)   │
└─────────────┬───────────────────────────┬──────────────┘
│                           │
Direct Audio Buffer (CDN)       WebSocket Sync Events
│                           │
▼                           ▼
┌───────────────────────────┐   ┌────────────────────────┐
│   Cloudflare R2 Bucket    │   │  Supabase / Node.js    │
│ (Zero-egress Object Store)│   │  - PostgreSQL DB       │
└───────────────────────────┘   │  - Realtime Channels   │
│  - Auth (OAuth/Email)  │
└────────────────────────┘

```

### 4.1 Client Layer (Flutter)
* **Framework:** Flutter SDK (Stable 3.x+) targeting iOS, Android, and Web.
* **State Management:** `flutter_bloc` or `riverpod` for predictable state synchronization.
* **Audio Engine:** `just_audio` (multi-platform playback engine with streaming and caching capabilities).
* **Background Audio Controls:** `audio_service` (Android lock screen, iOS Control Center, and media key notifications).
* **File Picker & Metadata Extraction:** `file_picker` + `audiotags` (or edge-based ID3 tag parser).

### 4.2 Backend & Storage Layer
* **Database & Auth:** **Supabase** (PostgreSQL, Row Level Security, and Realtime WebSocket Broadcast).
* **Audio Object Storage:** **Cloudflare R2** (S3-compatible API, selected specifically for **zero egress bandwidth fees** when streaming large media files).

---

## 5. Synchronization & Playback Protocol

To avoid bandwidth congestion and quality degradation, audio is **never** streamed peer-to-peer. All clients stream directly from storage; only **control state** and **timestamps** are synchronized.

### 5.1 Clock Synchronization (NTP-Style Handshake)
1. Upon entering a room, each client performs a 3-way ping-pong handshake with the server to compute the round-trip time ($RTT$) and determine client-to-server clock skew ($\Delta t$):
   $$\text{Offset} = \frac{(t_1 - t_0) + (t_2 - t_3)}{2}$$
2. The client calculates the true global timestamp:
   $$\text{ServerTime} = \text{ClientTime} + \text{Offset}$$

### 5.2 Scheduled Playback Trigger
When the host taps "Play":
1. The host sends an intent to the server: `{ action: "PLAY", track_id: "xyz", track_pos: 12.4 }`.
2. The server broadcasts a scheduled execution event to all room participants:
   ```json
   {
     "event": "PLAY_SCHEDULED",
     "track_id": "xyz",
     "start_position_ms": 12400,
     "trigger_at_server_time_ms": 1735689600500
   }

```

3. Each client computes:

$$\text{Delay} = \text{trigger\_at\_server\_time} - \text{CurrentEstimatedServerTime}$$


4. Clients fire `just_audio.play()` exactly at the coordinated timestamp, ensuring simultaneous playback within a $\pm 50\text{ ms}$ threshold.

### 5.3 Dynamic Drift Correction

* Every 3 seconds, listeners check their local track position against the host's broadcast position.
* **Drift $< 100\text{ ms}$:** No action (unnoticeable drift).
* **Drift between $100\text{ ms}$ and $350\text{ ms}$:** Subtly alter playback rate (`playbackRate = 1.05` or `0.95`) for 2 seconds to close the gap without hard audio clicks.
* **Drift $> 350\text{ ms}$:** Hard seek directly to the current synchronized position.

---

## 6. Functional Requirements

### 6.1 Authentication & Room Management

* **FR-01 (Sign In):** Users can register and sign in via Email/Password or Google Sign-In.
* **FR-02 (Create Room):** Authenticated users can create a listening room. The server generates a unique 6-character alphanumeric code and a shareable deep link.
* **FR-03 (Join Room):** Users can join an active room by typing the 6-character code or tapping the deep link.
* **FR-04 (Host Assignment):** The room creator is assigned the "Host" role by default. If the host leaves, the system automatically promotes the next active participant.
* **FR-05 (DJ Handover):** The active host can voluntarily pass the "Host" controller role to any connected room participant.

### 6.2 Communal Audio Vault (Upload & Library)

* **FR-06 (Supported Formats):** Client accepts `.mp3`, `.m4a`, `.wav`, and `.flac` up to 100 MB per file.
* **FR-07 (Metadata Extraction):** The app parses ID3 tags (Track Title, Artist, Album, Duration, and Album Artwork) upon selection. If metadata is missing, it falls back to the raw filename.
* **FR-08 (Direct-to-R2 Upload):** The Flutter client requests a pre-signed PUT URL from the backend and uploads the audio file directly to Cloudflare R2, tracking progress via an upload bar.
* **FR-09 (Communal Library UI):** All uploaded tracks are visible in a searchable, sortable group library list.

### 6.3 Synchronized Audio Player

* **FR-10 (Host Commands):** Only the active host can execute `PLAY`, `PAUSE`, and `SEEK`. Actions broadcast to all connected clients in $< 100\text{ ms}$.
* **FR-11 (Pre-Buffering):** Clients automatically fetch and buffer the next 30 seconds of the active track, as well as the next track in the queue.
* **FR-12 (Collaborative Queue):** Any user in the room can append songs from the Vault to the shared queue or reorder items.
* **FR-13 (Background Playback):**
* **Android:** Foreground service notification with media playback controls (Previous, Play/Pause, Next, Scrubber).
* **iOS:** Native `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` integration.
* **Web:** Native Media Session API support.



### 6.4 Social & Lightweight Interaction

* **FR-14 (Realtime Presence):** Visual avatars displaying the 4–5 listeners currently connected to the room.
* **FR-15 (Emoji Reactions):** Floating ephemeral reactions (🔥, 💃, 🎧, 💔) broadcast via WebSockets, animating over the album art for all connected listeners.

---

## 7. Non-Functional Requirements

* **Performance:** Flutter app must maintain a smooth 60 FPS on mid-range Android devices and 120 FPS on ProMotion iOS displays during UI animations.
* **Latency Drift:** Total audio desynchronization across all room participants must remain $\le 100\text{ ms}$ under stable network conditions.
* **Reliability:** Auto-reconnect WebSockets if a user temporarily switches Wi-Fi networks or passes through mobile dead zones, seamlessly re-aligning playback.
* **Data Efficiency:** Cloudflare R2 bandwidth usage must incur zero egress fees. Tracks are aggressively cached locally on mobile storage using `just_audio_cache` where appropriate.

---

## 8. Database Schema (PostgreSQL)

```sql
-- 1. Profiles Table
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Tracks Table (Communal Vault)
CREATE TABLE public.tracks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uploader_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    artist TEXT DEFAULT 'Unknown Artist',
    album TEXT DEFAULT 'Unknown Album',
    duration_seconds INT NOT NULL,
    storage_path TEXT NOT NULL,
    cover_art_url TEXT,
    file_size_bytes BIGINT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Rooms Table
CREATE TABLE public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_code VARCHAR(6) UNIQUE NOT NULL,
    host_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    current_track_id UUID REFERENCES public.tracks(id) ON DELETE SET NULL,
    is_playing BOOLEAN DEFAULT false,
    playhead_position_ms INT DEFAULT 0,
    server_sync_timestamp TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Queue Table
CREATE TABLE public.room_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
    track_id UUID REFERENCES public.tracks(id) ON DELETE CASCADE,
    added_by UUID REFERENCES public.profiles(id),
    position INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

```

---

## 9. Implementation Roadmap & Milestones

| Milestone | Deliverables | Key Flutter Packages |
| --- | --- | --- |
| **Phase 1: Shell & Auth** | Flutter project setup (iOS, Android, Web), Supabase Auth integration, profile setup, base responsive navigation. | `supabase_flutter`, `go_router`, `flutter_bloc` |
| **Phase 2: Vault & Cloud Storage** | File picker, ID3 parser, direct upload to Cloudflare R2 with signed URLs, track catalog UI. | `file_picker`, `audiotags`, `dio` |
| **Phase 3: Native Audio Engine** | Local and remote streaming audio setup, background audio handling, lock-screen notification controls. | `just_audio`, `audio_service` |
| **Phase 4: Sync & Room Engine** | Room creation via 6-digit codes, Supabase Realtime channel setup, NTP clock synchronization logic, drift catch-up. | `web_socket_channel`, custom NTP service |
| **Phase 5: Collaborative Queue & Polish** | Shared queue management, drag-to-reorder, live emoji reactions, UI animations, end-to-end testing. | `reorderables`, `flutter_animate` |

```

```