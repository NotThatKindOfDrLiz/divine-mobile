/// Extension on Duration for video editor time formatting.
extension VideoEditorTimeUtils on Duration {
  /// Formats duration as SS:MS (seconds:milliseconds).
  ///
  /// Example: Duration(seconds: 5, milliseconds: 730) → "05:73"
  String toVideoTime() {
    final seconds = inSeconds.toString().padLeft(2, '0');
    final milliseconds = (inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$seconds:$milliseconds';
  }
}