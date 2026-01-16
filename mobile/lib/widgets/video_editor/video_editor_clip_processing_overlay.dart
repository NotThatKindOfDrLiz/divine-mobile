// ABOUTME: Overlay widget showing processing indicator for video clips
// ABOUTME: Displays circular progress indicator while clip is being processed/rendered

import 'package:flutter/material.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:pro_video_editor/core/models/video/progress_model.dart';
import 'package:pro_video_editor/core/platform/platform_interface.dart';

class VideoEditorClipProcessingOverlay extends StatelessWidget {
  const VideoEditorClipProcessingOverlay({
    required this.clip,
    super.key,
    this.inactivePlaceholder,
    this.isProcessing = false,
  });

  /// The clip to show processing status for.
  final RecordingClip clip;
  final bool isProcessing;
  final Widget? inactivePlaceholder;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: isProcessing || clip.isProcessing
          ? ColoredBox(
              color: Color.fromARGB(140, 0, 0, 0),
              child: Center(
                // Without RepaintBoundary, the progress indicator repaints
                // the entire screen while it's running.
                child: RepaintBoundary(
                  child: StreamBuilder<ProgressModel>(
                    stream: ProVideoEditor.instance.progressStreamById(clip.id),
                    builder: (context, snapshot) {
                      final progress = snapshot.data?.progress ?? 0;
                      return _PartialCircleSpinner(progress: progress);
                    },
                  ),
                ),
              ),
            )
          : inactivePlaceholder ?? const SizedBox.shrink(),
    );
  }
}

/// Custom circular progress spinner matching Figma design.
/// Animates like a clock from 0 to 360 degrees based on progress.
/// Uses implicit animation for smooth transitions between progress values.
class _PartialCircleSpinner extends StatefulWidget {
  const _PartialCircleSpinner({required this.progress});

  final double progress;

  @override
  State<_PartialCircleSpinner> createState() => _PartialCircleSpinnerState();
}

class _PartialCircleSpinnerState extends State<_PartialCircleSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.progress,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(_PartialCircleSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _previousProgress = _animation.value;
      _animation = Tween<double>(
        begin: _previousProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(
            painter: _PartialCirclePainter(progress: _animation.value),
          ),
        );
      },
    );
  }
}

class _PartialCirclePainter extends CustomPainter {
  _PartialCirclePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle - the empty/remaining area
    final backgroundPaint = Paint()
      ..color = const Color(0xFF737778)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress pie slice - filled from center to edge like a clock
    final progressPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw filled pie slice from 0 to progress, starting from top (12 o'clock)
    const startAngle = -3.14159 / 2;
    final sweepAngle = 3.14159 * 2 * progress.clamp(0.0, 1.0);

    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true, // true = connect to center, creates filled pie slice
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_PartialCirclePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
