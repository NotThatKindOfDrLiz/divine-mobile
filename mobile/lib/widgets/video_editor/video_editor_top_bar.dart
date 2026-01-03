// ABOUTME: Top bar with close, clip counter, and done buttons
// ABOUTME: Displays current clip position and total clip count

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_icon_button.dart';

/// Top bar with close button, clip counter, and done button.
class VideoEditorTopBar extends ConsumerWidget {
  /// Creates a video editor top bar widget.
  const VideoEditorTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalClips = ref.watch(
      clipManagerProvider.select((state) => state.clips.length),
    );
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (currentClipIndex: s.currentClipIndex, isEditing: s.isEditing),
      ),
    );
    final notifier = ref.read(videoEditorProvider.notifier);

    return Container(
      height: 80,
      padding: const .symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: .spaceBetween,
        children: [
          // Close/Back button
          if (state.isEditing)
            VideoEditorIconButton(
              icon: Icons.close,
              onTap: () {
                ref.read(videoEditorProvider.notifier).stopClipEditing();
              },
              semanticLabel: 'Close video editor',
            )
          else
            VideoEditorIconButton(
              icon: Icons.videocam,
              onTap: () {
                notifier.close();
                Navigator.of(context).pop();
              },
              semanticLabel: 'Go back to camera',
            ),

          // Clip counter
          Text(
            '${state.currentClipIndex + 1}/$totalClips',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: .w800,
              fontFeatures: [.tabularFigures()],
            ),
          ),

          // Done button
          if (state.isEditing)
            VideoEditorIconButton(
              icon: Icons.more_horiz,
              onTap: () {
                // TODO(@hm21): Handle mroe
              },
              semanticLabel: 'More',
            )
          else
            VideoEditorIconButton(
              icon: Icons.arrow_forward,
              backgroundColor: const Color(0xFF27C58B),
              onTap: () {
                notifier.done();
                Navigator.of(context).pop();
              },
              semanticLabel: 'Done editing',
            ),
        ],
      ),
    );
  }
}
