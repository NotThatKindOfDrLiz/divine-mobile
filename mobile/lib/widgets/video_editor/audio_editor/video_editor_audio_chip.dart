import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/screens/video_editor/video_audio_editor_timing_screen.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';

class VideoEditorAudioChip extends ConsumerWidget {
  const VideoEditorAudioChip({this.onSelectionDone, super.key});

  final VoidCallback? onSelectionDone;

  Future<void> _selectAudio(BuildContext context, WidgetRef ref) async {
    final selectedSound = ref.read(selectedSoundProvider);
    final videoRecorderNotifier = ref.read(videoRecorderProvider.notifier);
    videoRecorderNotifier.pauseRemoteRecordControl();

    if (selectedSound == null) {
      final result = await VineBottomSheet.show<AudioEvent>(
        context: context,
        maxChildSize: 1,
        initialChildSize: 1,
        minChildSize: 0.8,
        buildScrollBody: (scrollController) =>
            AudioSelectionBottomSheet(scrollController: scrollController),
      );
      if (result == null) {
        videoRecorderNotifier.resumeRemoteRecordControl();
        return;
      } else {
        ref.read(selectedSoundProvider.notifier).select(result);
      }
    }

    if (!context.mounted) return;

    await Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, _, _) => const VideoAudioEditorTimingScreen(),
      ),
    );

    onSelectionDone?.call();

    videoRecorderNotifier.resumeRemoteRecordControl();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSound = ref.watch(selectedSoundProvider);
    final hasSelectedSound = selectedSound != null;

    return InkWell(
      onTap: () => _selectAudio(context, ref),
      radius: 16,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const .fromLTRB(16, 8, 8, 8),
        decoration: ShapeDecoration(
          color: VineTheme.scrim15,
          shape: RoundedRectangleBorder(borderRadius: .circular(16)),
        ),
        child: Row(
          mainAxisSize: .min,
          mainAxisAlignment: .center,

          children: [
            if (hasSelectedSound)
              const DivineIcon(
                icon: .musicNotesSimple,
              )
            else
              const Row(
                spacing: 1.5,
                children: [
                  _AudioBar(height: 7),
                  _AudioBar(height: 16),
                  _AudioBar(height: 13),
                  _AudioBar(height: 7),
                  _AudioBar(height: 10),
                ],
              ),
            Flexible(
              child: Padding(
                padding: const .symmetric(horizontal: 8),
                child: hasSelectedSound
                    ? Text.rich(
                        TextSpan(
                          style: VineTheme.labelLargeFont(),
                          children: [
                            // TODO(l10n): Replace with context.l10n when localization is added.
                            TextSpan(text: selectedSound.title ?? 'Untitled'),
                            if (selectedSound.source != null) ...[
                              const TextSpan(text: ' ∙ '),
                              TextSpan(
                                text: selectedSound.source,
                                style: VineTheme.bodyMediumFont(),
                              ),
                            ],
                          ],
                        ),
                        textAlign: .center,
                        maxLines: 1,
                        overflow: .ellipsis,
                      )
                    : Text(
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        'Add audio',
                        textAlign: .center,
                        style: VineTheme.titleMediumFont(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioBar extends StatelessWidget {
  const _AudioBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 2,
      height: height,
      decoration: BoxDecoration(
        color: VineTheme.whiteText,
        borderRadius: .circular(2),
      ),
    );
  }
}
