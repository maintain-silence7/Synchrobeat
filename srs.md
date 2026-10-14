```markdown
# Software Requirements Specification (SRS)
## Project: SynchroBeat — Multi-Platform Synchronized Group Audio Streaming
**Document Version:** 1.0.0  
**Status:** Draft / Approved for Engineering  
**Standard Compliance:** Adapted from IEEE Std 830-1998 / ISO/IEC/IEEE 29148:2018  

---

## 1. Introduction

### 1.1 Purpose
This document specifies the software requirements for **SynchroBeat**, a multi-platform client-server application built with the **Flutter** framework. It details the operational, functional, interface, and non-functional requirements necessary to implement real-time, low-latency synchronized audio streaming and self-hosted file management for small private groups (4–5 concurrent listeners).

### 1.2 Scope
SynchroBeat delivers:
* User registration and profile management.
* A shared Communal Audio Vault facilitating client-side ID3 parsing and direct-to-cloud file uploads (Cloudflare R2).
* Ephemeral listening rooms managed via 6-character access tokens and deep links.
* A low-latency state synchronization engine using Network Time Protocol (NTP)–style clock skew estimation over WebSockets.
* Native background audio playback on iOS, Android, and Web platforms.
* A real-time collaborative track queue and presence tracking system.

The system does **not** handle peer-to-peer raw audio bitstream relaying, copyrighted media catalog licensing (e.g., Spotify, Apple Music APIs), or public broadcasting channels exceeding 10 concurrent listeners per room.

### 1.3 Definitions, Acronyms, and Abbreviations
* **API:** Application Programming Interface
* **CDN:** Content Delivery Network
* **Clock Drift:** The discrepancy where two independent hardware clocks tick at subtly different frequencies.
* **Clock Skew ($\Delta t$):** The absolute difference in readings between client system time and server system time.
* **ID3:** Metadata container format embedded within MP3/audio files storing track title, artist, album, and artwork.
* **NTP:** Network Time Protocol.
* **PRD:** Product Requirements Document.
* **RLS:** Row Level Security (PostgreSQL).
* **RTT:** Round-Trip Time.
* **SRS:** Software Requirements Specification.
* **URI / URL:** Uniform Resource Identifier / Locator.
* **Vault:** The cloud-backed repository storing group-uploaded audio files and extracted metadata.

### 1.4 References
1. IEEE Std 830-1998: *IEEE Recommended Practice for Software Requirements Specifications*.
2. IETF RFC 5905: *Network Time Protocol Version 4: Protocol and Algorithms Specification*.
3. W3C Media Session Standard: *Media Session Standard for Web Audio Handling*.
4. SynchroBeat Product Requirement Document (PRD) v1.0.0.

---

## 2. Overall Description

### 2.1 Product Perspective
SynchroBeat is a standalone cross-platform application interfacing with managed cloud infrastructure:


```

┌────────────────────────────────────────────────────────┐
│                   Flutter Client App                   │
│         (Android, iOS, Web via just_audio)             │
└─────────────┬───────────────────────────┬──────────────┘
│                           │
HTTPS Direct Audio Stream       WSS State Broadcasts & Sync
│                           │
▼                           ▼
┌───────────────────────────┐   ┌────────────────────────┐
│   Cloudflare R2 Bucket    │   │  Supabase / Node Core  │
│  (S3-Compatible CDN, R/W) │   │  - PostgreSQL + RLS    │
└───────────────────────────┘   │  - Realtime Engine     │
│  - GoTrue Auth Engine  │
└────────────────────────┘

```

### 2.2 Product Functions
* **Media Acquisition & Ingestion:** Local media ingestion, client-side metadata parsing, direct-to-storage multipart upload via pre-signed URLs.
* **Session Orchestration:** Creation, discovery, access control, and termination of private playback rooms.
* **Synchronized Playback Control:** State propagation (Play, Pause, Seek, Skip) bound to coordinated epoch timestamps.
* **Collaborative State Management:** Append, reorder, and remove tracks in a shared queue with real-time UI reflection across all room participants.
* **Audio Session Persistence:** Continuous audio stream execution during device sleep, application backgrounding, and lock-screen display states.

### 2.3 User Classes and Characteristics
* **Standard User (Listener):** Basic technical literacy. Interacts via mobile (iOS/Android) or desktop web browser. Capable of uploading audio files, joining rooms, queueing songs, and sending emoji reactions.
* **Room Host (DJ):** Standard user with elevated room privileges. Initiates playback, controls playhead positions (Seek/Pause/Play), and transfers or yields the host lease to other participants.
* **System Administrator:** Interacts via database consoles and object storage dashboards for maintenance, telemetry analysis, and storage cleanup.

### 2.4 Operating Environment
* **Client - Android:** Android OS 10.0 (API Level 29) or higher; arm64-v8a architecture minimum.
* **Client - iOS:** iOS 15.0 or higher; arm64 architecture.
* **Client - Web:** Modern evergreen browsers (Chrome 110+, Safari 15+, Firefox 110+, Edge 110+) supporting HTML5 Audio, WebSockets, and Media Session API.
* **Backend Runtime:** Node.js v20 LTS / Go 1.22 containerized via Docker on Linux x86_64; PostgreSQL 15+ engine via Supabase.
* **Storage Infrastructure:** Cloudflare R2 object storage with global edge caching.

### 2.5 Design and Implementation Constraints
* **Language & Framework:** Single codebase written in Dart using the Flutter SDK (Stable branch $\ge 3.22$).
* **Audio Constraints:** Background audio requirements mandate native bridging via platform services (`AudioService` on Android, `AVAudioSession` on iOS).
* **Storage Cost Constraint:** Zero-egress bandwidth requirements necessitate S3-compatible alternatives to AWS S3 (explicitly Cloudflare R2).
* **Room Scale:** Target concurrency is strictly bounded to $N \le 10$ users per room to avoid complex peer tree topologies and minimize latency jitter.

### 2.6 Assumptions and Dependencies
* Audio assets are legally owned or non-DRM-protected files supplied directly by the end user.
* Connected clients have active network connections with symmetric latency fluctuations not exceeding $\pm 200\text{ ms}$.
* Client system clocks do not mutate non-monotonically during an active session (e.g., manual clock adjustment while playing).

---

## 3. System Features and Functional Requirements

### 3.1 Authentication & User Profiles

#### 3.1.1 Description
Manages credential creation, OAuth handshakes, session token persistence, and profile association.

#### 3.1.2 Functional Requirements
* **REQ-AUTH-01:** The system shall authenticate users via email/password and third-party OAuth providers (Google, Apple).
* **REQ-AUTH-02:** The system shall persist JWT access tokens securely using `flutter_secure_storage` on mobile devices and secure HTTP-only cookies/local storage on Web.
* **REQ-AUTH-03:** The system shall automatically refresh expired access tokens using OAuth refresh token mechanisms without interrupting active audio sessions.
* **REQ-AUTH-04:** The system shall allow users to specify a display name (3–30 characters) and upload an avatar image (max 2 MB, converted to WebP format).

---

### 3.2 Communal Audio Vault (Ingestion & Storage)

#### 3.2.1 Description
Allows users to pick local audio files, extract track metadata on-device, obtain signed upload authorization, and persist files to Cloudflare R2.


```

[User Selects File] ──► [Extract ID3 Tags Locally] ──► [Request Signed URL from API]
│
[Save Track to DB]  ◄─── [Upload Direct to R2] ◄──────────────────┘

```

#### 3.2.2 Functional Requirements
* **REQ-VLT-01:** The system shall allow users to select `.mp3`, `.m4a`, `.wav`, and `.flac` files up to a maximum file size of 100 MB using the platform-native file picker.
* **REQ-VLT-02:** The client application shall parse ID3/metadata tags locally (Title, Artist, Album, Duration, and Embedded Artwork) prior to transmission.
* **REQ-VLT-03:** If metadata tags are absent, the client application shall assign the sanitized filename as the `Title` and designate the `Artist` as `"Unknown Artist"`.
* **REQ-VLT-04:** The backend shall provide time-limited (15-minute validity) pre-signed PUT URLs for direct client-to-R2 upload bypass.
* **REQ-VLT-05:** Upon successful binary transmission, the client shall issue an atomic write to the `tracks` database table with the storage URI, metadata, file size, and uploader identifier.
* **REQ-VLT-06:** The system shall display all tracks uploaded across the group in a searchable, alphabetically sortable communal library view.

---

### 3.3 Room Management & Presence

#### 3.3.1 Description
Orchestrates virtual listening spaces, generates join tokens, and monitors real-time user presence.

#### 3.3.2 Functional Requirements
* **REQ-ROM-01:** Any authenticated user shall be able to initialize a new room instance, automatically assuming the `Host` role.
* **REQ-ROM-02:** The system shall generate a cryptographically random, collision-resistant 6-character alphanumeric code for every initialized room.
* **REQ-ROM-03:** The system shall generate platform-agnostic deep links resolving to format `https://synchrobeat.app/join/{room_code}`.
* **REQ-ROM-04:** A user entering a valid 6-character code shall be joined to the active room channel within $< 500\text{ ms}$ under nominal network conditions.
* **REQ-ROM-05:** The room shall reject connections if concurrent active participants reach 10, returning an error payload: `ROOM_CAPACITY_EXCEEDED`.
* **REQ-ROM-06:** The system shall maintain real-time presence indicators displaying avatar, name, and connection state of all active room members.
* **REQ-ROM-07:** If the active `Host` disconnects ungracefully, the server shall transfer the host lease to the participant with the longest active connection duration within 3 seconds.
* **REQ-ROM-08:** The current `Host` shall have the explicit capability to yield host controls to any other connected participant in the room.

---

### 3.4 Synchronized Playback Engine

#### 3.4.1 Description
Provides sub-100ms synchronized playback using client-server clock offset calibration and scheduled timestamp triggers.

#### 3.4.2 Clock Synchronization Protocol
Each client entering a room executes a three-way handshake:
1. Client sends ping timestamp $t_0$.
2. Server receives at $t_1$ and responds with $t_1$ and outbound timestamp $t_2$.
3. Client receives response at $t_3$.

$$\text{RTT} = (t_3 - t_0) - (t_2 - t_1)$$
$$\text{Clock Offset } (\Delta t) = \frac{(t_1 - t_0) + (t_2 - t_3)}{2}$$
$$\text{Estimated Server Time} = t_{\text{local}} + \Delta t$$

#### 3.4.3 Functional Requirements
* **REQ-SYNC-01:** The client application shall execute the NTP-style synchronization sequence upon room connection and re-execute it at 60-second intervals to calculate running rolling-average clock skews.
* **REQ-SYNC-02:** When the Host initiates `PLAY`, the client shall dispatch an intent to the server containing `{ action: "PLAY", track_id: UUID, current_position_ms: INT }`.
* **REQ-SYNC-03:** The server shall broadcast a `PLAY_SCHEDULED` message specifying `trigger_epoch_ms = CurrentServerTime + 500ms`.
* **REQ-SYNC-04:** All client devices shall calculate local trigger time:
  $$T_{\text{trigger\_local}} = \text{trigger\_epoch\_ms} - \Delta t$$
  and schedule local playback initiation via high-resolution system timers.
* **REQ-SYNC-05:** When the Host invokes `PAUSE`, an immediate broadcast payload shall cause all clients to stop audio rendering within $\le 50\text{ ms}$ of message receipt.
* **REQ-SYNC-06:** When the Host invokes `SEEK`, playback on all clients shall pause, buffer the target audio frame, and resume synchronously using the `PLAY_SCHEDULED` protocol.
* **REQ-SYNC-07 (Drift Correction):** The client shall periodically verify its playback playhead against the host's theoretical playhead:
  * **$\vert{}\text{Drift}\vert{} < 100\text{ ms}$:** Take no corrective action.
  * **$100\text{ ms} \le \vert{}\text{Drift}\vert{} \le 350\text{ ms}$:** Adjust audio hardware playback speed rate to $0.95\times$ or $1.05\times$ until drift converges to $< 30\text{ ms}$.
  * **$\vert{}\text{Drift}\vert{} > 350\text{ ms}$:** Execute an atomic hard seek (`seekTo(targetPosition)`) to restore hard parity.

---

### 3.5 Collaborative Queue Management

#### 3.5.1 Description
Maintains the ordered playlist of upcoming tracks within an active room.

#### 3.5.2 Functional Requirements
* **REQ-QUE-01:** Any connected participant shall be able to append tracks from the Communal Vault to the room's queue.
* **REQ-QUE-02:** Queue mutations (Add, Reorder, Remove) shall be committed to the database and broadcast across the room's WebSocket channel within $< 100\text{ ms}$.
* **REQ-QUE-03:** When the active track reaches its terminal duration minus 10 seconds, all client instances shall begin background pre-buffering the subsequent track in the queue.
* **REQ-QUE-04:** If the queue is depleted, the audio engine shall enter an idle state at the end of the current track and await host intervention.

---

### 3.6 Background Playback & OS Integration

#### 3.6.1 Description
Integrates Flutter client audio lifecycle with native mobile and browser media controllers.

#### 3.6.2 Functional Requirements
* **REQ-OS-01 (Android):** The application shall run a foreground service displaying a persistent notification equipped with MediaStyle controls (Track Title, Artist, Album Art, Play/Pause, Skip Next).
* **REQ-OS-02 (iOS):** The application shall configure `AVAudioSessionCategoryPlayback` to maintain uninterrupted audio when the silent switch is engaged or the screen is locked.
* **REQ-OS-03 (iOS Media Center):** The application shall populate `MPNowPlayingInfoCenter` and bind remote commands via `MPRemoteCommandCenter`.
* **REQ-OS-04 (Web):** The application shall bind metadata and media actions to the browser `navigator.mediaSession` API.
* **REQ-OS-05:** Remote hardware events (headphone button presses, Bluetooth car controls) executed by the Host shall broadcast globally; inputs executed by Listeners shall modify only local volume or display a non-host restriction banner.

---

## 4. External Interface Requirements

### 4.1 User Interfaces

#### 4.1.1 General UX Layout
* **Adaptive Breakpoints:**
  * **Mobile Portrait:** Screen width $< 600\text{ dp}$. Bottom navigation bar, floating miniature player, full-screen modal player.
  * **Desktop / Web Expanded:** Screen width $\ge 600\text{ dp}$. Persistent left sidebar (Library/Rooms), central content area (Vault/Queue), persistent bottom playback control strip.
* **Player UI Elements:**
  * Scrubbing slider showing current position and total duration.
  * Host playback indicators (disabled scrubber for non-host participants with an informative tooltip).
  * Presence row rendering participant circular avatars.
  * Ephemeral floating emoji bar on the right margin.

### 4.2 Software Interfaces

#### 4.2.1 Audio Subsystem Interface
* Flutter client interfaces with platform audio subsystems via `just_audio` (version $\ge 0.9.36$) combined with `audio_service` (version $\ge 0.18.12$).

#### 4.2.2 Object Storage Interface
* All audio binary transfers shall use the Amazon S3-compatible REST API exposed by Cloudflare R2:
  * Method: `PUT`
  * Headers: `Content-Type: audio/{format}`, `x-amz-acl: private`
  * Authentication: SigV4 presigned query parameters.

#### 4.2.3 Database Interface
* Client interacts with PostgreSQL via the Supabase client SDK using HTTPS REST (PostgREST) and WebSocket connections for Realtime engine bindings.

### 4.3 Hardware Interfaces
* **Audio Output Routes:** Seamless dynamic switching across onboard speakers, 3.5mm headphone jacks, USB-C DACs, and Bluetooth A2DP audio profiles.
* **Audio Routing Interruption:** The app shall automatically pause or adjust volume ducking when receiving telephone calls or system alarms via native OS audio focus managers.

### 4.4 Communications Interfaces
* **Primary Protocol:** TLS 1.3 over TCP for all HTTPS and Secure WebSocket (WSS) traffic.
* **Data Serialization:** JSON for all real-time command, control, and sync messages.
* **Port Requirements:** Outbound ports 443 (HTTPS/WSS) and 80 (HTTP redirect).

---

## 5. Non-Functional Requirements

### 5.1 Performance Requirements
* **NFR-PER-01 (Audio Desynchronization Threshold):** Audio playhead deviation among all room participants on broadband/4G/5G connections shall remain $\le 100\text{ ms}$ for at least 95% of active playback time.
* **NFR-PER-02 (Frame Rate):** The Flutter rendering thread shall sustain a minimum of 58 FPS on standard 60 Hz mobile displays and 115 FPS on 120 Hz displays during queue drag-and-drop operations.
* **NFR-PER-03 (State Broadcast Latency):** Server WebSocket transit time for control packets (`PLAY`, `PAUSE`, `SEEK`) shall not exceed $100\text{ ms}$ at the 99th percentile ($p99$).
* **NFR-PER-04 (Memory Footprint):** Client mobile RAM consumption shall not exceed 180 MB during active streaming and caching of a 50 MB audio asset.

### 5.2 Reliability & Availability
* **NFR-REL-01 (Network Reconnection):** If network connectivity drops (e.g., cell tower handoff, Wi-Fi toggling), the client shall attempt exponential backoff reconnection and realign playhead positions within 2 seconds of link recovery.
* **NFR-REL-02 (System Uptime):** The backend API, Realtime engine, and Database shall sustain an operational availability $\ge 99.9\%$ excluding scheduled maintenance.

### 5.3 Security Requirements
* **NFR-SEC-01 (Access Control):** All database read/write permissions shall be enforced at the engine level via PostgreSQL Row Level Security (RLS) using authenticated JWT identity claims.
* **NFR-SEC-02 (Object Privacy):** Audio assets in Cloudflare R2 shall be completely private; public read access without an expiring signed URL or auth proxy token is strictly forbidden.
* **NFR-SEC-03 (Input Sanitization):** Metadata extracted from user files shall be sanitized against cross-site scripting (XSS) and SQL injection payloads prior to persistence.

### 5.4 Maintainability & Portability
* **NFR-PRT-01 (Cross-Platform Compilation):** At least 85% of application source code must reside in platform-agnostic Dart modules shared universally across Android, iOS, and Web targets.
* **NFR-MNT-01 (Modular Decoupling):** Audio playback logic, synchronization timing algorithms, and network transport adapters must remain structurally decoupled through dependency injection or service locator patterns.

---

## 6. Data Model & Schema Specification

The operational database structure is specified below:


```

┌─────────────────┐       ┌─────────────────┐
│    profiles     │       │     tracks      │
├─────────────────┤       ├─────────────────┤
│ id (PK)         │◄──┐   │ id (PK)         │◄──┐
│ display_name    │   └───│ uploader_id(FK) │   │
│ avatar_url      │       │ title           │   │
│ created_at      │       │ artist          │   │
└─────────────────┘       │ storage_path    │   │
▲                │ duration_sec    │   │
│                └─────────────────┘   │
│                         ▲            │
│                         │            │
┌────────┴────────┐       ┌────────┴────────┐   │
│      rooms      │       │   room_queue    │   │
├─────────────────┤       ├─────────────────┤   │
│ id (PK)         │       │ id (PK)         │   │
│ room_code       │       │ room_id (FK)    │   │
│ host_id (FK)    │       │ track_id (FK)───┼───┘
│ current_track_id│───────┘ position        │
│ is_playing      │       └─────────────────┘
│ playhead_pos_ms │
└─────────────────┘

```

### 6.1 Database Tables (PostgreSQL DDL)

```sql
-- Enable UUID generation extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. User Profiles Table
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name VARCHAR(50) NOT NULL,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 2. Communal Vault Audio Tracks Table
CREATE TABLE public.tracks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uploader_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    artist VARCHAR(255) DEFAULT 'Unknown Artist' NOT NULL,
    album VARCHAR(255) DEFAULT 'Unknown Album' NOT NULL,
    duration_seconds INTEGER NOT NULL CHECK (duration_seconds > 0),
    storage_path TEXT NOT NULL UNIQUE,
    cover_art_url TEXT,
    file_size_bytes BIGINT NOT NULL CHECK (file_size_bytes > 0),
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 3. Playback Rooms Table
CREATE TABLE public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_code VARCHAR(6) UNIQUE NOT NULL,
    host_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    current_track_id UUID REFERENCES public.tracks(id) ON DELETE SET NULL,
    is_playing BOOLEAN DEFAULT FALSE NOT NULL,
    playhead_position_ms INTEGER DEFAULT 0 NOT NULL CHECK (playhead_position_ms >= 0),
    server_sync_timestamp TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 4. Room Queue Table
CREATE TABLE public.room_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    track_id UUID NOT NULL REFERENCES public.tracks(id) ON DELETE CASCADE,
    added_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    position INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT unique_room_position UNIQUE(room_id, position)
);

-- Indexes for Query Optimization
CREATE INDEX idx_tracks_uploader ON public.tracks(uploader_id);
CREATE INDEX idx_rooms_code ON public.rooms(room_code);
CREATE INDEX idx_queue_room_pos ON public.room_queue(room_id, position);

```

### 6.2 Real-time Message Payloads

#### 6.2.1 Play Event Payload (`PLAY_SCHEDULED`)

```json
{
  "event": "PLAY_SCHEDULED",
  "room_id": "8a3d5b78-1a2f-4c8d-90e1-7e83a45c7112",
  "track_id": "41cf43c0-3de8-48b2-b1e4-83957cc1b569",
  "start_position_ms": 45200,
  "trigger_at_server_time_ms": 1776157500500
}

```

#### 6.2.2 Pause Event Payload (`PAUSE_IMMEDIATE`)

```json
{
  "event": "PAUSE_IMMEDIATE",
  "room_id": "8a3d5b78-1a2f-4c8d-90e1-7e83a45c7112",
  "track_position_ms": 48920,
  "server_timestamp_ms": 1776157504220
}

```

#### 6.2.3 Seek Event Payload (`SEEK_SCHEDULED`)

```json
{
  "event": "SEEK_SCHEDULED",
  "room_id": "8a3d5b78-1a2f-4c8d-90e1-7e83a45c7112",
  "target_position_ms": 112000,
  "trigger_at_server_time_ms": 1776157512800
}

```

---

## 7. Verification & Quality Assurance Matrix

| Req ID | Requirement Overview | Verification Method | Acceptance Criteria |
| --- | --- | --- | --- |
| **REQ-VLT-01** | Support 100 MB files (.mp3, .wav, .flac, .m4a) | Test | Files up to 100 MB upload without payload drop; unsupported formats throw input validation dialog. |
| **REQ-VLT-02** | Local ID3 Metadata extraction | Inspection / Test | Mock audio files show valid Artist, Title, and Album artwork in preview prior to cloud upload. |
| **REQ-ROM-02** | 6-character room codes | Automated Unit Test | Generated codes evaluate to `^[A-Z0-9]{6}$` across 100,000 continuous test iterations without collisions. |
| **REQ-ROM-05** | Limit room concurrency to 10 users | System Test | The 11th client attempting connection receives HTTP 403 / `ROOM_CAPACITY_EXCEEDED` rejection. |
| **REQ-SYNC-01** | NTP clock skew estimation | Integration Test | Calculated local offset tracks against network timing emulators within $\pm 10\text{ ms}$ error margin. |
| **REQ-SYNC-07** | Automatic playback drift correction | System Test | Simulated network jitter of $200\text{ ms}$ causes playback rate adjustment ($1.05\times$) returning to sync $< 30\text{ ms}$ within 3 seconds. |
| **REQ-OS-01** | Android background audio notification | Hardware System Test | Device screen lock does not terminate audio; notification media buttons successfully control playback. |
| **NFR-PER-01** | Total system drift $\le 100\text{ ms}$ | Acoustic Benchmark | Dual recording setup measuring concurrent acoustic output pulses shows delta $\le 100\text{ ms}$ across 95% of test runtime. |

```

```