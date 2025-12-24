// ABOUTME: Video recorder screen with modern UI design
// ABOUTME: Features top search bar, camera preview with grid, and bottom controls

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_top_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';

class VideoRecorderScreen extends ConsumerStatefulWidget {
  const VideoRecorderScreen({super.key});

  @override
  ConsumerState<VideoRecorderScreen> createState() =>
      _VideoRecorderScreenState();
}

class _VideoRecorderScreenState extends ConsumerState<VideoRecorderScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize camera when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vineRecordingProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vineRecordingProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: .light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: .expand,
          children: [
            // Camera preview (full screen)
            _buildCameraPreview(state),

            // Top bar with close-button, clip-duration, and confirm-button
            VideoRecorderTopBar(),

            // Bottom controls
            VideoRecorderBottomBar(
              onStartRecording: _startRecording,
              onStopRecording: _stopRecording,
            ),

            // Countdown overlay
            if (state.countdownValue != null)
              _buildCountdownOverlay(state.countdownValue!),
          ],
        ),
      ),
    );
  }

  /// Build camera preview
  Widget _buildCameraPreview(VineRecordingUIState state) {
    if (!state.isCameraInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // Use the actual camera preview from vine recording provider
    final notifier = ref.read(vineRecordingProvider.notifier);

    return Center(
      child: AspectRatio(
        aspectRatio: state.aspectRatio.value,
        child: ClipRRect(
          clipBehavior: .hardEdge,
          borderRadius: .circular(16),
          child: CustomPaint(
            foregroundPainter: state.showGrid ? GridPainter() : null,
            // TODO: Fix aspect ratio
            child: notifier.previewWidget,
          ),
        ),
      ),
    );
  }

  /// Build countdown overlay
  Widget _buildCountdownOverlay(int countdown) {
    return Container(
      color: const Color(0xB3000000),
      child: Center(
        child: Text(
          countdown.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 100,
            fontWeight: .bold,
          ),
        ),
      ),
    );
  }

  /// Start recording with optional timer
  Future<void> _startRecording() async {
    final notifier = ref.read(vineRecordingProvider.notifier);
    final state = ref.read(vineRecordingProvider);

    // Handle timer countdown
    if (state.timerDuration != TimerDuration.off) {
      final seconds = state.timerDuration == TimerDuration.three ? 3 : 10;

      for (int i = seconds; i > 0; i--) {
        notifier.startCountdown(i);
        await Future.delayed(const Duration(seconds: 1));
      }

      notifier.clearCountdown();
    }

    // Start recording
    await notifier.startRecording();
  }

  /// Stop recording
  Future<void> _stopRecording() async {
    final notifier = ref.read(vineRecordingProvider.notifier);
    await notifier.stopSegment();
  }
}

/// Custom painter for grid overlay (rule of thirds)
class GridPainter extends CustomPainter {
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
