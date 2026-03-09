import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:pooled_video_player/src/controllers/video_feed_controller.dart';
import 'package:pooled_video_player/src/models/video_index_state.dart';
import 'package:pooled_video_player/src/widgets/video_pool_provider.dart';

const _firstFrameRevealTimeout = Duration(seconds: 2);

/// Builder for the video layer.
typedef VideoBuilder =
    Widget Function(
      BuildContext context,
      VideoController videoController,
      Player player,
    );

/// Builder for the overlay layer rendered on top of the video.
typedef OverlayBuilder =
    Widget Function(
      BuildContext context,
      VideoController? videoController,
      Player? player,
    );

/// Builder for the error state.
typedef ErrorBuilder =
    Widget Function(BuildContext context, VoidCallback onRetry);

/// Video player widget that displays a video from [VideoFeedController].
class PooledVideoPlayer extends StatelessWidget {
  /// Creates a pooled video player widget.
  const PooledVideoPlayer({
    required this.index,
    required this.videoBuilder,
    this.controller,
    this.thumbnailUrl,
    this.loadingBuilder,
    this.errorBuilder,
    this.overlayBuilder,
    this.enableTapToPause = false,
    this.onTap,
    super.key,
  });

  /// Optional explicit controller. Falls back to [VideoPoolProvider].
  final VideoFeedController? controller;

  /// The index of this video in the feed.
  final int index;

  /// Optional thumbnail URL to display while loading.
  final String? thumbnailUrl;

  /// Builder for the video layer.
  final VideoBuilder videoBuilder;

  /// Builder for the loading state.
  final WidgetBuilder? loadingBuilder;

  /// Builder for the error state.
  final ErrorBuilder? errorBuilder;

  /// Builder for the overlay layer.
  final OverlayBuilder? overlayBuilder;

  /// Whether tapping toggles play/pause.
  final bool enableTapToPause;

  /// Custom tap handler.
  final VoidCallback? onTap;

  void _handleTap(VideoFeedController ctrl) {
    if (onTap != null) {
      onTap!();
    } else if (enableTapToPause) {
      ctrl.togglePlayPause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedController = controller ?? VideoPoolProvider.feedOf(context);

    return ValueListenableBuilder<VideoIndexState>(
      valueListenable: feedController.getIndexNotifier(index),
      builder: (context, state, _) {
        final videoController = state.videoController;
        final player = state.player;
        final loadState = state.loadState;
        final overlay = overlayBuilder?.call(context, videoController, player);

        Widget content;

        if (loadState == LoadState.error) {
          content = Stack(
            fit: StackFit.expand,
            children: [
              errorBuilder?.call(
                    context,
                    () => feedController.onPageChanged(
                      feedController.currentIndex,
                    ),
                  ) ??
                  const _DefaultErrorState(),
              ?overlay,
            ],
          );
        } else {
          final loadingPlaceholder =
              loadingBuilder?.call(context) ??
              _DefaultLoadingState(thumbnailUrl: thumbnailUrl);

          final children = <Widget>[
            loadingPlaceholder,
            if (videoController != null && player != null)
              _RevealVideoAfterFirstFrame(
                videoController: videoController,
                player: player,
                readyForFallback: loadState == LoadState.ready,
                child: videoBuilder(context, videoController, player),
              ),
            ?overlay,
          ];
          content = Stack(fit: StackFit.expand, children: children);
        }

        final enableInteraction =
            (enableTapToPause || onTap != null) &&
            videoController != null &&
            loadState == LoadState.ready;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: enableInteraction ? () => _handleTap(feedController) : null,
          child: content,
        );
      },
    );
  }
}

class _RevealVideoAfterFirstFrame extends StatefulWidget {
  const _RevealVideoAfterFirstFrame({
    required this.videoController,
    required this.player,
    required this.readyForFallback,
    required this.child,
  });

  final VideoController videoController;
  final Player player;
  final bool readyForFallback;
  final Widget child;

  @override
  State<_RevealVideoAfterFirstFrame> createState() =>
      _RevealVideoAfterFirstFrameState();
}

class _RevealVideoAfterFirstFrameState
    extends State<_RevealVideoAfterFirstFrame> {
  final ValueNotifier<bool> _hasRenderedFirstFrame = ValueNotifier(false);
  final ValueNotifier<bool> _revealedByTimeout = ValueNotifier(false);
  int _generation = 0;
  Timer? _firstFrameTimeout;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToFirstFrame();
    _syncFallbackTimer();
  }

  @override
  void didUpdateWidget(covariant _RevealVideoAfterFirstFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.player, widget.player)) {
      _cancelPositionSubscription();
      _resetRevealState();
      _subscribeToFirstFrame();
    }
    if (oldWidget.readyForFallback != widget.readyForFallback) {
      _syncFallbackTimer();
    }
  }

  void _cancelPositionSubscription() {
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
  }

  void _resetRevealState() {
    _firstFrameTimeout?.cancel();
    _hasRenderedFirstFrame.value = false;
    _revealedByTimeout.value = false;
  }

  void _subscribeToFirstFrame() {
    final generation = ++_generation;
    _firstFrameTimeout?.cancel();
    _cancelPositionSubscription();

    // Wait for position to become > 0 after subscribing.
    // We track whether we've seen position become > 0 since subscribing,
    // which handles the case where the player is reused and had an old
    // position value before being assigned to this video.
    var seenZeroOrStart = widget.player.state.position <= Duration.zero;

    _positionSubscription = widget.player.stream.position.listen((position) {
      if (!mounted || generation != _generation) return;

      // First, we need to see position at or near zero (video started loading)
      if (position <= Duration.zero) {
        seenZeroOrStart = true;
      }

      // Then, when position becomes > 0, the first frame is rendered
      if (seenZeroOrStart && position > Duration.zero) {
        _cancelPositionSubscription();
        _firstFrameTimeout?.cancel();
        _hasRenderedFirstFrame.value = true;
      }
    });

    // If position is already 0 or less, we're ready to detect first frame
    // If position is already > 0 and we just subscribed, we need to wait
    // for it to reset (new video loading) before revealing
  }

  void _syncFallbackTimer() {
    _firstFrameTimeout = Timer(_firstFrameRevealTimeout, () {
      if (!mounted ||
          _hasRenderedFirstFrame.value ||
          !widget.readyForFallback) {
        return;
      }
      _revealedByTimeout.value = true;
    });

    if (!widget.readyForFallback || _hasRenderedFirstFrame.value) {
      _firstFrameTimeout?.cancel();
      _revealedByTimeout.value = false;
      return;
    }
  }

  @override
  void dispose() {
    _cancelPositionSubscription();
    _firstFrameTimeout?.cancel();
    _hasRenderedFirstFrame.dispose();
    _revealedByTimeout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _hasRenderedFirstFrame,
        _revealedByTimeout,
      ]),
      builder: (context, _) {
        final shouldReveal =
            _hasRenderedFirstFrame.value ||
            (widget.readyForFallback && _revealedByTimeout.value);

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          opacity: shouldReveal ? 1 : 0,
          child: widget.child,
        );
      },
    );
  }
}

/// Default loading state.
class _DefaultLoadingState extends StatelessWidget {
  const _DefaultLoadingState({this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            Image.network(
              thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}

/// Default error state.
class _DefaultErrorState extends StatelessWidget {
  const _DefaultErrorState();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white70, size: 48),
            SizedBox(height: 16),
            Text(
              'Failed to load video',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
