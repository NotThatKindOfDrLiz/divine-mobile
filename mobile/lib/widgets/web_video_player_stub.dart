// ABOUTME: Stub WebVideoPlayer for non-web platforms (VM/native)
// ABOUTME: Provides same API surface so tests compile on all platforms

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Stub video player for non-web platforms.
///
/// This should never be used at runtime — the real implementation
/// is in `web_video_player_web.dart`, selected via conditional import.
class WebVideoPlayer extends StatefulWidget {
  /// Creates a web video player.
  const WebVideoPlayer({
    required this.url,
    this.autoPlay = false,
    this.looping = true,
    this.fit = BoxFit.cover,
    this.headers = const {},
    this.onInitialized,
    this.onError,
    super.key,
  });

  /// The video URL to play.
  final String url;

  /// Whether to auto-play when initialized.
  final bool autoPlay;

  /// Whether to loop the video.
  final bool looping;

  /// How the video should fit within its container.
  final BoxFit fit;

  /// HTTP headers for the video request.
  final Map<String, String> headers;

  /// Called when the video controller is initialized.
  final ValueChanged<VideoPlayerController>? onInitialized;

  /// Called when an error occurs.
  final VoidCallback? onError;

  @override
  State<WebVideoPlayer> createState() => WebVideoPlayerState();
}

/// Stub state — renders an error placeholder on non-web.
class WebVideoPlayerState extends State<WebVideoPlayer> {
  /// Returns null — no controller on stub.
  VideoPlayerController? get controller => null;

  /// No-op on stub.
  Future<void> play() async {}

  /// No-op on stub.
  Future<void> pause() async {}

  /// No-op on stub.
  Future<void> seekTo(Duration position) async {}

  /// No-op on stub.
  Future<void> setVolume(double volume) async {}

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: VineTheme.backgroundColor,
      child: Center(
        child: Text(
          'Video not supported on this platform',
          style: TextStyle(
            color: VineTheme.secondaryText,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
