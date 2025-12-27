// ABOUTME: Bottom bar widget for video recorder screen
// ABOUTME: Contains flash, timer, record button, camera flip, and more options

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/vine_recording_provider.dart';

import 'video_recorder_more_sheet.dart';

class VideoRecorderBottomBar extends ConsumerWidget {
  const VideoRecorderBottomBar({super.key, required this.previewWidgetRadius});

  final double previewWidgetRadius;
  static const double _bottomBarHeight = 64;

  /// Show more options menu
  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101111),
      enableDrag: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: .vertical(top: .circular(32)),
      ),
      builder: (context) => const VideoRecorderMoreSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = ref.watch(
      vineRecordingProvider.select((p) => p.isRecording),
    );

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Stack(
          alignment: .bottomCenter,
          children: [
            /// Record button
            _buildRecordButton(ref, isRecording),

            /// BottomBar
            Stack(
              alignment: .bottomCenter,
              clipBehavior: .none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  ),
                  child: isRecording
                      ? const SizedBox.shrink()
                      : _buildActionButtons(context, ref),
                ),

                /// Helper widget which create a inner radius for the camera
                /// preview so long it's not recording.
                Positioned(
                  top: -previewWidgetRadius,
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    painter: _InvertedRadiusPainter(
                      color: Colors.black,
                      radius: previewWidgetRadius,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build record button
  Widget _buildRecordButton(WidgetRef ref, bool isRecording) {
    return Align(
      alignment: .bottomCenter,
      child: GestureDetector(
        onTap: ref.read(vineRecordingProvider.notifier).toggleRecording,
        onLongPressStart: (_) =>
            ref.read(vineRecordingProvider.notifier).startRecording(),
        onLongPressMoveUpdate: isRecording
            ? (details) => ref
                  .read(vineRecordingProvider.notifier)
                  .zoomByLongPressMove(details.localOffsetFromOrigin)
            : null,
        onLongPressUp: ref.read(vineRecordingProvider.notifier).stopRecording,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const .only(bottom: _bottomBarHeight + 20),
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            border: .all(color: Colors.white, width: 4),
            borderRadius: .circular(36),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.ease,
              width: isRecording ? 32 : 64,
              height: isRecording ? 32 : 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF44336),
                borderRadius: .circular(isRecording ? 6 : 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the action buttons
  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    final flashMode = ref.watch(
      vineRecordingProvider.select((p) => p.flashMode),
    );
    final timerDuration = ref.watch(
      vineRecordingProvider.select((p) => p.timerDuration),
    );
    final aspectRatio = ref.watch(
      vineRecordingProvider.select((p) => p.aspectRatio),
    );

    return Container(
      color: Colors.black,
      height: _bottomBarHeight,
      child: Row(
        crossAxisAlignment: .center,
        mainAxisAlignment: .spaceAround,
        children: [
          // Flash toggle
          _buildControlButton(
            icon: _getFlashIcon(flashMode),
            onPressed: ref.read(vineRecordingProvider.notifier).toggleFlash,
          ),

          // Timer toggle
          _buildControlButton(
            icon: timerDuration.icon,
            onPressed: ref.read(vineRecordingProvider.notifier).cycleTimer,
          ),

          // Aspect-Ratio
          _buildControlButton(
            icon: aspectRatio == .square
                ? Icons.crop_square
                : Icons.crop_portrait,
            onPressed: ref
                .read(vineRecordingProvider.notifier)
                .toggleAspectRatio,
          ),

          // Flip camera
          _buildControlButton(
            icon: Icons.cached_rounded,
            onPressed: ref.read(vineRecordingProvider.notifier).switchCamera,
          ),

          // More options
          _buildControlButton(
            icon: Icons.more_horiz,
            onPressed: () => _showMoreOptions(context),
          ),
        ],
      ),
    );
  }

  /// Build control button with optional label
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 32),
    );
  }

  /// Get flash icon based on mode
  IconData _getFlashIcon(FlashMode mode) {
    return switch (mode) {
      .off => Icons.flash_off,
      .torch => Icons.flash_on,
      .always => Icons.flash_on,
      .auto => Icons.flash_auto,
    };
  }
}

/// Custom painter for inverted radius at top-left and top-right corners
class _InvertedRadiusPainter extends CustomPainter {
  _InvertedRadiusPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Start from left side
    path.moveTo(0, 0);
    path.lineTo(0, radius);
    path.lineTo(radius, radius);

    // Draw left inverted corner (concave inward)
    path.quadraticBezierTo(0, radius, 0, 0);

    canvas.drawPath(path, paint);

    // Right side path
    final rightPath = Path();
    rightPath.moveTo(size.width, 0);
    rightPath.lineTo(size.width, radius);
    rightPath.lineTo(size.width - radius, radius);

    // Draw right inverted corner (concave inward)
    rightPath.quadraticBezierTo(size.width, radius, size.width, 0);

    canvas.drawPath(rightPath, paint);

    // Important to draw bottom 2px black rectangle which ensure there is no gap
    // to the bottom bar.
    final bottomRect = Rect.fromLTWH(0, radius, size.width, 2);
    canvas.drawRect(bottomRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
