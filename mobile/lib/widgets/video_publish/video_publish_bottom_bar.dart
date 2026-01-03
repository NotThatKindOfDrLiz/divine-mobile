// ABOUTME: Bottom control bar for video publish screen
// ABOUTME: Contains play/pause, mute buttons and time display

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom control bar with playback controls and time display.
class VideoPublishBottomBar extends ConsumerStatefulWidget {
  /// Creates a video publish bottom bar.
  const VideoPublishBottomBar({super.key});

  @override
  ConsumerState<VideoPublishBottomBar> createState() =>
      _VideoPublishBottomBarState();
}

class _VideoPublishBottomBarState extends ConsumerState<VideoPublishBottomBar> {
  bool _isPlaying = true;
  bool _isMuted = false;
  final Duration _currentPosition = const Duration(
    seconds: 4,
    milliseconds: 870,
  );
  final Duration _totalDuration = const Duration(seconds: 5, milliseconds: 730);

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    final milliseconds = (duration.inMilliseconds % 1000) ~/ 10;
    return '$seconds.${milliseconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left controls
            Row(
              spacing: 16,
              children: [
                // Pause/Play button
                _buildIconButton(
                  icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                  onTap: () {
                    setState(() {
                      _isPlaying = !_isPlaying;
                    });
                  },
                ),
                // Mute button
                _buildIconButton(
                  icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                  onTap: () {
                    setState(() {
                      _isMuted = !_isMuted;
                    });
                  },
                ),
              ],
            ),
            // Time display
            Row(
              spacing: 8,
              children: [
                Text(
                  _formatDuration(_currentPosition),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
                Text(
                  '/',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
                Text(
                  '${_formatDuration(_totalDuration)}s',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a circular icon button with consistent styling.
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF101111),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(1, 1),
              blurRadius: 1,
            ),
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0.4, 0.4),
              blurRadius: 0.6,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
