// ABOUTME: Bottom bar with playback controls and time display
// ABOUTME: Play/pause, mute, and options buttons with formatted duration

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_icon_button.dart';

/// Bottom bar with playback controls and time display.
class VideoEditorBottomBar extends ConsumerWidget {
  /// Creates a video editor bottom bar widget.
  const VideoEditorBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalDurationValue = ref.watch(
      clipManagerProvider.select((state) => state.totalDuration),
    );
    final totalDuration = _formatDuration(totalDurationValue);
    final state = ref.watch(
      videoEditorProvider.select(
        (state) => (
          isPlaying: state.isPlaying,
          isEditing: state.isEditing,
          isMuted: state.isMuted,
          currentTime: state.currentTime,
        ),
      ),
    );
    final notifier = ref.read(videoEditorProvider.notifier);

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  icon: state.isMuted ? Icons.volume_off : Icons.volume_up,
                  onTap: notifier.toggleMute,
                  semanticLabel: 'Mute or unmute audio',
                ),
                VideoEditorIconButton(
                  icon: Icons.more_horiz,
                  onTap: notifier.showMoreOptions,
                  semanticLabel: 'More options',
                ),
              ],
            ],
          ),

          // Time display
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Bricolage Grotesque',
                fontWeight: .w800,
                height: 1.33,
                letterSpacing: 0.15,
                fontFeatures: const [.tabularFigures()],
                color: Colors.white.withValues(alpha: 0.5),
              ),
              children: [
                TextSpan(
                  text: state.currentTime,
                  style: const TextStyle(color: Colors.white),
                ),
                const TextSpan(text: ' / '),
                TextSpan(text: totalDuration),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Formats duration as SS:MS (seconds:milliseconds).
  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds.toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$seconds:$milliseconds';
  }
}
