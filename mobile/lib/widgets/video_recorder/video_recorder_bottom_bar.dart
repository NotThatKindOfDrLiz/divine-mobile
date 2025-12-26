// ABOUTME: Bottom bar widget for video recorder screen
// ABOUTME: Contains flash, timer, record button, camera flip, and more options

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/vine_recording_provider.dart';

class VideoRecorderBottomBar extends ConsumerWidget {
  const VideoRecorderBottomBar({
    super.key,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vineRecordingProvider);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Column(
          spacing: 20,
          children: [
            // Record button
            _buildRecordButton(state),
            SizedBox(
              height: 68,
              child: AnimatedSwitcher(
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
            ),
          ],
        ),
      ),
    );
  }

  /// Build record button
  Widget _buildRecordButton(VineRecordingUIState state) {
    return GestureDetector(
      onTapDown: (_) => onStartRecording(),
      onTapUp: (_) => onStopRecording(),
      onTapCancel: () => onStopRecording(),
      child: Container(
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
    );
  }

  Widget _buildActionButtons(WidgetRef ref, VineRecordingUIState state) {
    return Container(
      color: Colors.black,
      height: .infinity,
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
            icon: _getTimerIcon(state.timerDuration),
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
            onPressed: () async {
              final notifier = ref.read(vineRecordingProvider.notifier);
              await notifier.switchCamera();
            },
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

  IconData _getTimerIcon(TimerDuration mode) {
    return switch (mode) {
      .off => Icons.timer,
      .three => Icons.timer_3,
      .ten => Icons.timer_10,
    };
  }
}
