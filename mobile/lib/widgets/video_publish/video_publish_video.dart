// ABOUTME: Video preview widget for video publish screen
// ABOUTME: Displays the video being published with placeholder

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Video preview widget displaying the video to be published.
class VideoPublishVideo extends ConsumerWidget {
  /// Creates a video publish video widget.
  const VideoPublishVideo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Replace with actual video player
    return SafeArea(
      child: ClipRRect(
        clipBehavior: .hardEdge,
        borderRadius: .circular(16),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: ColoredBox(
            color: Colors.grey.shade800,
            child: const Center(
              child: Icon(
                Icons.videocam,
                size: 100,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
