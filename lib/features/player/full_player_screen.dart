import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../common/app_buttons.dart';
import '../room/local_room_repository.dart';
import '../sync/sync_playback_controller.dart';
import '../sync/time_sync_service.dart';
import 'playback_service.dart';

/// Full-screen "Now Playing". Also surfaces the sync engine telemetry
/// (clock offset + drift action) so the lock is visible, not magical.
class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  bool _isDragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    final playback = sl<PlaybackService>();
    final sync = sl<SyncPlaybackController>();
    final timeSync = sl<TimeSyncService>();
    final rooms = sl<LocalRoomRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: playback.currentTrack,
        builder: (context, track, _) {
          if (track == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_off_outlined,
                      size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'Nothing playing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Explore Vault'),
                  ),
                ],
              ),
            );
          }
          final art = track.artworkPath;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Artwork with ambient glow shadow
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                          blurRadius: 36,
                          spreadRadius: 2,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: art != null
                          ? Image.file(
                              File(art),
                              width: 270,
                              height: 270,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _artworkFallback(),
                            )
                          : _artworkFallback(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Track Information
                  Text(
                    track.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${track.artist}${track.album.isNotEmpty ? ' — ${track.album}' : ''}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Interactive Scrubber Slider
                  StreamBuilder<Duration>(
                    stream: playback.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final total = track.duration;
                      final maxMs = total.inMilliseconds <= 0
                          ? 1.0
                          : total.inMilliseconds.toDouble();
                      final currentVal = _isDragging
                          ? _dragValue
                          : position.inMilliseconds
                              .toDouble()
                              .clamp(0.0, maxMs);

                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4.5,
                              activeTrackColor: AppTheme.secondary,
                              inactiveTrackColor: AppTheme.surfaceHighlight,
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14),
                            ),
                            child: Slider(
                              value: currentVal.clamp(0.0, maxMs),
                              max: maxMs,
                              onChangeStart: (val) {
                                setState(() {
                                  _isDragging = true;
                                  _dragValue = val;
                                });
                              },
                              onChanged: (val) {
                                setState(() => _dragValue = val);
                              },
                              onChangeEnd: (val) async {
                                setState(() => _isDragging = false);
                                final seekTarget =
                                    Duration(milliseconds: val.round());
                                if (rooms.currentRoom != null) {
                                  await rooms.seekTo(seekTarget);
                                } else {
                                  await playback.seek(seekTarget);
                                }
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatDuration(
                                      Duration(milliseconds: currentVal.round())),
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  total.inMilliseconds > 0
                                      ? '-${formatDuration(total - Duration(milliseconds: currentVal.round()))}'
                                      : '--:--',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
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
                  const SizedBox(height: 20),
                  // Playback Control Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SkipControlButton(
                        icon: Icons.skip_previous_rounded,
                        size: 52,
                        iconSize: 32,
                        onPressed: playback.skipPrevious,
                      ),
                      const SizedBox(width: 24),
                      StreamBuilder<PlayerState>(
                        stream: playback.playerStateStream,
                        builder: (context, snapshot) {
                          final playing = snapshot.data?.playing ?? false;
                          return PlaybackControlButton(
                            isPlaying: playing,
                            size: 72,
                            iconSize: 42,
                            onTap: () async {
                              if (rooms.currentRoom != null) {
                                await rooms.togglePlayPause();
                              } else {
                                await playback.toggle();
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 24),
                      SkipControlButton(
                        icon: Icons.skip_next_rounded,
                        size: 52,
                        iconSize: 32,
                        onPressed: () async {
                          if (rooms.currentRoom != null) {
                            await rooms.skipNext();
                          } else {
                            await playback.skipNext();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Sync Telemetry HUD Card
                  ValueListenableBuilder<SyncStatus>(
                    valueListenable: sync.status,
                    builder: (context, status, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.surfaceBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatColumn(
                              label: 'CLOCK OFFSET',
                              value:
                                  '${timeSync.currentOffsetMs >= 0 ? '+' : ''}${timeSync.currentOffsetMs} ms',
                            ),
                            Container(
                              height: 32,
                              width: 1,
                              color: AppTheme.surfaceBorder,
                            ),
                            _StatColumn(
                              label: 'DRIFT',
                              value:
                                  '${status.driftMs >= 0 ? '+' : ''}${status.driftMs} ms',
                            ),
                            Container(
                              height: 32,
                              width: 1,
                              color: AppTheme.surfaceBorder,
                            ),
                            _StatColumn(
                              label: 'STATE',
                              value: switch (status.action) {
                                DriftAction.none => 'LOCKED',
                                DriftAction.warpFaster => 'RATE 1.05×',
                                DriftAction.warpSlower => 'RATE 0.95×',
                                DriftAction.hardSeek => 'HARD SEEK',
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _artworkFallback() => Container(
        width: 270,
        height: 270,
        decoration: const BoxDecoration(
          gradient: AppTheme.artworkFallbackGradient,
        ),
        child: const Icon(Icons.music_note_rounded,
            size: 96, color: Colors.white54),
      );
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
