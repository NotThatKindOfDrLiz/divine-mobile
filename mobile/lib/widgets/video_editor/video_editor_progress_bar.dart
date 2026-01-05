// ABOUTME: Progress bar showing video clips as proportional segments
// ABOUTME: Each segment width reflects clip duration with rounded corners

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';

/// Displays a progress bar showing all video clips as segments.
class VideoProgressBar extends ConsumerWidget {
  /// Creates a video progress bar widget.
  const VideoProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.watch(clipManagerProvider.select((state) => state.clips));
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (
          currentClipIndex: s.currentClipIndex,
          isReordering: s.isReordering,
        ),
      ),
    );

    return Container(
      height: 40,
      padding: const .symmetric(horizontal: 16),
      child: Row(
        spacing: 3,
        children: _buildSegments(
          clips,
          state.currentClipIndex,
          state.isReordering,
        ),
      ),
    );
  }

  /// Builds segment widgets for each clip with proportional widths.
  List<Widget> _buildSegments(
    List<RecordingClip> clips,
    int currentClipIndex,
    bool isReordering,
  ) {
    return List.generate(clips.length, (i) {
      final clip = clips[i];
      final isFirst = i == 0;
      final isLast = i == clips.length - 1;
      final isCompleted = i < currentClipIndex;
      final isCurrent = i == currentClipIndex;
      final isReorderingClip = isReordering && isCurrent;

      // Determine color based on state
      final segmentColor = isReorderingClip
          ? const Color(0xFF27C58B)
          : isCompleted
          ? const Color(0xFF146346) // Green for completed
          : const Color(0xFF404040); // Gray for uncompleted

      return Expanded(
        flex: clip.duration.inMilliseconds,
        child: AnimatedContainer(
          duration: isReordering
              ? Duration.zero
              : const Duration(milliseconds: 100),
          height: 8,
          decoration: BoxDecoration(
            color: segmentColor,
            border: isReorderingClip
                ? Border.all(
                    color: const Color(0xFFEBDE3B),
                    width: 3,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  )
                : null,
            borderRadius: .horizontal(
              left: isFirst || isReorderingClip ? const .circular(999) : .zero,
              right: isLast || isReorderingClip ? const .circular(999) : .zero,
            ),
          ),
        ),
      );
    });
  }
}
