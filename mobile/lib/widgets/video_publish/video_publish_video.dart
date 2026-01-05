// ABOUTME: Video preview widget for video publish screen
// ABOUTME: Displays the video being published with video player

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:video_player/video_player.dart';

/// Video preview widget displaying the video to be published.
class VideoPublishVideo extends ConsumerStatefulWidget {
  /// Creates a video publish video widget.
  const VideoPublishVideo({super.key});

  @override
  ConsumerState<VideoPublishVideo> createState() => _VideoPublishVideoState();
}

class _VideoPublishVideoState extends ConsumerState<VideoPublishVideo> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize after first frame to ensure provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeVideoPlayer());
    });
  }

  Future<void> _initializeVideoPlayer() async {
    final editedVideo = ref.read(videoEditorProvider).editedVideo;
    final videoPath = editedVideo?.file?.path;

    if (videoPath == null) {
      debugPrint('⚠️ No edited video path available');
      return;
    }

    _controller = VideoPlayerController.file(File(videoPath));
    await _controller?.initialize();
    if (!mounted) return;
    await _controller?.setLooping(true);
    if (!mounted) return;
    await _controller?.play();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = ref.watch(
      videoEditorProvider.select((s) => s.editedVideoMeta),
    );

    return SafeArea(
      child: ClipRRect(
        clipBehavior: .hardEdge,
        borderRadius: .circular(16),
        child: AspectRatio(
          aspectRatio: metadata!.resolution.aspectRatio,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _isInitialized && _controller != null
                ? FittedBox(
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : ColoredBox(
                    color: Colors.grey.shade800,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
