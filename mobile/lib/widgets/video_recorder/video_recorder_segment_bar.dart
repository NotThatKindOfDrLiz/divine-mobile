// ABOUTME: Widget that displays recording progress as a segmented bar
// ABOUTME: Shows filled segments for recorded clips with remaining space for more recording

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Displays a horizontal bar showing recording segments.
///
/// Each segment represents a recorded clip, with dividers between them.
/// Remaining space is shown as transparent, indicating available recording time.
class VideoRecorderSegmentBar extends ConsumerWidget {
  const VideoRecorderSegmentBar({super.key});

  static const _maxDuration = ClipManagerState.maxDuration;
  static const _dividerWidth = 2.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Expanded(
      child: SizedBox(
        height: 20,
        child: ClipRRect(
          borderRadius: .circular(8),
          child: Container(
            color: const Color(0xBEFFFFFF),
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  _buildSegments(ref, constraints),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegments(WidgetRef ref, BoxConstraints constraints) {
    final state = ref.watch(
      clipManagerProvider.select(
        (s) => (clips: s.clips, activeRecording: s.activeRecordingDuration),
      ),
    );

    final recordSegments = state.clips;
    final activeRecordingDuration = state.activeRecording;

    var used = Duration.zero;
    final segments = <Widget>[];

    // Build segments with Flexible based on duration
    for (int i = 0; i < recordSegments.length; i++) {
      if (used >= _maxDuration) break;

      final segment = recordSegments[i];
      final remaining = _maxDuration - used;
      final segmentDuration = segment.duration > remaining
          ? remaining
          : segment.duration;

      used += segmentDuration;

      // Add segment as Flexible with flex based on milliseconds
      segments.add(
        Flexible(
          flex: segmentDuration.inMilliseconds,
          child: Container(color: VineTheme.vineGreen),
        ),
      );

      // Add divider between segments
      if (i < recordSegments.length - 1 || activeRecordingDuration > .zero) {
        if (used < _maxDuration) {
          segments.add(
            SizedBox(
              width: _dividerWidth,
              child: Container(color: Colors.white),
            ),
          );
        }
      }
    }

    // Add active recording segment
    if (activeRecordingDuration > .zero && used < _maxDuration) {
      final remaining = _maxDuration - used;
      final activeDuration = activeRecordingDuration > remaining
          ? remaining
          : activeRecordingDuration;

      segments.add(
        Flexible(
          flex: activeDuration.inMilliseconds,
          child: Container(color: VineTheme.vineGreen),
        ),
      );

      used += activeDuration;
    }

    // Add remaining empty space as Flexible
    if (used < _maxDuration) {
      final remaining = _maxDuration - used;
      segments.add(
        Flexible(
          flex: remaining.inMilliseconds,
          child: Container(color: Colors.transparent),
        ),
      );
    }

    return Row(children: segments);
  }
}
