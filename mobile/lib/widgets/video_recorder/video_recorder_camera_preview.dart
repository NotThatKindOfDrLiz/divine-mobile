// ABOUTME: Camera preview widget with animated aspect ratio transitions and grid overlay
// ABOUTME: Handles tap-to-focus and displays rule-of-thirds grid during non-recording state

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/vine_recording_provider.dart';

/// Displays the camera preview with animated aspect ratio changes.
///
/// Includes a grid overlay for composition guidance and tap-to-focus functionality.
class VideoRecorderCameraPreview extends ConsumerStatefulWidget {
  const VideoRecorderCameraPreview({
    super.key,
    required this.previewWidgetRadius,
  });

  final double previewWidgetRadius;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _VideoRecorderCameraPreviewState();
}

class _VideoRecorderCameraPreviewState
    extends ConsumerState<VideoRecorderCameraPreview> {
  /// Handles tap gestures to set camera focus point.
  ///
  /// Converts tap position to normalized coordinates (0.0-1.0) for the camera.
  void _handleTapFocus(TapUpDetails details) {
    // TODO: Fix below
    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final size = renderBox.size;

    // Convert to normalized coordinates (0.0 - 1.0)
    final dx = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final dy = (localPosition.dy / size.height).clamp(0.0, 1.0);

    ref.read(vineRecordingProvider.notifier).setFocusPoint(Offset(dx, dy));
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(vineRecordingProvider.notifier);

    // Only rebuild when aspectRatio, showGrid or cameraSwitchCount changes
    final targetAspectRatio = ref.watch(
      vineRecordingProvider.select((state) => state.aspectRatio.value),
    );
    final cameraSensorAspectRatio = ref.watch(
      vineRecordingProvider.select((state) => state.cameraSensorAspectRatio),
    );
    final showGrid = ref.watch(
      vineRecordingProvider.select((state) => !state.isRecording),
    );
    final cameraSwitchCount = ref.watch(
      vineRecordingProvider.select((state) => state.cameraSwitchCount),
    );

    final previewWidget = notifier.previewWidget;

    return Center(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        tween: Tween<double>(begin: targetAspectRatio, end: targetAspectRatio),
        builder: (context, animatedAspectRatio, child) {
          return AspectRatio(
            aspectRatio: animatedAspectRatio,
            child: ClipRRect(
              clipBehavior: .hardEdge,
              borderRadius: .circular(widget.previewWidgetRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTapUp: _handleTapFocus,
                    child: FittedBox(
                      fit: .cover,
                      child: SizedBox(
                        key: ValueKey(
                          'Video-Recorder-Camera-$cameraSwitchCount',
                        ),
                        width: 100 / cameraSensorAspectRatio,
                        height: 100,
                        child: Stack(
                          children: [
                            // TODO (@hm21): Add a skeleton to the camera view
                            // that appears when the user switches cameras until
                            // the other camera loads.
                            Container(color: const Color(0xFF141414)),
                            ?previewWidget,
                          ],
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: showGrid ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeInOut,
                      child: CustomPaint(painter: _GridPainter()),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for grid overlay (rule of thirds)
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xBEFFFFFF)
      ..strokeWidth = 1;

    // Vertical lines
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
