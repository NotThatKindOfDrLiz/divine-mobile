import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_clip_processing_overlay.dart';

class VideoMetadataClipPreview extends ConsumerWidget {
  const VideoMetadataClipPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clip = ref.watch(clipManagerProvider).clips.first;
    final isProcessing = ref.watch(videoEditorProvider).isProcessing;

    return Padding(
      padding: const .symmetric(vertical: 32.0),
      child: Center(
        child: SizedBox(
          height: 200,
          child: AspectRatio(
            aspectRatio: clip.aspectRatio.value,
            child: ClipRRect(
              borderRadius: .circular(16),
              child: Stack(
                children: [
                  AnimatedSwitcher(
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      fit: .expand,
                      alignment: .center,
                      children: [...previousChildren, ?currentChild],
                    ),
                    duration: const Duration(milliseconds: 150),
                    child: clip.thumbnailPath != null
                        ?
                          // Show thumbnail when not playing or not initialized
                          Image.file(File(clip.thumbnailPath!), fit: .cover)
                        :
                          // Video thumbnail placeholder
                          Container(
                            color: Colors.grey.shade400,
                            child: const Icon(
                              Icons.play_circle_outline,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  VideoEditorClipProcessingOverlay(
                    clip: clip,
                    isProcessing: isProcessing,
                    inactivePlaceholder: _PlayIndicator(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayIndicator extends StatelessWidget {
  const _PlayIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const .all(12),
        decoration: ShapeDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          shape: RoundedRectangleBorder(borderRadius: .circular(20)),
        ),
        child: SizedBox(
          width: 24,
          height: 24,
          child: SvgPicture.asset(
            'assets/icon/play.svg',
            colorFilter: const .mode(Colors.white, .srcIn),
          ),
        ),
      ),
    );
  }
}
