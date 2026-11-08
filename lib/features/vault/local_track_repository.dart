import 'dart:async';
import 'dart:io';

import 'package:audiotags/audiotags.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/local/json_store.dart';
import 'track.dart';

class VaultFailure implements Exception {
  const VaultFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Offline-mode communal vault: audio files are copied into app storage and
/// metadata lives in a local JSON index. The public API mirrors what a
/// Supabase + R2 backed implementation will expose (list/upload/delete/watch).
class LocalTrackRepository extends ChangeNotifier {
  static const _indexFile = 'vault_tracks.json';
  final _uuid = const Uuid();

  JsonStore? _store;
  List<Track>? _cache;

  Future<JsonStore> get _s async => _store ??= await JsonStore.open();

  Future<List<Track>> listTracks() async {
    final cached = _cache;
    if (cached != null) return List.unmodifiable(cached);
    final store = await _s;
    final raw = await store.readList(_indexFile);
    final tracks = raw
        .whereType<Map>()
        .map((e) => Track.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => File(t.filePath).existsSync())
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cache = tracks;
    return List.unmodifiable(tracks);
  }

  Future<Track?> byId(String id) async {
    final tracks = await listTracks();
    for (final t in tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> _saveIndex(List<Track> tracks) async {
    _cache = List.of(tracks);
    await (await _s).write(_indexFile, tracks.map((t) => t.toJson()).toList());
    notifyListeners();
  }

  void _validateFile(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (!AppConstants.supportedAudioExtensions.contains(ext)) {
      throw VaultFailure(
        'Unsupported format ".$ext". Use MP3, M4A, WAV or FLAC.',
      );
    }
    final size = File(path).lengthSync();
    if (size > AppConstants.maxFileSizeBytes) {
      throw const VaultFailure('File exceeds the 100 MB vault limit.');
    }
  }

  /// Reads ID3/Vorbis metadata without importing the file. Falls back to
  /// file-name parsing ("Artist - Title") when tags are missing.
  Future<ParsedTrackMeta> readMetadata(String path) async {
    _validateFile(path);
    final fileName = p.basename(path);
    String? title;
    String? artist;
    String? album;
    final durationMs = await _probeDurationMs(path);
    Uint8List? artwork;
    String? artworkMime;

    try {
      final tag = await AudioTags.read(path);
      if (tag != null) {
        title = tag.title?.trim();
        artist = tag.trackArtist?.trim().isNotEmpty == true
            ? tag.trackArtist!.trim()
            : tag.albumArtist?.trim();
        album = tag.album?.trim();
        if (tag.pictures.isNotEmpty) {
          final pic = tag.pictures.first;
          artwork = Uint8List.fromList(pic.bytes);
          artworkMime = pic.mimeType == MimeType.png ? 'image/png' : 'image/jpeg';
        }
      }
    } catch (_) {
      // Tag read failed (corrupt tag / unsupported encoder) → fallbacks below.
    }

    if ((title == null || title.isEmpty)) {
      final base = p.basenameWithoutExtension(path);
      final dash = base.split(' - ');
      if (dash.length >= 2) {
        artist ??= dash.first.trim();
        title = dash.sublist(1).join(' - ').trim();
      } else {
        title = base;
      }
    }

    return ParsedTrackMeta(
      sourcePath: path,
      fileName: fileName,
      title: title,
      artist: (artist == null || artist.isEmpty) ? 'Unknown Artist' : artist,
      album: (album == null || album.isEmpty) ? 'Unknown Album' : album,
      durationMs: durationMs,
      artworkBytes: artwork,
      artworkMime: artworkMime,
    );
  }

  /// Decodes the file header through just_audio to get a reliable duration
  /// across MP3/M4A/WAV/FLAC, with the RIFF parser as a last resort for WAV.
  Future<int> _probeDurationMs(String path) async {
    try {
      final probe = AudioPlayer();
      try {
        await probe.setFilePath(path);
        final duration = probe.duration;
        if (duration != null && duration.inMilliseconds > 0) {
          return duration.inMilliseconds;
        }
      } finally {
        await probe.dispose();
      }
    } catch (_) {}
    if (p.extension(path).toLowerCase() == '.wav') {
      return _wavDurationMs(path) ?? 0;
    }
    return 0;
  }

  int? _wavDurationMs(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      if (bytes.length < 64) return null;
      // Locate the 'fmt ' and 'data' chunks.
      int findChunk(String id) {
        for (var i = 12; i < bytes.length - 8; i++) {
          if (bytes[i] == id.codeUnitAt(0) &&
              bytes[i + 1] == id.codeUnitAt(1) &&
              bytes[i + 2] == id.codeUnitAt(2) &&
              bytes[i + 3] == id.codeUnitAt(3)) {
            return i;
          }
        }
        return -1;
      }

      final fmt = findChunk('fmt ');
      final data = findChunk('data');
      if (fmt < 0 || data < 0) return null;
      // fmt chunk data starts at fmt+8: audioFormat(2) channels(2)
      // sampleRate(4) byteRate(4) → byteRate at fmt+8+8 = fmt+16.
      final byteRate = _u32(bytes, fmt + 16);
      final dataSize = _u32(bytes, data + 4);
      if (byteRate <= 0) return null;
      return ((dataSize / byteRate) * 1000).round();
    } catch (_) {
      return null;
    }
  }

  static int _u32(Uint8List bytes, int offset) {
    final data = bytes.buffer.asByteData();
    return data.getUint32(offset, Endian.little);
  }

  /// Copies the audio file (and optional artwork) into app storage and
  /// commits the track to the vault index.
  Future<Track> commitUpload({
    required ParsedTrackMeta meta,
    required String uploaderId,
    required String uploaderName,
    String? title,
    String? artist,
    String? album,
  }) async {
    _validateFile(meta.sourcePath);
    final store = await _s;
    final id = _uuid.v4();
    final ext = p.extension(meta.sourcePath).toLowerCase();
    final audioDir = await store.subdir('vault/audio');
    final artDir = await store.subdir('vault/art');
    final destPath = p.join(audioDir, '$id$ext');
    await File(meta.sourcePath).copy(destPath);

    String? artworkPath;
    if (meta.artworkBytes != null && meta.artworkBytes!.isNotEmpty) {
      final mime = meta.artworkMime ?? 'image/jpeg';
      final artExt = mime.contains('png') ? '.png' : '.jpg';
      artworkPath = p.join(artDir, '$id$artExt');
      await File(artworkPath).writeAsBytes(meta.artworkBytes!, flush: true);
    }

    final track = Track(
      id: id,
      title: (title ?? meta.title ?? p.basenameWithoutExtension(meta.fileName))
          .trim(),
      artist: (artist ?? meta.artist ?? 'Unknown Artist').trim(),
      album: (album ?? meta.album ?? 'Unknown Album').trim(),
      durationMs: meta.durationMs,
      filePath: destPath,
      artworkPath: artworkPath,
      fileSizeBytes: File(meta.sourcePath).lengthSync(),
      uploaderId: uploaderId,
      uploaderName: uploaderName,
      createdAt: DateTime.now(),
    );

    final existing = await listTracks();
    await _saveIndex([track, ...existing]);
    return track;
  }

  Future<void> deleteTrack(String id, {required String requesterId}) async {
    final tracks = await listTracks();
    final match = tracks.where((t) => t.id == id);
    if (match.isEmpty) return;
    final track = match.first;
    if (track.uploaderId != requesterId) {
      throw const VaultFailure('Only the uploader can remove this track.');
    }
    try {
      await File(track.filePath).delete();
    } catch (_) {}
    final art = track.artworkPath;
    if (art != null) {
      try {
        await File(art).delete();
      } catch (_) {}
    }
    await _saveIndex(tracks.where((t) => t.id != id).toList());
  }
}
