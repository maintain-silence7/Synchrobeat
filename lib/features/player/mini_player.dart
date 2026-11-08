import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../player/playback_service.dart';
import '../vault/track.dart';

/// Docked player shown above the bottom navigation bar whenever a track is
/// loaded. Tap to open the full player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final playback = sl<PlaybackService>();
    return ValueListenableBuilder<Track?>(
      valueListenable: playback.currentTrack,
      builder: (context, track, _) {
        if (track == null) return const SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            border: const Border(
              top: BorderSide(color: AppTheme.surfaceBorder, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/player'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<Duration>(
                    stream: playback.positionStream,
                    builder: (context, snapshot) {
                      final total = track.duration.inMilliseconds;
                      final pos = snapshot.data?.inMilliseconds ?? 0;
                      final fraction =
                          total <= 0 ? 0.0 : (pos / total).clamp(0.0, 1.0);
                      return LinearProgressIndicator(
                        value: fraction,
                        minHeight: 2.5,
                        backgroundColor: AppTheme.surfaceHighlight,
                        color: AppTheme.secondary,
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                    child: Row(
                      children: [
                        _MiniArtwork(track: track),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StreamBuilder<PlayerState>(
                          stream: playback.playerStateStream,
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            return Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.primaryGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.35),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: playback.toggle,
                                  child: Center(
                                    child: Icon(
                                      playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 26,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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
  }
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) {
    final art = track.artworkPath;
    if (art != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(art),
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: AppTheme.artworkFallbackGradient,
        ),
        child: const Icon(Icons.music_note_rounded,
            size: 22, color: Colors.white70),
      );
}
