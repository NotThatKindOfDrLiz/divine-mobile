// ABOUTME: Web-native video player using raw HTML5 <video> via HtmlElementView
// ABOUTME: Bypasses video_player package overhead for faster web playback

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

/// A video player widget for web using a raw HTML5 `<video>` element
/// embedded via [HtmlElementView] for maximum performance.
///
/// Bypasses the `video_player` package's Flutter compositor overhead
/// by controlling the DOM element directly through `package:web`.
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
  /// Note: Always receives null with HtmlElementView implementation.
  final ValueChanged<VideoPlayerController>? onInitialized;

  /// Called when an error occurs.
  final VoidCallback? onError;

  @override
  State<WebVideoPlayer> createState() => WebVideoPlayerState();
}

/// State for [WebVideoPlayer].
class WebVideoPlayerState extends State<WebVideoPlayer> {
  web.HTMLVideoElement? _videoElement;
  bool _hasError = false;
  late final String _viewType;
  late final JSFunction _errorCallback;

  /// Returns null — no [VideoPlayerController] is used.
  ///
  /// Kept for compatibility with [WebVideoFeedItemBuilder].
  VideoPlayerController? get controller => null;

  @override
  void initState() {
    super.initState();
    _viewType = 'web-video-player-${widget.url.hashCode}-$hashCode';
    _errorCallback = _onError.toJS;
    _createAndRegister();
  }

  void _createAndRegister() {
    final video = web.HTMLVideoElement()
      ..src = widget.url
      ..autoplay = widget.autoPlay
      ..loop = widget.looping
      ..muted = true
      ..playsInline = true
      ..preload = 'auto';

    video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover'
      ..setProperty('pointer-events', 'none');

    video.addEventListener('error', _errorCallback);

    _videoElement = video;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => video,
    );
  }

  void _onError(web.Event event) {
    if (!mounted) return;
    setState(() => _hasError = true);
    widget.onError?.call();
  }

  @override
  void didUpdateWidget(WebVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      final video = _videoElement;
      if (video != null) {
        video.src = widget.url;
        video.load();
      }
    }
  }

  /// Plays the video.
  Future<void> play() async {
    final element = _videoElement;
    if (element == null) return;
    element.play();
  }

  /// Pauses the video.
  Future<void> pause() async {
    _videoElement?.pause();
  }

  /// Seeks to the given position.
  Future<void> seekTo(Duration position) async {
    final element = _videoElement;
    if (element != null) {
      element.currentTime = position.inMilliseconds / 1000.0;
    }
  }

  /// Sets the volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    _videoElement?.volume = volume;
  }

  @override
  void dispose() {
    final video = _videoElement;
    if (video != null) {
      video.pause();
      video.removeEventListener(
        'error',
        _errorCallback,
      );
    }
    _videoElement = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const ColoredBox(
        color: VineTheme.backgroundColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: VineTheme.secondaryText,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Failed to load video',
                style: TextStyle(
                  color: VineTheme.secondaryText,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return HtmlElementView(viewType: _viewType);
  }
}
