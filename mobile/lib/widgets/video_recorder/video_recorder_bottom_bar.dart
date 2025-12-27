// ABOUTME: Bottom bar widget for video recorder screen
// ABOUTME: Contains flash, timer, record button, camera flip, and more options

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/vine_recording_provider.dart';

class VideoRecorderBottomBar extends ConsumerWidget {
  const VideoRecorderBottomBar({super.key, required this.previewWidgetRadius});

  final double previewWidgetRadius;

  final double _bottomBarHeight = 64;

  /// Show more options menu
  void _showMoreOptions() {
    /* TODO: Implement more options
     showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons., color: Colors.white),
              title: const Text(
                'test',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                ref.read(vineRecordingProvider.notifier).toggleGrid();
                Navigator.pop(context);
              },
            ),
            
          ],
        ),
      ),
    ); */
  }

  /// Start recording with optional timer
  Future<void> _startRecording(WidgetRef ref) async {
    final notifier = ref.read(vineRecordingProvider.notifier);
    await notifier.startRecording();
  }

  /// Stop recording
  Future<void> _stopRecording(WidgetRef ref) async {
    final notifier = ref.read(vineRecordingProvider.notifier);
    await notifier.stopSegment();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vineRecordingProvider);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Stack(
          alignment: .bottomCenter,
          children: [
            /// Record button
            _buildRecordButton(ref, state),

            /// BottomBar
            Stack(
              alignment: .bottomCenter,
              clipBehavior: .none,
              children: [
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 150),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  ),
                  child: state.isRecording
                      ? SizedBox.shrink()
                      : _buildActionButtons(ref, state),
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
  Widget _buildRecordButton(WidgetRef ref, VineRecordingUIState state) {
    return Align(
      alignment: .bottomCenter,
      child: GestureDetector(
        onTapDown: (_) => _startRecording(ref),
        onTapUp: (_) => _stopRecording(ref),
        onTapCancel: () => _stopRecording(ref),
        child: Container(
          margin: EdgeInsets.only(bottom: _bottomBarHeight + 20),
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            border: .all(color: Colors.white, width: 4),
            borderRadius: .circular(36),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: Duration(milliseconds: 250),
              curve: Curves.ease,
              width: state.isRecording ? 32 : 64,
              height: state.isRecording ? 32 : 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF44336),
                borderRadius: .circular(state.isRecording ? 6 : 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the action buttons
  Widget _buildActionButtons(WidgetRef ref, VineRecordingUIState state) {
    return Container(
      color: Colors.black,
      height: _bottomBarHeight,
      child: Row(
        crossAxisAlignment: .center,
        mainAxisAlignment: .spaceAround,
        children: [
          // Flash toggle
          _buildControlButton(
            icon: _getFlashIcon(state.flashMode),
            onPressed: ref.read(vineRecordingProvider.notifier).toggleFlash,
          ),

          // Timer toggle
          _buildControlButton(
            icon: state.timerDuration.icon,
            onPressed: ref.read(vineRecordingProvider.notifier).cycleTimer,
          ),

          // Aspect-Ratio
          _buildControlButton(
            icon: state.aspectRatio == .square
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
            onPressed: _showMoreOptions,
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
