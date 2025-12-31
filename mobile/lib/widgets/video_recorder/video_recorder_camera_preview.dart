// ABOUTME: Camera preview widget with animated aspect ratio transitions and grid overlay
// ABOUTME: Handles tap-to-focus and displays rule-of-thirds grid during non-recording state

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_recording_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_camera_placeholder.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_focus_point.dart';

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
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      videoRecordingProvider.select(
        (s) => (
          aspectRatio: s.aspectRatio.value,
          sensorAspectRatio: s.cameraSensorAspectRatio,
          showGrid: !s.isRecording,
          cameraSwitchCount: s.cameraSwitchCount,
          isCameraInitialized: s.isCameraInitialized,
        ),
      ),
    );

    final previewWidget = ref
        .read(videoRecordingProvider.notifier)
        .previewWidget;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: AspectRatio(
          aspectRatio: state.aspectRatio,
          child: ClipRRect(
            clipBehavior: .hardEdge,
            borderRadius: .circular(widget.previewWidgetRadius),
            child: Stack(
              fit: .expand,
              children: [
                FittedBox(
                  fit: .cover,
                  child: SizedBox(
                    key: ValueKey(
                      'Video-Recorder-Camera-${state.cameraSwitchCount}',
                    ),
                    width: 100 / state.sensorAspectRatio,
                    height: 100,
                    child: Stack(
                      children: [
                        if (state.isCameraInitialized && previewWidget != null)
                          FittedBox(
                            fit: .cover,
                            child: SizedBox(
                              key: ValueKey(
                                'Video-Recorder-Camera-${state.cameraSwitchCount}',
                              ),
                              width: 100 / state.sensorAspectRatio,
                              height: 100,
                              child: Stack(
                                children: [
                                  /// Skeleton when switching camera
                                  Container(color: const Color(0xFF141414)),

                                  /// Preview widget
                                  previewWidget,

                                  /// Focus Point
                                  const VideoRecorderFocusPoint(),
                                ],
                              ),
                            ),
                          )
                        else
                          VideoRecorderCameraPlaceholder(),
                        IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: state.showGrid ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.easeInOut,
                            child: CustomPaint(painter: _GridPainter()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: state.showGrid ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeInOut,
                    child: CustomPaint(painter: _GridPainter()),
                  ),
                ),
              ],
            ),
          ),
        ),
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
