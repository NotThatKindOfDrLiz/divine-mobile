import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'video_editor_icon_button.dart';

class VideoEditorBottomBar extends ConsumerWidget {
  const VideoEditorBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      videoEditorProvider.select(
        (state) => (
          isPlaying: state.isPlaying,
          isMuted: state.isMuted,
          currentTime: state.currentTime,
          totalTime: state.totalTime,
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
            children: [
              VideoEditorIconButton(
                icon: state.isPlaying ? Icons.pause : Icons.play_arrow,
                onTap: notifier.togglePlayPause,
                semanticLabel: 'Play or pause video',
              ),
              const SizedBox(width: 16),
              VideoEditorIconButton(
                icon: state.isMuted ? Icons.volume_off : Icons.volume_up,
                onTap: notifier.toggleMute,
                semanticLabel: 'Mute or unmute audio',
              ),
              const SizedBox(width: 16),
              VideoEditorIconButton(
                icon: Icons.more_horiz,
                onTap: notifier.showMoreOptions,
                semanticLabel: 'More options',
              ),
            ],
          ),

          // Time display
          Row(
            children: [
              Text(
                state.currentTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                state.totalTime,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
