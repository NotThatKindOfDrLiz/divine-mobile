// ABOUTME: Video publish screen with video preview and controls
// ABOUTME: Allows users to preview and publish their edited video

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/widgets/video_publish/video_publish_bottom_bar.dart';
import 'package:openvine/widgets/video_publish/video_publish_top_bar.dart';
import 'package:openvine/widgets/video_publish/video_publish_video.dart';

/// Video publish screen for previewing and publishing edited videos.
class VideoPublishScreen extends ConsumerWidget {
  /// Creates a video publish screen.
  const VideoPublishScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: .light,
        statusBarBrightness: .dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Video preview
            Align(
              child: VideoPublishVideo(),
            ),

            // Top navigation
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: VideoPublishTopBar(),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoPublishBottomBar(),
            ),
          ],
        ),
      ),
    );
  }
}
