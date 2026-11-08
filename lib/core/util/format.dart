String formatDuration(Duration duration) {
  if (duration.inMilliseconds <= 0) return '--:--';
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1)} MB';
}
