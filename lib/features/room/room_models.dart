import 'package:equatable/equatable.dart';

import '../vault/track.dart';

class RoomMember extends Equatable {
  const RoomMember({
    required this.id,
    required this.displayName,
    required this.avatarEmoji,
    required this.avatarColorValue,
    required this.isHost,
  });

  final String id;
  final String displayName;
  final String avatarEmoji;
  final int avatarColorValue;
  final bool isHost;

  RoomMember copyWith({bool? isHost}) => RoomMember(
        id: id,
        displayName: displayName,
        avatarEmoji: avatarEmoji,
        avatarColorValue: avatarColorValue,
        isHost: isHost ?? this.isHost,
      );

  @override
  List<Object?> get props => [id, displayName, isHost];
}

class QueueItem extends Equatable {
  const QueueItem({
    required this.id,
    required this.track,
    required this.addedByName,
    required this.position,
  });

  final String id;
  final Track track;
  final String addedByName;
  final int position;

  QueueItem copyWith({int? position}) => QueueItem(
        id: id,
        track: track,
        addedByName: addedByName,
        position: position ?? this.position,
      );

  @override
  List<Object?> get props => [id];
}

class Room extends Equatable {
  const Room({
    required this.id,
    required this.code,
    required this.hostId,
    required this.members,
    required this.currentTrack,
    required this.queue,
    required this.isPlaying,
    required this.playheadPositionMs,
    required this.serverSyncTimestamp,
    required this.createdAt,
  });

  final String id;
  final String code;
  final String hostId;
  final List<RoomMember> members;
  final Track? currentTrack;
  final List<QueueItem> queue;
  final bool isPlaying;
  final int playheadPositionMs;
  final DateTime serverSyncTimestamp;
  final DateTime createdAt;

  bool get isActive => currentTrack != null;

  Room copyWith({
    String? hostId,
    List<RoomMember>? members,
    Track? currentTrack,
    bool clearCurrentTrack = false,
    List<QueueItem>? queue,
    bool? isPlaying,
    int? playheadPositionMs,
    DateTime? serverSyncTimestamp,
  }) {
    return Room(
      id: id,
      code: code,
      hostId: hostId ?? this.hostId,
      members: members ?? this.members,
      currentTrack: clearCurrentTrack ? null : (currentTrack ?? this.currentTrack),
      queue: queue ?? this.queue,
      isPlaying: isPlaying ?? this.isPlaying,
      playheadPositionMs: playheadPositionMs ?? this.playheadPositionMs,
      serverSyncTimestamp: serverSyncTimestamp ?? this.serverSyncTimestamp,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        hostId,
        members,
        currentTrack,
        queue,
        isPlaying,
        playheadPositionMs,
        serverSyncTimestamp,
      ];
}

class EmojiEvent {
  const EmojiEvent({
    required this.id,
    required this.emoji,
    required this.fromName,
  });
  final int id;
  final String emoji;
  final String fromName;
}
