import 'package:flutter/material.dart';

class VideoClipPreview extends StatelessWidget {
  const VideoClipPreview({
    super.key,
    required this.videoPath,
    this.isCenter = false,
    this.onTap,
  });

  final String videoPath;
  final bool isCenter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isCenter ? 273 : 245.7,
        height: isCenter ? 485 : 437,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: .circular(isCenter ? 16 : 14.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: isCenter ? 8 : 7.2,
              offset: Offset(0, isCenter ? 4 : 3.6),
              spreadRadius: isCenter ? 3 : 2.7,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: isCenter ? 3 : 2.7,
              offset: Offset(0, isCenter ? 1 : 0.9),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: .circular(isCenter ? 16 : 14.4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video thumbnail placeholder
              Container(
                color: Colors.grey[300],
                child: const Icon(
                  Icons.play_circle_outline,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              // Semi-transparent overlay for non-center clips
              if (!isCenter)
                Container(color: Colors.white.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
