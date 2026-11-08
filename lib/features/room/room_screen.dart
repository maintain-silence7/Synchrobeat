import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../auth/auth_repository.dart';
import '../common/app_buttons.dart';
import '../common/avatar_circle.dart';
import '../player/playback_service.dart';
import '../sync/sync_playback_controller.dart';
import '../vault/local_track_repository.dart';
import '../vault/track.dart';
import 'local_room_repository.dart';
import 'room_models.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _FloatingEmoji {
  _FloatingEmoji(this.id, this.emoji) : left = 0.15 + (id % 700) / 1000;
  final int id;
  final String emoji;
  final double left; // fraction of screen width
}

class _RoomScreenState extends State<RoomScreen> {
  late final LocalRoomRepository _rooms;
  late final PlaybackService _playback;
  late final SyncPlaybackController _sync;
  late final StreamSubscription<EmojiEvent> _emojiSub;

  final List<_FloatingEmoji> _floats = [];
  bool _isDragging = false;
  double _dragValue = 0;

  static const _reactionEmojis = ['🎧', '🔥', '👏', '💜', '😂', '🚀'];

  @override
  void initState() {
    super.initState();
    _rooms = sl<LocalRoomRepository>();
    _playback = sl<PlaybackService>();
    _sync = sl<SyncPlaybackController>();
    _emojiSub = _rooms.emojiStream.listen(_onEmoji);
  }

  @override
  void dispose() {
    _emojiSub.cancel();
    super.dispose();
  }

  void _onEmoji(EmojiEvent event) {
    final float = _FloatingEmoji(event.id, event.emoji);
    setState(() => _floats.add(float));
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _floats.removeWhere((f) => f.id == float.id));
      }
    });
  }

  Future<void> _copyInvite(Room room) async {
    await Clipboard.setData(
      ClipboardData(text: 'https://synchrobeat.app/join/${room.code}'),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite link copied to clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _leaveRoom() async {
    final user = sl<AuthRepository>().currentUser;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave room?'),
            content: const Text(
              'Playback stops for you. If you are the host, the DJ role passes to the longest-waiting listener.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed && mounted) {
      await _rooms.leaveRoom(user);
      if (mounted) context.go('/home');
    }
  }

  Future<void> _showAddFromVault() async {
    final tracks = await sl<LocalTrackRepository>().listTracks();
    if (!mounted) return;
    final user = sl<AuthRepository>().currentUser;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighlight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.library_music_rounded,
                        color: AppTheme.primaryAccent, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Add Tracks from Vault',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Divider(),
              if (tracks.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Vault is empty. Upload some tracks first!',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.surfaceBorder),
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: AppTheme.artworkFallbackGradient,
                            ),
                            child: const Icon(Icons.music_note_rounded,
                                color: Colors.white70, size: 20),
                          ),
                          title: Text(track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                          trailing: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: AppTheme.secondary, size: 20),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            if (user != null) {
                              await _rooms.enqueueTrack(track, user);
                            }
                          },
                        ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _transferHost(RoomMember member) async {
    final user = sl<AuthRepository>().currentUser;
    if (user == null) return;
    try {
      await _rooms.transferHost(member.id, user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.displayName} is now the DJ'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on RoomFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = sl<AuthRepository>().currentUser;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/home'),
        ),
        title: StreamBuilder<Room?>(
          stream: _rooms.roomStream,
          initialData: _rooms.currentRoom,
          builder: (context, snapshot) => Text(
            snapshot.data == null ? 'Room' : 'Room ${snapshot.data!.code}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        actions: [
          StreamBuilder<Room?>(
            stream: _rooms.roomStream,
            initialData: _rooms.currentRoom,
            builder: (context, snapshot) {
              final room = snapshot.data;
              if (room == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Copy invite link',
                icon: const Icon(Icons.share_rounded, size: 20),
                onPressed: () => _copyInvite(room),
              );
            },
          ),
          IconButton(
            tooltip: 'Leave room',
            icon: const Icon(Icons.logout_rounded,
                size: 20, color: AppTheme.error),
            onPressed: _leaveRoom,
          ),
        ],
      ),
      body: StreamBuilder<Room?>(
        stream: _rooms.roomStream,
        initialData: _rooms.currentRoom,
        builder: (context, snapshot) {
          final room = snapshot.data;
          if (room == null) {
            return _EmptyRoomState(onGoHome: () => context.go('/home'));
          }
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  _ParticipantsBar(
                    room: room,
                    currentUserId: currentUser?.id,
                    onTransferHost: _transferHost,
                  ),
                  _NowPlayingCard(
                    room: room,
                    playback: _playback,
                    sync: _sync,
                    isDragging: _isDragging,
                    dragValue: _dragValue,
                    onDragStart: (v) => setState(() {
                      _isDragging = true;
                      _dragValue = v;
                    }),
                    onDragUpdate: (v) => setState(() => _dragValue = v),
                    onDragEnd: (v) {
                      setState(() => _isDragging = false);
                      _rooms.seekTo(Duration(milliseconds: v.round()));
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                    child: Row(
                      children: [
                        const Text(
                          'UP NEXT',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _showAddFromVault,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    size: 16, color: AppTheme.primaryAccent),
                                SizedBox(width: 4),
                                Text(
                                  'Add from Vault',
                                  style: TextStyle(
                                    color: AppTheme.primaryAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _QueueSection(room: room, rooms: _rooms),
                ],
              ),
              // Floating emoji reactions overlay
              for (final float in _floats)
                Positioned(
                  left: MediaQuery.of(context).size.width * float.left,
                  bottom: 180,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1500),
                    builder: (context, t, child) => Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -150 * t),
                        child: Text(
                          float.emoji,
                          style: const TextStyle(fontSize: 42),
                        ),
                      ),
                    ),
                  ),
                ),
              // Floating Emoji reaction bar
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: AppTheme.surfaceBorder,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final emoji in _reactionEmojis)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              final user = sl<AuthRepository>().currentUser;
                              if (user != null) {
                                _rooms.sendEmoji(emoji, user);
                              }
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.surfaceHighlight
                                    .withValues(alpha: 0.5),
                              ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyRoomState extends StatelessWidget {
  const _EmptyRoomState({required this.onGoHome});
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHighlight.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.meeting_room_outlined,
                  size: 54, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            const Text(
              'You are not in a room',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Join or create a listening room to experience synchronized audio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            PrimaryGradientButton(
              onPressed: onGoHome,
              label: 'Go to Rooms',
              isFullWidth: false,
              icon: const Icon(Icons.groups_rounded,
                  size: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantsBar extends StatelessWidget {
  const _ParticipantsBar({
    required this.room,
    required this.currentUserId,
    required this.onTransferHost,
  });

  final Room room;
  final String? currentUserId;
  final ValueChanged<RoomMember> onTransferHost;

  @override
  Widget build(BuildContext context) {
    final isHost = room.hostId == currentUserId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: room.members.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final member = room.members[index];
            final canManage = isHost && member.id != currentUserId;
            final avatar = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    AvatarCircle(
                      emoji: member.avatarEmoji,
                      colorValue: member.avatarColorValue,
                      radius: 24,
                    ),
                    if (member.isHost)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppTheme.background,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppTheme.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star_rounded,
                              size: 10, color: Colors.black),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (member.isHost)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'DJ',
                          style: TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    Text(
                      member.id == currentUserId ? 'You' : member.displayName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            );
            if (!canManage) return avatar;
            return PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'dj') onTransferHost(member);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'dj',
                  child: Row(
                    children: [
                      Icon(Icons.headphones_rounded,
                          size: 18, color: AppTheme.secondary),
                      SizedBox(width: 8),
                      Text('Make DJ'),
                    ],
                  ),
                ),
              ],
              child: avatar,
            );
          },
        ),
      ),
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({
    required this.room,
    required this.playback,
    required this.sync,
    required this.isDragging,
    required this.dragValue,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Room room;
  final PlaybackService playback;
  final SyncPlaybackController sync;
  final bool isDragging;
  final double dragValue;
  final ValueChanged<double> onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context) {
    final track = room.currentTrack;
    if (track == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: const Column(
          children: [
            Icon(Icons.queue_music_rounded,
                size: 44, color: AppTheme.textSecondary),
            SizedBox(height: 14),
            Text(
              'Nothing playing yet',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              'Add tracks from the Vault, then tap one to start synchronized playback.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF221A3D), Color(0xFF161624)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _Artwork(track: track, size: 156),
          const SizedBox(height: 16),
          Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<SyncStatus>(
            valueListenable: sync.status,
            builder: (context, status, _) {
              final (label, color) = switch (status.action) {
                DriftAction.none => (
                    'SYNC LOCKED · ±${status.driftMs.abs()}ms',
                    AppTheme.secondary
                  ),
                DriftAction.warpFaster ||
                DriftAction.warpSlower =>
                  ('TUNING · ${status.driftMs}ms', const Color(0xFFFFD166)),
                DriftAction.hardSeek =>
                  ('RESYNCING · ${status.driftMs}ms', AppTheme.error),
              };
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          StreamBuilder<Duration>(
            stream: playback.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final total = track.duration;
              final maxMs = total.inMilliseconds <= 0
                  ? 1.0
                  : total.inMilliseconds.toDouble();
              final value = isDragging
                  ? dragValue
                  : position.inMilliseconds.toDouble().clamp(0.0, maxMs);
              return Column(
                children: [
                  SliderTheme(
                    data: const SliderThemeData(
                      trackHeight: 4,
                      activeTrackColor: AppTheme.secondary,
                      inactiveTrackColor: AppTheme.surfaceHighlight,
                      thumbColor: Colors.white,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: value.clamp(0.0, maxMs),
                      max: maxMs,
                      onChangeStart: onDragStart,
                      onChanged: onDragUpdate,
                      onChangeEnd: onDragEnd,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatDuration(Duration(milliseconds: value.round())),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          total.inMilliseconds > 0
                              ? '-${formatDuration(total - Duration(milliseconds: value.round()))}'
                              : '--:--',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkipControlButton(
                icon: Icons.skip_previous_rounded,
                size: 48,
                iconSize: 28,
                onPressed: () => playback.skipPrevious(),
              ),
              const SizedBox(width: 18),
              PlaybackControlButton(
                isPlaying: room.isPlaying,
                size: 68,
                iconSize: 38,
                onTap: () => sl<LocalRoomRepository>().togglePlayPause(),
              ),
              const SizedBox(width: 18),
              SkipControlButton(
                icon: Icons.skip_next_rounded,
                size: 48,
                iconSize: 28,
                onPressed: () => sl<LocalRoomRepository>().skipNext(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.track, required this.size});
  final Track track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final art = track.artworkPath;
    final borderRadius = BorderRadius.circular(18);
    if (art != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Image.file(
            File(art),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: AppTheme.artworkFallbackGradient,
        ),
        child: const Icon(Icons.music_note_rounded,
            size: 56, color: Colors.white70),
      );
}

class _QueueSection extends StatelessWidget {
  const _QueueSection({required this.room, required this.rooms});
  final Room room;
  final LocalRoomRepository rooms;

  @override
  Widget build(BuildContext context) {
    if (room.queue.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Center(
          child: Text(
            'Queue is empty — add tracks to build a shared lineup.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: room.queue.length,
      onReorderItem: rooms.reorderQueue,
      itemBuilder: (context, index) {
        final item = room.queue[index];
        return Container(
          key: ValueKey(item.id),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            leading: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle_rounded,
                  color: AppTheme.textSecondary),
            ),
            title: Text(
              item.track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              '${item.track.artist}  ·  by ${item.addedByName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppTheme.textSecondary),
              onPressed: () => rooms.removeQueueItem(item.id),
            ),
            onTap: () => rooms.playQueueItem(item.id),
          ),
          ),
        );
      },
    );
  }
}
