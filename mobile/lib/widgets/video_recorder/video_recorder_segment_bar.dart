// ABOUTME: Widget that displays recording progress as a segmented bar
// ABOUTME: Shows filled segments for recorded clips with remaining space for more recording

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Displays a horizontal bar showing recording segments.
///
/// Each segment represents a recorded clip, with dividers between them.
/// Remaining space is shown as transparent, indicating available recording time.
class VideoRecorderSegmentBar extends ConsumerWidget {
  const VideoRecorderSegmentBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordSegments = ref.watch(
      clipManagerProvider.select((state) => state.clips),
    );

    const maxDuration = Duration(milliseconds: 6_300);
    const dividerWidth = 2.0;

    // Track used duration to ignore overflow segments
    Duration used = Duration.zero;

    final segments = <Widget>[];

    for (int i = 0; i < recordSegments.length; i++) {
      final segment = recordSegments[i];

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
          child: Container(color: VineTheme.vineGreen),
        ),
      );

      // Divider (only if not at the end and more segments follow)
      if (i < recordSegments.length - 1 && used < maxDuration) {
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
}
