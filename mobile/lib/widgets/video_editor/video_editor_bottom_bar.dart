// ABOUTME: Bottom bar with playback controls and time display
// ABOUTME: Play/pause, mute, and options buttons with formatted duration

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/video_editor/video_editor_icon_button.dart';
import 'package:openvine/widgets/video_editor/video_time_display.dart';

/// Bottom bar with playback controls and time display.
class VideoEditorBottomBar extends ConsumerWidget {
  /// Creates a video editor bottom bar widget.
  const VideoEditorBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalDuration = ref.watch(
      clipManagerProvider.select((state) => state.totalDuration),
    );
    final state = ref.watch(
      videoEditorProvider.select(
        (state) => (
          isPlaying: state.isPlaying,
          isEditing: state.isEditing,
          isReordering: state.isReordering,
          isMuted: state.isMuted,
        ),
      ),
    );
    final notifier = ref.read(videoEditorProvider.notifier);

    return Container(
      height: 80,
      padding: const .symmetric(horizontal: 16, vertical: 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: state.isReordering
            ? _buildClipRemoveButton()
            : Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  // Control buttons
                  Row(
                    spacing: 16,
                    children: [
                      VideoEditorIconButton(
                        icon: state.isPlaying ? Icons.pause : Icons.play_arrow,
                        onTap: notifier.togglePlayPause,
                        semanticLabel: 'Play or pause video',
                      ),
                      if (state.isEditing)
                        VideoEditorIconButton(
                          icon: Icons.cut_outlined,
                          onTap: () {
                            /// TODO(@hm21): Handle crop
                          },
                          semanticLabel: 'Crop',
                        )
                      else ...[
                        VideoEditorIconButton(
                          icon: state.isMuted
                              ? Icons.volume_off
                              : Icons.volume_up,
                          onTap: notifier.toggleMute,
                          semanticLabel: 'Mute or unmute audio',
                        ),
                        VideoEditorIconButton(
                          icon: Icons.more_horiz,
                          onTap: () => notifier.showMoreOptions(context),
                          semanticLabel: 'More options',
                        ),
                      ],
                    ],
                  ),

                  // Time display
                  VideoTimeDisplay(
                    isPlayingSelector: videoEditorProvider.select(
                      (s) => s.isPlaying,
                    ),
                    currentPositionSelector: videoEditorProvider.select(
                      (s) => s.currentPosition,
                    ),
                    totalDuration: totalDuration,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildClipRemoveButton() {
    return Align(
      child: Container(
        padding: const .all(8),
        decoration: ShapeDecoration(
          color: const Color(0xFF2D0000) /* error-error-container */,
          shape: RoundedRectangleBorder(
            borderRadius: .circular(20),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 1,
              offset: Offset(1, 1),
            ),
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 0.60,
              offset: Offset(0.40, 0.40),
            ),
          ],
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Color(0xFFF44336),
          size: 32,
        ),
      ),
    );
  }
}
