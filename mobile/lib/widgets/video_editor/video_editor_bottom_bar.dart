// ABOUTME: Bottom bar with playback controls and time display
// ABOUTME: Play/pause, mute, and options buttons with formatted duration

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:openvine/widgets/divine_icon_button.dart';
import 'package:openvine/widgets/video_editor/video_time_display.dart';

/// Bottom bar with playback controls and time display.
class VideoEditorBottomBar extends ConsumerWidget {
  /// Creates a video editor bottom bar widget.
  const VideoEditorBottomBar({super.key});
  Future<void> _handleSplitClip(BuildContext context, WidgetRef ref) async {
    final splitPosition = ref.read(videoEditorProvider).splitPosition;
    final currentClipIndex = ref.read(videoEditorProvider).currentClipIndex;

    final clips = ref.read(clipManagerProvider).clips;
    if (currentClipIndex >= clips.length) {
      return;
    }

    final selectedClip = clips[currentClipIndex];

    // Check if clip is currently processing
    if (selectedClip.isProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Cannot split clip while it is being processed. Please wait.',
          ),
          duration: Duration(seconds: 2),
          behavior: .floating,
        ),
      );
      return;
    }

    // Validate split position
    if (!VideoEditorSplitService.isValidSplitPosition(
      selectedClip,
      splitPosition,
    )) {
      const minDuration = VideoEditorSplitService.minClipDuration;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Split position invalid. Both clips must be at least '
            '${minDuration.inMilliseconds}ms long.',
          ),
          duration: const Duration(seconds: 2),
          behavior: .floating,
        ),
      );
      return;
    }

    // Proceed with split
    await ref.read(videoEditorProvider.notifier).splitSelectedClip();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      videoEditorProvider.select(
        (state) => (
          isPlaying: state.isPlaying,
          isEditing: state.isEditing,
          isReordering: state.isReordering,
          isMuted: state.isMuted,
          currentClipIndex: state.currentClipIndex,
          splitPosition: state.splitPosition,
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
                      DivineIconButton(
                        iconPath: state.isPlaying
                            ? 'assets/icon/pause.svg'
                            : 'assets/icon/play.svg',
                        onTap: notifier.togglePlayPause,
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticLabel: 'Play or pause video',
                      ),
                      if (state.isEditing)
                        DivineIconButton(
                          iconPath: 'assets/icon/trim.svg',
                          onTap: () => _handleSplitClip(context, ref),
                          // TODO(l10n): Replace with context.l10n when localization is added.
                          semanticLabel: 'Crop',
                        )
                      else ...[
                        DivineIconButton(
                          iconPath: state.isMuted
                              ? 'assets/icon/volume_off.svg'
                              : 'assets/icon/volume_on.svg',
                          onTap: notifier.toggleMute,
                          // TODO(l10n): Replace with context.l10n when localization is added.
                          semanticLabel: 'Mute or unmute audio',
                        ),
                        DivineIconButton(
                          iconPath: 'assets/icon/more_horiz.svg',
                          onTap: () => notifier.showMoreOptions(context),
                          // TODO(l10n): Replace with context.l10n when localization is added.
                          semanticLabel: 'More options',
                        ),
                      ],
                    ],
                  ),

                  // Time display
                  Consumer(
                    builder: (_, ref, _) {
                      Duration totalDuration = .zero;

                      if (state.isEditing) {
                        totalDuration = ref.watch(
                          clipManagerProvider.select((p) {
                            final clipIndex = state.currentClipIndex;

                            if (clipIndex >= p.clips.length) {
                              assert(
                                false,
                                'Clip index $clipIndex is out of bounds. '
                                'Total clips: ${p.clips.length}',
                              );
                              return Duration.zero;
                            }

                            return p.clips[clipIndex].duration;
                          }),
                        );
                      } else {
                        totalDuration = ref.watch(
                          clipManagerProvider.select(
                            (state) => state.totalDuration,
                          ),
                        );
                      }

                      return VideoTimeDisplay(
                        key: ValueKey(state.isEditing),
                        isPlayingSelector: videoEditorProvider.select(
                          (s) => s.isPlaying && !s.isEditing,
                        ),
                        currentPositionSelector: state.isEditing
                            ? videoEditorProvider.select((s) => s.splitPosition)
                            : videoEditorProvider.select(
                                (s) => s.currentPosition,
                              ),
                        totalDuration: totalDuration,
                      );
                    },
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
          shape: RoundedRectangleBorder(borderRadius: .circular(20)),
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
