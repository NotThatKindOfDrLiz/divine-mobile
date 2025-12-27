// ABOUTME: Top bar widget for video recorder screen
// ABOUTME: Contains close button, segment-bar, and forward button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_segment_bar.dart';

class VideoRecorderTopBar extends ConsumerWidget {
  const VideoRecorderTopBar({super.key});

  final Color _buttonColor = const Color(0xFF101111);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSegments = ref.watch(
      vineRecordingProvider.select((state) => state.hasSegments),
    );
    final isRecording = ref.watch(
      vineRecordingProvider.select((state) => state.isRecording),
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const .all(16),
          child: Row(
            spacing: 16,
            children: [
              // Close button
              _buildActionButton(
                icon: Icons.close,
                hidden: isRecording,
                backgroundColor: _buttonColor,
                onPressed: () => ref
                    .read(vineRecordingProvider.notifier)
                    .closeVideoRecorder(context),
              ),

              // Segment bar
              const VideoRecorderSegmentBar(),

              // Confirm button
              _buildActionButton(
                icon: Icons.arrow_forward,
                hidden: isRecording,
                backgroundColor: hasSegments
                    ? VineTheme.vineGreen
                    : _buttonColor,
                onPressed: hasSegments
                    ? ref.read(vineRecordingProvider.notifier).openVideoEditor
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build action button for top bar
  Widget _buildActionButton({
    required IconData icon,
    required Color backgroundColor,
    bool hidden = false,
    VoidCallback? onPressed,
  }) {
    final bool enabled = onPressed != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: hidden ? 0 : 1,
      curve: Curves.ease,
      child: ClipRRect(
        borderRadius: .circular(20),
        child: BackdropFilter(
          enabled: !enabled,
          filter: .blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: backgroundColor.withAlpha(enabled ? 255 : 166),
              borderRadius: .circular(20),
            ),
            child: IconButton(
              icon: Icon(
                icon,
                color: Colors.white.withAlpha(enabled ? 255 : 64),
                size: 32,
              ),
              onPressed: onPressed,
              padding: .zero,
            ),
          ),
        ),
      ),
    );
  }
}
