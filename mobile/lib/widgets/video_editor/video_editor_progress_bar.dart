import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_editor_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';

class VideoProgressBar extends ConsumerWidget {
  const VideoProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segments = ref.watch(
      videoEditorProvider.select((state) => state.progressSegments),
    );

    return Container(
      height: 40,
      padding: const .symmetric(horizontal: 16),
      child: Row(children: _buildSegments(segments)),
    );
  }

  List<Widget> _buildSegments(List<ProgressSegment> segments) {
    final widgets = <Widget>[];

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final isFirst = i == 0;
      final isLast = i == segments.length - 1;

      widgets.add(
        Expanded(
          flex: segment.duration,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: segment.color,
              borderRadius: .horizontal(
                left: isFirst ? const .circular(999) : .zero,
                right: isLast ? const .circular(999) : .zero,
              ),
            ),
          ),
        ),
      );

      // Add gap between segments if not the last one
      if (i < segments.length - 1) {
        widgets.add(const SizedBox(width: 2.88));
      }
    }

    return widgets;
  }
}
