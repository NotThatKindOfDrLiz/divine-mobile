// ABOUTME: Displays individual video clip thumbnail with aspect ratio
// ABOUTME: Shows thumbnail image or placeholder icon with rounded corners

import 'package:flutter/material.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/platform_io.dart';

/// Displays a video clip thumbnail with aspect ratio preserved.
class VideoClipPreview extends StatelessWidget {
  /// Creates a video clip preview widget.
  const VideoClipPreview({required this.clip, super.key, this.onTap});

  /// The clip to display.
  final RecordingClip clip;

  /// Callback when the clip is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AspectRatio(
          aspectRatio: clip.aspectRatio?.value ?? 1,
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
    );
  }
}
