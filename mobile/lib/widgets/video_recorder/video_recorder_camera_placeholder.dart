// ABOUTME: Fallback placeholder widget displayed when camera is unavailable
// ABOUTME: Shows idle icon

import 'package:flutter/material.dart';

/// Fallback preview widget for when camera is not available
class VideoRecorderCameraPlaceholder extends StatelessWidget {
  /// Creates a camera placeholder widget.
  const VideoRecorderCameraPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color(0xFF141414),
      child: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x33FFFFFF), width: 2),
          ),
          child: Icon(
            Icons.videocam_rounded,
            size: 56,
            color: const Color(0xB3FFFFFF),
          ),
        ),
      ),
    );
  }
}
