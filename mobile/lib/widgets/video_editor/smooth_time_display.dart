import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// A reusable smooth time display widget that interpolates video position
/// updates.
///
/// Uses a Ticker to provide smooth ~60 FPS updates between video player
/// position updates.
class SmoothTimeDisplay extends ConsumerStatefulWidget {
  /// Creates a smooth time display.
  const SmoothTimeDisplay({
    required this.isPlayingSelector,
    required this.currentPositionSelector,
    this.style,
    this.formatter,
    super.key,
  });

  /// Provider selector that returns whether video is currently playing
  final ProviderListenable<bool> isPlayingSelector;

  /// Provider selector that returns current video position
  final ProviderListenable<Duration> currentPositionSelector;

  /// Text style for the time display
  final TextStyle? style;

  /// Custom duration formatter. Defaults to 'SS.MS' format (e.g., "12.34")
  final String Function(Duration)? formatter;

  @override
  ConsumerState<SmoothTimeDisplay> createState() => _SmoothTimeDisplayState();
}

class _SmoothTimeDisplayState extends ConsumerState<SmoothTimeDisplay>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastKnownPosition = Duration.zero;
  DateTime? _lastUpdateTime;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    // Check if playing state changed
    final currentIsPlaying = ref.read(widget.isPlayingSelector);
    if (_isPlaying != currentIsPlaying) {
      _isPlaying = currentIsPlaying;
      if (_isPlaying) {
        _lastUpdateTime = DateTime.now();
      }
    }

    // Get latest position from provider
    final providerPosition = ref.read(widget.currentPositionSelector);

    // Update reference point if position changed significantly
    if ((providerPosition - _lastKnownPosition).abs() >
        const Duration(milliseconds: 50)) {
      _lastKnownPosition = providerPosition;
      _lastUpdateTime = DateTime.now();
    }

    // Rebuild to show interpolated time
    if (_isPlaying && mounted) {
      setState(() {});
    }
  }

  Duration get _displayPosition {
    if (!_isPlaying || _lastUpdateTime == null) {
      return _lastKnownPosition;
    }

    // Interpolate: add elapsed time since last update
    final elapsed = DateTime.now().difference(_lastUpdateTime!);
    return _lastKnownPosition + elapsed;
  }

  String _defaultFormatter(Duration duration) {
    final seconds = duration.inSeconds;
    final milliseconds = (duration.inMilliseconds % 1000) ~/ 10;
    return '$seconds.${milliseconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = widget.formatter ?? _defaultFormatter;
    final style =
        widget.style ??
        const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: .w800,
          letterSpacing: 0.1,
        );

    return Text(
      formatter(_displayPosition),
      style: style,
    );
  }
}
