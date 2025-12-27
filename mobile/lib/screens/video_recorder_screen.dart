// ABOUTME: Video recorder screen with modern UI design
// ABOUTME: Features top search bar, camera preview with grid, and bottom controls

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_countdown_overlay.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_top_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';

import '../widgets/video_recorder/video_recorder_camera_preview.dart';

class VideoRecorderScreen extends ConsumerStatefulWidget {
  const VideoRecorderScreen({super.key});

  @override
  ConsumerState<VideoRecorderScreen> createState() =>
      _VideoRecorderScreenState();
}

class _VideoRecorderScreenState extends ConsumerState<VideoRecorderScreen>
    with WidgetsBindingObserver {
  final double _previewRadius = 16.0;
  VineRecordingNotifier? _notifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize camera when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _notifier = ref.read(vineRecordingProvider.notifier);
      final success = await _notifier!.initialize(context: context);
      // If the user didn't give permission, we close the video recorder
      // screen because the user can't do anything anyway.
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera and microphone permissions are required to record videos.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        _notifier!.closeVideoRecorder(context);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(vineRecordingProvider.notifier).handleAppLifecycleState(state);
  }

  @override
  void dispose() {
    _notifier?.destroy();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            // Camera preview
            VideoRecorderCameraPreview(previewWidgetRadius: _previewRadius),

            // Top bar with close-button, clip-duration, and confirm-button
            const VideoRecorderTopBar(),

            // Bottom controls
            VideoRecorderBottomBar(previewWidgetRadius: _previewRadius),

            // Countdown overlay
            const VideoRecorderCountdownOverlay(),
          ],
        ),
      ),
    );
  }
}
