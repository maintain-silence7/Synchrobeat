import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../auth/auth_repository.dart';
import '../common/app_buttons.dart';
import '../player/playback_service.dart';
import '../room/local_room_repository.dart';
import 'local_track_repository.dart';
import 'track.dart';
import 'upload_screen.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

enum _VaultSort { recent, title, artist }

class _VaultScreenState extends State<VaultScreen> {
  late final LocalTrackRepository _repo;
  late final PlaybackService _playback;
  List<Track> _tracks = const [];
  bool _loading = true;
  String _query = '';
  _VaultSort _sort = _VaultSort.recent;

  @override
  void initState() {
    super.initState();
    _repo = sl<LocalTrackRepository>();
    _playback = sl<PlaybackService>();
    _repo.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    _repo.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final tracks = await _repo.listTracks();
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _loading = false;
    });
  }

  List<Track> get _visible {
    var list = _tracks.where((t) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q);
    }).toList();
    switch (_sort) {
      case _VaultSort.recent:
        break; // repository already returns newest first
      case _VaultSort.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _VaultSort.artist:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
    }
    return list;
  }

  Future<void> _addToQueue(Track track) async {
    final rooms = sl<LocalRoomRepository>();
    final authRepo = sl<AuthRepository>();
    final user = authRepo.currentUser;
    if (rooms.currentRoom == null || user == null) return;
    await rooms.enqueueTrack(track, user);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${track.title}" to the room queue'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteTrack(Track track) async {
    final user = sl<AuthRepository>().currentUser;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove from vault?'),
            content: Text('"${track.title}" will be deleted for everyone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await _repo.deleteTrack(track.id, requesterId: user.id);
    } on VaultFailure catch (e) {
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

  Future<void> _openUpload() async {
    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const UploadScreen()),
    );
    if (uploaded == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final inRoom = sl<LocalRoomRepository>().currentRoom != null;
    final currentUser = sl<AuthRepository>().currentUser;
    final tracks = _visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Communal Vault'),
        actions: [
          PopupMenuButton<_VaultSort>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort tracks',
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _VaultSort.recent,
                child: Row(
                  children: [
                    Icon(
                      _sort == _VaultSort.recent
                          ? Icons.check
                          : Icons.access_time_rounded,
                      size: 18,
                      color: _sort == _VaultSort.recent
                          ? AppTheme.secondary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sort: Recent'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _VaultSort.title,
                child: Row(
                  children: [
                    Icon(
                      _sort == _VaultSort.title
                          ? Icons.check
                          : Icons.title_rounded,
                      size: 18,
                      color: _sort == _VaultSort.title
                          ? AppTheme.secondary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sort: Title'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _VaultSort.artist,
                child: Row(
                  children: [
                    Icon(
                      _sort == _VaultSort.artist
                          ? Icons.check
                          : Icons.person_outline_rounded,
                      size: 18,
                      color: _sort == _VaultSort.artist
                          ? AppTheme.secondary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sort: Artist'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: AppTheme.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _openUpload,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
          label: const Text(
            'Upload Track',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search tracks, artists, albums…',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.textSecondary, size: 22),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppTheme.textSecondary, size: 18),
                        onPressed: () => setState(() => _query = ''),
                      ),
              ),
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primaryAccent,
                ),
              ),
            )
          else if (tracks.isEmpty)
            Expanded(
              child: Center(
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
                        child: const Icon(Icons.library_music_rounded,
                            size: 54, color: AppTheme.primaryAccent),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _query.isEmpty
                            ? 'The vault is empty'
                            : 'No tracks match "$_query"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _query.isEmpty
                            ? 'Upload audio files so everyone in the room can stream them in sync.'
                            : 'Try adjusting your search terms.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (_query.isEmpty) ...[
                        const SizedBox(height: 24),
                        PrimaryGradientButton(
                          onPressed: _openUpload,
                          label: 'Upload First Track',
                          isFullWidth: false,
                          icon: const Icon(Icons.add_rounded,
                              size: 18, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ValueListenableBuilder<Track?>(
                valueListenable: _playback.currentTrack,
                builder: (context, activeTrack, _) {
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final isOwn = currentUser?.id == track.uploaderId;
                      final isPlayingThis = activeTrack?.id == track.id;

                      return Container(
                        decoration: BoxDecoration(
                          color: isPlayingThis
                              ? AppTheme.primary.withValues(alpha: 0.12)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isPlayingThis
                                ? AppTheme.primary.withValues(alpha: 0.5)
                                : AppTheme.surfaceBorder,
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            leading: _TrackArtwork(
                              track: track,
                              size: 48,
                              isPlaying: isPlayingThis,
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isPlayingThis
                                    ? AppTheme.primaryAccent
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                '${track.artist}  •  ${formatDuration(track.duration)}  •  ${track.uploaderName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            onTap: () =>
                                _playback.playTrack(track, context: _visible),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded,
                                  color: AppTheme.textSecondary),
                              onSelected: (value) {
                                if (value == 'queue') _addToQueue(track);
                                if (value == 'delete') _deleteTrack(track);
                              },
                              itemBuilder: (context) => [
                                if (inRoom)
                                  const PopupMenuItem(
                                    value: 'queue',
                                    child: Row(
                                      children: [
                                        Icon(Icons.queue_music_rounded,
                                            size: 18,
                                            color: AppTheme.secondary),
                                        SizedBox(width: 10),
                                        Text('Add to room queue'),
                                      ],
                                    ),
                                  ),
                                if (isOwn)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded,
                                            size: 18, color: AppTheme.error),
                                        SizedBox(width: 10),
                                        Text(
                                          'Delete from vault',
                                          style:
                                              TextStyle(color: AppTheme.error),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TrackArtwork extends StatelessWidget {
  const _TrackArtwork({
    required this.track,
    required this.size,
    this.isPlaying = false,
  });

  final Track track;
  final double size;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final art = track.artworkPath;
    final borderRadius = BorderRadius.circular(12);
    Widget imageWidget;

    if (art != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          File(art),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(size),
        ),
      );
    } else {
      imageWidget = _fallback(size);
    }

    if (isPlaying) {
      return Stack(
        alignment: Alignment.center,
        children: [
          imageWidget,
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: Colors.black.withValues(alpha: 0.5),
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: AppTheme.secondary,
              size: 22,
            ),
          ),
        ],
      );
    }

    return imageWidget;
  }

  Widget _fallback(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: AppTheme.artworkFallbackGradient,
        ),
        child: const Icon(Icons.music_note_rounded,
            color: Colors.white70, size: 22),
      );
}
