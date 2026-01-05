// ABOUTME: Displays individual video clip thumbnail with aspect ratio
// ABOUTME: Shows thumbnail image or placeholder icon with rounded corners

import 'package:flutter/material.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/platform_io.dart';

/// Displays a video clip thumbnail with aspect ratio preserved.
class VideoClipPreview extends StatelessWidget {
  /// Creates a video clip preview widget.
  const VideoClipPreview({
    required this.clip,
    super.key,
    this.isReordering = false,
    this.isDeletionZone = false,
    this.onTap,
    this.onLongPress,
  });

  /// The clip to display.
  final RecordingClip clip;

  final bool isReordering;

  final bool isDeletionZone;

  /// Callback when the clip is tapped.
  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Center(
        child: AspectRatio(
          aspectRatio: clip.aspectRatio?.value ?? 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: .circular(16),
              border: .all(
                color: isDeletionZone
                    ? const Color(0xFFF44336) // Red when over delete zone
                    : isReordering
                    ? const Color(0xFFEBDE3B) // Yellow when reordering
                    : const Color(0x00000000), // Transparent otherwise
                width: 4,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
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
