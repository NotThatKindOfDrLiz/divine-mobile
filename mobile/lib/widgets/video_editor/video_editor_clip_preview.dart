import 'package:flutter/material.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/platform_io.dart';

class VideoClipPreview extends StatelessWidget {
  const VideoClipPreview({super.key, required this.clip, this.onTap});

  final RecordingClip clip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AspectRatio(
          aspectRatio: clip.aspectRatio?.value ?? 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: .circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: .circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (clip.thumbnailPath != null)
                    Image.file(File(clip.thumbnailPath!), fit: .cover)
                  else
                    // Video thumbnail placeholder
                    Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.play_circle_outline,
                        size: 64,
                        color: Colors.white,
                      ),
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
