// ABOUTME: Video editor screen for adding text overlays and sound to recorded videos
// ABOUTME: Dark-themed interface with video preview, text editing, and sound selection

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import '../widgets/video_editor/video_editor_top_bar.dart';
import '../widgets/video_editor/video_editor_bottom_bar.dart';
import '../widgets/video_editor/video_editor_clip_preview.dart';
import '../widgets/video_editor/video_editor_progress_bar.dart';

class VideoEditorScreen extends ConsumerStatefulWidget {
  const VideoEditorScreen({super.key, required this.videoPath});

  final String videoPath;

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize editor with video path
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(videoEditorProvider.notifier)
          .initializeWithVideo(widget.videoPath);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content area with clips
            Positioned.fill(
              child: Column(
                children: [
                  const SizedBox(height: 80),

                  // Clip counter badge
                  Container(
                    margin: const EdgeInsets.only(left: 16, top: 0, bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101111),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.list, color: Colors.white, size: 24),
                      ],
                    ),
                  ),

                  // Clips carousel
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Left clip (partially visible)
                        Positioned(
                          left: -133,
                          child: VideoClipPreview(
                            videoPath: widget.videoPath,
                            isCenter: false,
                          ),
                        ),

                        // Center clip (main focus)
                        VideoClipPreview(
                          videoPath: widget.videoPath,
                          isCenter: true,
                        ),

                        // Right clip (partially visible)
                        Positioned(
                          right: -95,
                          child: VideoClipPreview(
                            videoPath: widget.videoPath,
                            isCenter: false,
                          ),
                        ),

                        // Gradient overlays on sides
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 65,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: 64,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                                colors: [
                                  Colors.black.withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Instruction text
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Tap to edit. Drag to reorder.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),

            // Top bar
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: VideoEditorTopBar(),
            ),

            // Bottom bar
            const Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: VideoEditorBottomBar(),
            ),

            // Progress bar
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressBar(),
            ),
          ],
        ),
      ),
    );
  }
}
