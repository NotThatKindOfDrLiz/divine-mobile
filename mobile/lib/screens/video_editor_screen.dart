// ABOUTME: Video editor screen for adding text overlays and sound to recorded videos
// ABOUTME: Dark-themed interface with video preview, text editing, and sound selection

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/widgets/video_editor/video_editor_clips.dart';
import '../widgets/video_editor/video_editor_top_bar.dart';
import '../widgets/video_editor/video_editor_bottom_bar.dart';
import '../widgets/video_editor/video_editor_clip_preview.dart';
import '../widgets/video_editor/video_editor_progress_bar.dart';

class VideoEditorScreen extends ConsumerStatefulWidget {
  const VideoEditorScreen({super.key});

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize editor with video path
    WidgetsBinding.instance.addPostFrameCallback((_) {
      /*  ref
          .read(videoEditorProvider.notifier)
          .initializeWithVideo('widget.videoPath'); */
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            /// Top bar
            VideoEditorTopBar(),

            /// Main content area with clips
            Expanded(
              child: Column(
                spacing: 25,
                mainAxisAlignment: .center,
                crossAxisAlignment: .stretch,
                children: [
                  // Clips carousel
                  Flexible(child: VideoEditorClips()),

                  // Instruction text
                  Align(
                    alignment: .center,
                    child: Text(
                      'Tap to edit. Drag to reorder.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// Bottom bar
            VideoEditorBottomBar(),

            /// Progress bar
            VideoProgressBar(),
          ],
        ),
      ),
    );
  }
}
