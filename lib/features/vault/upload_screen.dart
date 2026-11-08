import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../auth/auth_repository.dart';
import '../common/app_buttons.dart';
import 'local_track_repository.dart';
import 'track.dart';

/// Two-step upload flow: pick a file → review/edit parsed metadata →
/// commit. In demo mode the "upload" copies into local app storage; the same
/// metadata is what the R2 pre-signed PUT pipeline will consume in production.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late final LocalTrackRepository _repo;

  ParsedTrackMeta? _meta;
  bool _parsing = false;
  bool _saving = false;
  double _progress = 0;
  String? _error;

  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _albumController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = sl<LocalTrackRepository>();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _parsing = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.supportedAudioExtensions,
      );
      final path = result?.files.single.path;
      if (path == null) {
        setState(() => _parsing = false);
        return;
      }
      final meta = await _repo.readMetadata(path);
      if (!mounted) return;
      _titleController.text = meta.title ?? '';
      _artistController.text = meta.artist ?? '';
      _albumController.text = meta.album ?? '';
      setState(() {
        _meta = meta;
        _parsing = false;
      });
    } on VaultFailure catch (e) {
      setState(() {
        _error = e.message;
        _parsing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not read that file: $e';
        _parsing = false;
      });
    }
  }

  Future<void> _commit() async {
    final meta = _meta;
    final user = sl<AuthRepository>().currentUser;
    if (meta == null || user == null) return;

    setState(() {
      _saving = true;
      _progress = 0;
      _error = null;
    });

    final ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      setState(() {
        _progress = (_progress + 0.09).clamp(0.0, 0.92);
      });
    });

    try {
      await _repo.commitUpload(
        meta: meta,
        uploaderId: user.id,
        uploaderName: user.displayName,
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        album: _albumController.text.trim(),
      );
      ticker.cancel();
      if (!mounted) return;
      setState(() => _progress = 1);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) Navigator.of(context).pop(true);
    } on VaultFailure catch (e) {
      ticker.cancel();
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      ticker.cancel();
      setState(() {
        _saving = false;
        _error = 'Upload failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload to Vault'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppTheme.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (meta == null) ...[
                // Styled Upload Zone Container
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 40),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.surfaceBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_rounded,
                          size: 54,
                          color: AppTheme.primaryAccent,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Select an Audio Track',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose an audio file from your device to add it to the shared communal vault.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Audio Format Badges
                      Wrap(
                        spacing: 8,
                        children: ['MP3', 'M4A', 'WAV', 'FLAC']
                            .map(
                              (fmt) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceHighlight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  fmt,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.secondary,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 28),
                      PrimaryGradientButton(
                        onPressed: _parsing ? null : _pickFile,
                        label: _parsing ? 'Reading metadata…' : 'Choose Audio File',
                        isLoading: _parsing,
                        icon: const Icon(Icons.audio_file_rounded,
                            size: 20, color: Colors.white),
                        isFullWidth: false,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Track Preview Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      if (meta.artworkBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            Uint8List.fromList(meta.artworkBytes!),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: AppTheme.artworkFallbackGradient,
                          ),
                          child: const Icon(Icons.music_note_rounded,
                              size: 38, color: Colors.white70),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meta.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${formatDuration(Duration(milliseconds: meta.durationMs))}  •  Ready to upload',
                              style: const TextStyle(
                                color: AppTheme.secondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _saving ? null : _pickFile,
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  'Choose a different file',
                                  style: TextStyle(
                                    color: AppTheme.primaryAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'EDIT TRACK DETAILS',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Track Title',
                    prefixIcon: Icon(Icons.title_rounded,
                        color: AppTheme.textSecondary, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _artistController,
                  decoration: const InputDecoration(
                    labelText: 'Artist',
                    prefixIcon: Icon(Icons.person_outline_rounded,
                        color: AppTheme.textSecondary, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _albumController,
                  decoration: const InputDecoration(
                    labelText: 'Album',
                    prefixIcon: Icon(Icons.album_outlined,
                        color: AppTheme.textSecondary, size: 20),
                  ),
                ),
                const SizedBox(height: 28),
                if (_saving) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 10,
                      backgroundColor: AppTheme.surfaceHighlight,
                      color: AppTheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Uploading to vault… ${(100 * _progress).round()}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else
                  PrimaryGradientButton(
                    onPressed: _commit,
                    label: 'Commit to Vault',
                    icon: const Icon(Icons.cloud_done_rounded,
                        size: 20, color: Colors.white),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
