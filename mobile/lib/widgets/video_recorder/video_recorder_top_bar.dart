// ABOUTME: Top bar widget for video recorder screen
// ABOUTME: Contains close button, segment-bar, and forward button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_segment_bar.dart';

/// Top bar with close button, segment bar, and forward button.
class VideoRecorderTopBar extends ConsumerWidget {
  /// Creates a video recorder top bar widget.
  const VideoRecorderTopBar({super.key});

  static const Color _buttonColor = Color(0xFF101111);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoRecorderProvider.notifier);
    final hasClips = ref.watch(clipManagerProvider.select((s) => s.hasClips));
    final isRecording = ref.watch(
      videoRecorderProvider.select((s) => s.isRecording),
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
                label: 'Close video recorder',
                hidden: isRecording,
                backgroundColor: _buttonColor,
                onPressed: () => notifier.closeVideoRecorder(context),
              ),

              // Segment bar
              const VideoRecorderSegmentBar(),

              // Confirm button
              _buildActionButton(
                icon: Icons.arrow_forward,
                label: 'Continue to video editor',
                hidden: isRecording,
                backgroundColor: hasClips
                    ? VineTheme.tabIndicatorGreen
                    : _buttonColor,
                onPressed: hasClips
                    ? () => notifier.openVideoEditor(context)
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
    String? label,
  }) {
    final enabled = onPressed != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: hidden ? 0 : 1,
      curve: Curves.ease,
      child: Container(
        width: 48,
        height: 48,
        decoration: ShapeDecoration(
          color: backgroundColor.withAlpha(enabled ? 255 : 166),
          shape: RoundedRectangleBorder(borderRadius: .circular(20)),
          shadows: const [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 1,
              offset: Offset(1, 1),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(
            icon,
            color: Colors.white.withAlpha(enabled ? 255 : 64),
            size: 32,
          ),
          onPressed: onPressed,
          padding: .zero,
          tooltip: label,
        ),
      ),
    );
  }
}
