import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../auth/app_user.dart';
import '../player/playback_service.dart';
import '../sync/sync_playback_controller.dart';
import '../sync/time_sync_service.dart';
import '../vault/track.dart';
import 'room_models.dart';

class RoomFailure implements Exception {
  const RoomFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Offline demo room orchestration: rooms live in memory on this device
/// (ephemeral by design) and the sync math still runs through the real
/// [TimeSyncService] + [SyncPlaybackController] pipeline. A Supabase Realtime
/// backed implementation can replace this class without UI changes.
class LocalRoomRepository {
  LocalRoomRepository(this._playback, this._timeSync, this._sync) {
    _completedSub = _playback.trackCompleted.listen(_onTrackCompleted);
  }

  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final PlaybackService _playback;
  final TimeSyncService _timeSync;
  final SyncPlaybackController _sync;
  final _uuid = const Uuid();
  final _random = Random();

  final Map<String, Room> _rooms = {};
  Room? _current;

  late final StreamSubscription<Track> _completedSub;
  final _roomController = StreamController<Room?>.broadcast();
  final _emojiController = StreamController<EmojiEvent>.broadcast();

  Stream<Room?> get roomStream => _roomController.stream;
  Stream<EmojiEvent> get emojiStream => _emojiController.stream;
  Room? get currentRoom => _current;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  String _generateCode() {
    String code;
    do {
      code = List.generate(
        AppConstants.roomCodeLength,
        (_) => _codeAlphabet[_random.nextInt(_codeAlphabet.length)],
      ).join();
    } while (_rooms.containsKey(code));
    return code;
  }

  static RoomMember _memberOf(AppUser user, {required bool isHost}) => RoomMember(
        id: user.id,
        displayName: user.displayName,
        avatarEmoji: user.avatarEmoji,
        avatarColorValue: user.avatarColorValue,
        isHost: isHost,
      );

  Future<Room> createRoom(AppUser host) async {
    if (_current != null) return _current!;
    final code = _generateCode();
    final room = Room(
      id: _uuid.v4(),
      code: code,
      hostId: host.id,
      members: [_memberOf(host, isHost: true)],
      currentTrack: null,
      queue: const [],
      isPlaying: false,
      playheadPositionMs: 0,
      serverSyncTimestamp: _timeSync.estimatedServerTime,
      createdAt: _timeSync.estimatedServerTime,
    );
    _rooms[code] = room;
    _setCurrent(room);
    return room;
  }

  Future<Room> joinRoom(String rawCode, AppUser user) async {
    final code = rawCode.trim().toUpperCase();
    if (code.length != AppConstants.roomCodeLength) {
      throw const RoomFailure('Enter the 6-character room code.');
    }
    final room = _rooms[code];
    if (room == null) {
      throw const RoomFailure(
        'Room not found. Codes are valid for the lifetime of the host\'s session.',
      );
    }
    if (room.members.any((m) => m.id == user.id)) {
      _setCurrent(room);
      return room;
    }
    if (room.members.length >= AppConstants.maxRoomCapacity) {
      throw const RoomFailure('This room is full (max 10 listeners).');
    }
    final updated = room.copyWith(
      members: [...room.members, _memberOf(user, isHost: false)],
    );
    _rooms[code] = updated;
    _setCurrent(updated);
    return updated;
  }

  Future<void> leaveRoom(AppUser user) async {
    final room = _current;
    if (room == null) return;
    _playback.autoAdvanceFromContext = true;
    _sync.reset();
    await _playback.pause();
    await _playback.seek(Duration.zero);
    final remaining = room.members.where((m) => m.id != user.id).toList();
    if (remaining.isEmpty) {
      _rooms.remove(room.code);
    } else if (room.hostId == user.id) {
      // Host handover: promote the earliest-joined remaining member.
      final promoted = remaining.first.copyWith(isHost: true);
      final next = [promoted, ...remaining.skip(1)];
      final updated = room.copyWith(hostId: promoted.id, members: next);
      _rooms[room.code] = updated;
    } else {
      _rooms[room.code] = room.copyWith(members: remaining);
    }
    _setCurrent(null);
  }

  // ─── Playback orchestration ────────────────────────────────────────────────

  Future<void> playTrackNow(Track track, AppUser user) async {
    final room = _requireRoom();
    _roomMutation(room.copyWith(
      currentTrack: track,
      isPlaying: true,
      playheadPositionMs: 0,
      serverSyncTimestamp: _timeSync.estimatedServerTime,
    ));
    _playback.currentTrack.value = track;
    _playback.contextQueue.value = [track];
    _playback.autoAdvanceFromContext = false;
    await _playback.prepare(track, Duration.zero);
    await _sync.schedulePlay(fromPosition: Duration.zero);
  }

  Future<void> togglePlayPause() async {
    final room = _requireRoom();
    final track = room.currentTrack;
    if (track == null) return;
    if (room.isPlaying) {
      _sync.schedulePause();
      final position = _playback.player.position.inMilliseconds;
      _roomMutation(room.copyWith(
        isPlaying: false,
        playheadPositionMs: position,
        serverSyncTimestamp: _timeSync.estimatedServerTime,
      ));
    } else {
      final position = Duration(milliseconds: room.playheadPositionMs);
      _roomMutation(room.copyWith(
        isPlaying: true,
        serverSyncTimestamp: _timeSync.estimatedServerTime,
      ));
      await _sync.schedulePlay(fromPosition: position);
    }
  }

  Future<void> seekTo(Duration position) async {
    final room = _requireRoom();
    await _playback.seek(position);
    if (room.isPlaying) _sync.reposition(position);
    _roomMutation(room.copyWith(
      playheadPositionMs: position.inMilliseconds,
      serverSyncTimestamp: _timeSync.estimatedServerTime,
    ));
  }

  Future<void> skipNext() async {
    final room = _requireRoom();
    if (room.queue.isEmpty) {
      _sync.reset();
      await _playback.pause();
      await _playback.seek(Duration.zero);
      _roomMutation(room.copyWith(
        clearCurrentTrack: true,
        isPlaying: false,
        playheadPositionMs: 0,
      ));
      return;
    }
    final next = room.queue.first;
    final remaining = _renumbered(room.queue.skip(1).toList());
    _roomMutation(room.copyWith(
      currentTrack: next.track,
      queue: remaining,
      isPlaying: true,
      playheadPositionMs: 0,
      serverSyncTimestamp: _timeSync.estimatedServerTime,
    ));
    _playback.currentTrack.value = next.track;
    _playback.contextQueue.value = [next.track];
    _playback.autoAdvanceFromContext = false;
    await _playback.prepare(next.track, Duration.zero);
    await _sync.schedulePlay(fromPosition: Duration.zero);
  }

  Future<void> playQueueItem(String itemId) async {
    final room = _requireRoom();
    final match = room.queue.where((q) => q.id == itemId).toList();
    if (match.isEmpty) return;
    final item = match.first;
    final remaining =
        _renumbered(room.queue.where((q) => q.id != itemId).toList());
    _roomMutation(room.copyWith(
      currentTrack: item.track,
      queue: remaining,
      isPlaying: true,
      playheadPositionMs: 0,
      serverSyncTimestamp: _timeSync.estimatedServerTime,
    ));
    _playback.currentTrack.value = item.track;
    _playback.autoAdvanceFromContext = false;
    await _playback.prepare(item.track, Duration.zero);
    await _sync.schedulePlay(fromPosition: Duration.zero);
  }

  Future<void> _onTrackCompleted(Track finished) async {
    final room = _current;
    if (room == null) return;
    if (room.currentTrack?.id != finished.id) return;
    await skipNext();
  }

  // ─── Queue ─────────────────────────────────────────────────────────────────

  Future<void> enqueueTrack(Track track, AppUser user) async {
    final room = _requireRoom();
    final item = QueueItem(
      id: _uuid.v4(),
      track: track,
      addedByName: user.displayName,
      position: room.queue.length,
    );
    _roomMutation(room.copyWith(queue: [...room.queue, item]));
  }

  Future<void> removeQueueItem(String itemId) async {
    final room = _requireRoom();
    final remaining =
        _renumbered(room.queue.where((q) => q.id != itemId).toList());
    _roomMutation(room.copyWith(queue: remaining));
  }

  /// Moves the item at [oldIndex] to [newIndex]. Indices are final positions
  /// (the ReorderableListView `onReorderItem` callback adjusts for removal).
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final room = _requireRoom();
    final queue = [...room.queue];
    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex.clamp(0, queue.length), item);
    _roomMutation(room.copyWith(queue: _renumbered(queue)));
  }

  List<QueueItem> _renumbered(List<QueueItem> items) => [
        for (var i = 0; i < items.length; i++) items[i].copyWith(position: i),
      ];

  // ─── Presence / social ─────────────────────────────────────────────────────

  void sendEmoji(String emoji, AppUser user) {
    _emojiController.add(EmojiEvent(
      id: DateTime.now().microsecondsSinceEpoch,
      emoji: emoji,
      fromName: user.displayName,
    ));
  }

  Future<void> transferHost(String memberId, AppUser requester) async {
    final room = _requireRoom();
    if (room.hostId != requester.id) {
      throw const RoomFailure('Only the host can hand over the DJ role.');
    }
    if (!room.members.any((m) => m.id == memberId)) {
      throw const RoomFailure('That listener is no longer in the room.');
    }
    final members = [
      for (final m in room.members) m.copyWith(isHost: m.id == memberId),
    ];
    _roomMutation(room.copyWith(hostId: memberId, members: members));
  }

  // ─── Internals ─────────────────────────────────────────────────────────────

  Room _requireRoom() {
    final room = _current;
    if (room == null) {
      throw const RoomFailure('You are not in a room yet.');
    }
    return room;
  }

  void _roomMutation(Room room) {
    _rooms[room.code] = room;
    _setCurrent(room);
  }

  void _setCurrent(Room? room) {
    _current = room;
    _roomController.add(room);
  }

  Future<void> dispose() async {
    await _completedSub.cancel();
    await _roomController.close();
    await _emojiController.close();
  }
}


