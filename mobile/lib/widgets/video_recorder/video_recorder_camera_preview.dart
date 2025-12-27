import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/vine_recording_provider.dart';

class VideoRecorderCameraPreview extends ConsumerWidget {
  const VideoRecorderCameraPreview({
    super.key,
    required this.previewWidgetRadius,
  });

  final double previewWidgetRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(vineRecordingProvider.notifier);

    // Only rebuild when aspectRatio, showGrid or cameraSwitchCount changes
    final targetAspectRatio = ref.watch(
      vineRecordingProvider.select((state) => state.aspectRatio.value),
    );
    final showGrid = ref.watch(
      vineRecordingProvider.select((state) => state.showGrid),
    );
    final cameraSwitchCount = ref.watch(
      vineRecordingProvider.select((state) => state.cameraSwitchCount),
    );

    final previewWidget = notifier.previewWidget;
    final cameraAspectRatio = notifier.cameraAspectRatio;

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
              borderRadius: .circular(previewWidgetRadius),
              child: CustomPaint(
                foregroundPainter: showGrid ? _GridPainter() : null,
                child: FittedBox(
                  fit: .cover,
                  child: SizedBox(
                    key: ValueKey('Video-Recorder-Camera-$cameraSwitchCount'),
                    width: 100,
                    height: 100 / cameraAspectRatio,
                    child: previewWidget,
                  ),
                ),
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
