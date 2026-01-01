import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'video_editor_icon_button.dart';

class VideoEditorTopBar extends ConsumerWidget {
  const VideoEditorTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      videoEditorProvider.select(
        (state) => (
          currentClipIndex: state.currentClipIndex,
          totalClips: state.totalClips,
        ),
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
          VideoEditorIconButton(
            icon: Icons.videocam,
            onTap: () {
              notifier.close();
              Navigator.of(context).pop();
            },
            semanticLabel: 'Close video editor',
          ),

          // Clip counter
          Text(
            '${state.currentClipIndex}/${state.totalClips}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: .w800,
              fontFeatures: const [.tabularFigures()],
            ),
          ),

          // Done button
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
