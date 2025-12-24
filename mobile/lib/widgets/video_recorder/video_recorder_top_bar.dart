// ABOUTME: Top bar widget for video recorder screen
// ABOUTME: Contains close button, segment-bar, and forward button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/utils/unified_logger.dart';

class VideoRecorderTopBar extends ConsumerWidget {
  const VideoRecorderTopBar({super.key});

  void _closeVideoRecorder(BuildContext context) {
    Log.info(
      '📹 X CANCEL - navigating away from camera',
      category: LogCategory.video,
    );
    // Try to pop if possible, otherwise go home
    // Camera can be reached via push (from FAB) or go (from ClipManager)
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      // No screen to pop to (navigated via go), go home instead
      context.goHome();
    }
  }

  void _openVideoEditor() {
    /// TODO: navigate to new video-editor
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vineRecordingProvider);
    final hasSegments = state.hasSegments;

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
                onPressed: () => _closeVideoRecorder(context),
              ),

              // Segment bar
              _buildSegmentBar(state),

              // Confirm button
              _buildActionButton(
                icon: Icons.arrow_forward,
                onPressed: hasSegments ? _openVideoEditor : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentBar(VineRecordingUIState state) {
    const maxDuration = Duration(milliseconds: 6300);
    const dividerWidth = 2.0;

    // Track used duration to ignore overflow segments
    Duration used = Duration.zero;

    final segments = <Widget>[];

    for (int i = 0; i < state.segments.length; i++) {
      final segment = state.segments[i];

      if (used >= maxDuration) break;

      final remaining = maxDuration - used;
      final segmentDuration = segment.duration > remaining
          ? remaining
          : segment.duration;

      used += segmentDuration;

      final fraction =
          segmentDuration.inMilliseconds / maxDuration.inMilliseconds;

      segments.add(
        Expanded(
          flex: (fraction * 1000).round(),
          child: Container(color: Colors.green),
        ),
      );

      // Divider (only if not at the end and more segments follow)
      if (i < state.segments.length - 1 && used < maxDuration) {
        segments.add(
          SizedBox(
            width: dividerWidth,
            child: Container(color: Colors.white),
          ),
        );
      }
    }

    // Add remaining empty space if not filled
    if (used < maxDuration) {
      final remainingFraction =
          (maxDuration - used).inMilliseconds / maxDuration.inMilliseconds;
      segments.add(
        Expanded(
          flex: (remainingFraction * 1000).round(),
          child: Container(color: Colors.transparent),
        ),
      );
    }

    return Expanded(
      child: SizedBox(
        height: 20,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: const Color(0xBEFFFFFF), // background
            child: Row(children: segments),
          ),
        ),
      ),
    );
  }

  /// Build action button for top bar
  Widget _buildActionButton({required IconData icon, VoidCallback? onPressed}) {
    final bool enabled = onPressed != null;

    return ClipRRect(
      borderRadius: .circular(20),
      child: BackdropFilter(
        enabled: !enabled,
        filter: .blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(enabled ? 255 : 166),
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
    );
  }
}
