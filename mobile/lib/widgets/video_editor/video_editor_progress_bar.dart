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
    final currentClipIndex = ref.watch(
      videoEditorProvider.select((state) => state.currentClipIndex),
    );

    return Container(
      height: 40,
      padding: const .symmetric(horizontal: 16),
      child: Row(children: _buildSegments(clips, currentClipIndex)),
    );
  }

  /// Builds segment widgets for each clip with proportional widths.
  List<Widget> _buildSegments(List<RecordingClip> clips, int currentClipIndex) {
    final widgets = <Widget>[];

    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final isFirst = i == 0;
      final isLast = i == clips.length - 1;
      final isCompleted = i < currentClipIndex;

      widgets.add(
        Expanded(
          flex: clip.duration.inMilliseconds,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: 8,
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFF146346)
                  : const Color(0xFF404040),
              borderRadius: .horizontal(
                left: isFirst ? const .circular(999) : .zero,
                right: isLast ? const .circular(999) : .zero,
              ),
            ),
          ),
        ),
      );

      // Add gap between segments if not the last one
      if (i < clips.length - 1) {
        widgets.add(const SizedBox(width: 2.88));
      }
    }

    return widgets;
  }
}
