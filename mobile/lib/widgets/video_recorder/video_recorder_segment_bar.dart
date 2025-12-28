// ABOUTME: Widget that displays recording progress as a segmented bar
// ABOUTME: Shows filled segments for recorded clips with remaining space for more recording

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Displays a horizontal bar showing recording segments.
///
/// Each segment represents a recorded clip, with dividers between them.
/// Remaining space is shown as transparent, indicating available recording time.
class VideoRecorderSegmentBar extends ConsumerWidget {
  const VideoRecorderSegmentBar({super.key});

  final _maxDuration = const Duration(milliseconds: 6_300);
  final _dividerWidth = 2.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordSegments = ref.watch(
      clipManagerProvider.select((state) => state.clips),
    );
    final activeRecordingDuration = ref.watch(
      clipManagerProvider.select((state) => state.activeRecordingDuration),
    );

    return Expanded(
      child: SizedBox(
        height: 20,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: const Color(0xBEFFFFFF),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Track used duration to ignore overflow segments
                Duration used = Duration.zero;
                final segments = <Widget>[];

                // First pass: count dividers
                int dividerCount = 0;
                for (int i = 0; i < recordSegments.length; i++) {
                  if (used >= _maxDuration) break;

                  final segment = recordSegments[i];
                  final remaining = _maxDuration - used;
                  final segmentDuration = segment.duration > remaining
                      ? remaining
                      : segment.duration;
                  used += segmentDuration;

                  if ((i < recordSegments.length - 1 ||
                          activeRecordingDuration > Duration.zero) &&
                      used < _maxDuration) {
                    dividerCount++;
                  }
                }

                // Calculate available width for segments (excluding dividers)
                final totalDividerWidth = dividerCount * _dividerWidth;
                final availableWidthForSegments =
                    constraints.maxWidth - totalDividerWidth;

                // Reset and build actual segments
                used = Duration.zero;
                segments.clear();

                for (int i = 0; i < recordSegments.length; i++) {
                  final segment = recordSegments[i];

                  if (used >= _maxDuration) break;

                  final remaining = _maxDuration - used;
                  final segmentDuration = segment.duration > remaining
                      ? remaining
                      : segment.duration;

                  used += segmentDuration;

                  final widthFraction =
                      segmentDuration.inMilliseconds /
                      _maxDuration.inMilliseconds;

                  segments.add(
                    SizedBox(
                      width: availableWidthForSegments * widthFraction,
                      child: Container(color: VineTheme.vineGreen),
                    ),
                  );

                  // Divider (only if not at the end and more segments follow or if recording)
                  if ((i < recordSegments.length - 1 ||
                          activeRecordingDuration > Duration.zero) &&
                      used < _maxDuration) {
                    segments.add(
                      SizedBox(
                        width: _dividerWidth,
                        child: Container(color: Colors.white),
                      ),
                    );
                  }
                }

                // Add active recording segment with smooth animation
                if (activeRecordingDuration > Duration.zero &&
                    used < _maxDuration) {
                  final remaining = _maxDuration - used;
                  final activeDuration = activeRecordingDuration > remaining
                      ? remaining
                      : activeRecordingDuration;

                  final widthFraction =
                      activeDuration.inMilliseconds /
                      _maxDuration.inMilliseconds;

                  segments.add(
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.linear,
                      tween: Tween(begin: widthFraction, end: widthFraction),
                      builder: (context, value, child) {
                        return SizedBox(
                          width: availableWidthForSegments * value,
                          child: Container(
                            color: VineTheme.vineGreen.withOpacity(0.8),
                          ),
                        );
                      },
                    ),
                  );

                  used += activeDuration;
                }

                // Add remaining empty space if not filled
                final usedFraction =
                    used.inMilliseconds / _maxDuration.inMilliseconds;
                final remainingWidth =
                    availableWidthForSegments * (1 - usedFraction);

                if (remainingWidth > 0) {
                  segments.add(
                    SizedBox(
                      width: remainingWidth,
                      child: Container(color: Colors.transparent),
                    ),
                  );
                }

                return Row(children: segments);
              },
            ),
          ),
        ),
      ),
    );
  }
}
