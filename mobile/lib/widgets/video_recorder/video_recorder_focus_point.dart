// ABOUTME: Animated focus point indicator widget for camera tap-to-focus
// ABOUTME: Shows a circular indicator at tap location with scale and fade animations

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_recording_provider.dart';

class VideoRecorderFocusPoint extends ConsumerStatefulWidget {
  const VideoRecorderFocusPoint({super.key});

  @override
  ConsumerState<VideoRecorderFocusPoint> createState() =>
      _VideoRecorderFocusPointState();
}

class _VideoRecorderFocusPointState
    extends ConsumerState<VideoRecorderFocusPoint> {
  Offset _lastVisiblePosition = .zero;

  @override
  Widget build(BuildContext context) {
    final focusPoint = ref.watch(
      videoRecordingProvider.select((state) => state.focusPoint),
    );

    final isVisible = focusPoint != .zero;

    // Remember the last visible position for smooth fade out
    if (isVisible) {
      _lastVisiblePosition = focusPoint;
    }

    // Use last visible position when fading out
    final displayPosition = isVisible ? focusPoint : _lastVisiblePosition;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Convert normalized coordinates (0.0-1.0) to pixel coordinates
        final x = displayPosition.dx * constraints.maxWidth;
        final y = displayPosition.dy * constraints.maxHeight;

        // Size relative to container (since we're inside FittedBox)
        final indicatorSize = constraints.maxWidth * 0.08;

        return IgnorePointer(
          child: Stack(
            children: [
              Positioned(
                left: x - indicatorSize / 2,
                top: y - indicatorSize / 2,
                child: AnimatedOpacity(
                  opacity: isVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('Focus-Point-$focusPoint'),
                    duration: const Duration(milliseconds: 300),
                    tween: Tween(
                      begin: isVisible ? 1.2 : 1.0,
                      end: isVisible ? 1.0 : 0.8,
                    ),
                    curve: Curves.easeOutCubic,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: _buildFocusPoint(indicatorSize),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFocusPoint(double indicatorSize) {
    return Container(
      width: indicatorSize,
      height: indicatorSize,
      decoration: BoxDecoration(
        border: .all(
          color: const Color(0xFFFFFFFF),
          width: indicatorSize * 0.025,
        ),
        shape: .circle,
      ),
      child: Center(
        child: Container(
          width: indicatorSize * 0.05,
          height: indicatorSize * 0.05,
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            shape: .circle,
          ),
        ),
      ),
    );
  }
}
