import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../core/local/json_store.dart';
import '../vault/local_track_repository.dart';
import '../vault/track.dart';

/// Seeds the offline vault with a small "starter pack" on first launch so the
/// app is immediately playable. The tracks are synthesized programmatically
/// (no copyrighted material) and written as PCM16 WAV files.
class DemoSeeder {
  DemoSeeder(this._tracks);

  static const _markerFile = 'demo_seeded.json';
  static const _sampleRate = 22050;

  final LocalTrackRepository _tracks;

  Future<void> seedIfEmpty() async {
    final store = await JsonStore.open();
    final marker = await store.readMap(_markerFile);
    if (marker['done'] == true) return;

    final existing = await _tracks.listTracks();
    if (existing.isNotEmpty) {
      await store.write(_markerFile, {'done': true});
      return;
    }

    final specs = <_DemoSpec>[
      const _DemoSpec(
        title: 'Neon Skyline',
        artist: 'Synthwave Collective',
        album: 'Midnight Circuit',
        bpm: 96,
        chords: [
          [57, 60, 64], // Am
          [53, 57, 60], // F
          [48, 52, 55], // C
          [55, 59, 62], // G
        ],
        bassRoots: [33, 29, 24, 31],
        seconds: 19,
      ),
      const _DemoSpec(
        title: 'Midnight Drive',
        artist: 'Vector Nine',
        album: 'Overdrive',
        bpm: 112,
        chords: [
          [50, 53, 57], // Dm
          [50, 53, 57],
          [46, 50, 53], // Bb
          [48, 52, 55], // C
        ],
        bassRoots: [26, 26, 34, 24],
        seconds: 17,
      ),
      const _DemoSpec(
        title: 'Ocean Protocol',
        artist: 'Lumen Field',
        album: 'Deep State',
        bpm: 80,
        chords: [
          [48, 52, 55, 59], // Cmaj7
          [45, 48, 52, 55], // Am7
          [41, 45, 48, 52], // Fmaj7
          [43, 47, 50, 55], // G
        ],
        bassRoots: [36, 33, 29, 31],
        seconds: 20,
      ),
    ];

    final tempDir = await store.subdir('demo_seed_tmp');
    for (var i = 0; i < specs.length; i++) {
      final spec = specs[i];
      final samples = _render(spec);
      final wavPath = '$tempDir${Platform.pathSeparator}seed_$i.wav';
      await File(wavPath).writeAsBytes(_toWav(samples));
      final meta = ParsedTrackMeta(
        sourcePath: wavPath,
        fileName: '${spec.title}.wav',
        title: spec.title,
        artist: spec.artist,
        album: spec.album,
        durationMs: (samples.length * 1000) ~/ _sampleRate,
      );
      try {
        await _tracks.commitUpload(
          meta: meta,
          uploaderId: 'synchrobeat-starter',
          uploaderName: 'SynchroBeat',
          title: spec.title,
          artist: spec.artist,
          album: spec.album,
        );
      } finally {
        try {
          await File(wavPath).delete();
        } catch (_) {}
      }
    }

    await store.write(_markerFile, {'done': true});
  }

  static double _freq(int midi) => 440.0 * pow(2.0, (midi - 69) / 12.0);

  static List<double> _render(_DemoSpec spec) {
    final totalSamples = spec.seconds * _sampleRate;
    final out = List<double>.filled(totalSamples, 0.0);
    final beatSec = 60.0 / spec.bpm;
    final stepSec = beatSec / 2; // 8th notes
    final totalSteps = (spec.seconds / stepSec).floor();

    for (var step = 0; step < totalSteps; step++) {
      final chord = spec.chords[(step ~/ 8) % spec.chords.length];
      // Arpeggiate the chord in eighth notes.
      final noteMidi = chord[step % chord.length] + 12;
      final f = _freq(noteMidi);
      final start = (step * stepSec * _sampleRate).round();
      final noteLen = (stepSec * _sampleRate * 0.9).round();
      for (var i = 0; i < noteLen && start + i < totalSamples; i++) {
        final t = i / _sampleRate;
        final env = exp(-4.0 * t) * min(1.0, t * 60); // fast attack, decay
        final tone = 0.62 * sin(2 * pi * f * t) +
            0.28 * sin(2 * pi * f * 2 * t) +
            0.12 * sin(2 * pi * f * 3 * t);
        out[start + i] += tone * env * 0.5;
      }
      // Bass on each beat.
      if (step.isEven) {
        final bassMidi = spec.bassRoots[(step ~/ 8) % spec.bassRoots.length];
        final bf = _freq(bassMidi);
        final bStart = start;
        final bLen = (beatSec * _sampleRate * 0.95).round();
        for (var i = 0; i < bLen && bStart + i < totalSamples; i++) {
          final t = i / _sampleRate;
          final env = exp(-1.6 * t) * min(1.0, t * 80);
          out[bStart + i] += 0.55 * sin(2 * pi * bf * t) * env;
        }
      }
    }

    // Slow pad underneath (whole-note chords).
    final padStepSec = spec.seconds / spec.chords.length;
    for (var c = 0; c < spec.chords.length; c++) {
      final start = (c * padStepSec * _sampleRate).round();
      final len = (padStepSec * _sampleRate).round();
      for (final midi in spec.chords[c]) {
        final f = _freq(midi);
        for (var i = 0; i < len && start + i < totalSamples; i++) {
          final t = i / _sampleRate;
          final fade = min(1.0, min(t, (padStepSec - t)) / 0.6).clamp(0.0, 1.0);
          out[start + i] +=
              0.16 * (sin(2 * pi * f * t) + 0.6 * sin(2 * pi * f * 1.005 * t)) * fade;
        }
      }
    }

    // Gentle master soft-clip.
    for (var i = 0; i < out.length; i++) {
      out[i] = tanh(out[i] * 1.1) * 0.8;
    }
    return out;
  }

  static double tanh(double x) {
    final e = exp(2 * x);
    return (e - 1) / (e + 1);
  }

  static Uint8List _toWav(List<double> samples) {
    final dataSize = samples.length * 2;
    final bytes = Uint8List(44 + dataSize);
    final bd = ByteData.view(bytes.buffer);

    void writeStr(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes[offset + i] = s.codeUnitAt(i);
      }
    }

    writeStr(0, 'RIFF');
    bd.setUint32(4, 36 + dataSize, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little); // PCM chunk size
    bd.setUint16(20, 1, Endian.little); // PCM format
    bd.setUint16(22, 1, Endian.little); // mono
    bd.setUint32(24, _sampleRate, Endian.little);
    bd.setUint32(28, _sampleRate * 2, Endian.little); // byte rate
    bd.setUint16(32, 2, Endian.little); // block align
    bd.setUint16(34, 16, Endian.little); // bits per sample
    writeStr(36, 'data');
    bd.setUint32(40, dataSize, Endian.little);

    var offset = 44;
    for (final sample in samples) {
      final v = (sample * 32767).round().clamp(-32768, 32767);
      bd.setInt16(offset, v, Endian.little);
      offset += 2;
    }
    return bytes;
  }
}

class _DemoSpec {
  const _DemoSpec({
    required this.title,
    required this.artist,
    required this.album,
    required this.bpm,
    required this.chords,
    required this.bassRoots,
    required this.seconds,
  });

  final String title;
  final String artist;
  final String album;
  final int bpm;
  final List<List<int>> chords;
  final List<int> bassRoots;
  final int seconds;
}

