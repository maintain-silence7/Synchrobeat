import 'dart:io';

import 'package:equatable/equatable.dart';

class Track extends Equatable {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.filePath,
    required this.fileSizeBytes,
    required this.uploaderId,
    required this.uploaderName,
    required this.createdAt,
    this.artworkPath,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String filePath;
  final String? artworkPath;
  final int fileSizeBytes;
  final String uploaderId;
  final String uploaderName;
  final DateTime createdAt;

  bool get hasArtwork => artworkPath != null && File(artworkPath!).existsSync();

  Duration get duration => Duration(milliseconds: durationMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': durationMs,
        'filePath': filePath,
        'artworkPath': artworkPath,
        'fileSizeBytes': fileSizeBytes,
        'uploaderId': uploaderId,
        'uploaderName': uploaderName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Unknown Title',
        artist: json['artist'] as String? ?? 'Unknown Artist',
        album: json['album'] as String? ?? 'Unknown Album',
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        filePath: json['filePath'] as String,
        artworkPath: json['artworkPath'] as String?,
        fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
        uploaderId: json['uploaderId'] as String? ?? '',
        uploaderName: json['uploaderName'] as String? ?? 'Unknown',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  @override
  List<Object?> get props => [id];
}

class ParsedTrackMeta {
  const ParsedTrackMeta({
    required this.sourcePath,
    required this.fileName,
    this.title,
    this.artist,
    this.album,
    this.durationMs = 0,
    this.artworkBytes,
    this.artworkMime,
  });

  final String sourcePath;
  final String fileName;
  final String? title;
  final String? artist;
  final String? album;
  final int durationMs;
  final List<int>? artworkBytes;
  final String? artworkMime;
}
