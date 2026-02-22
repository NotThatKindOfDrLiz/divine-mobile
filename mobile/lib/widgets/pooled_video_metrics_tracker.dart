// ABOUTME: Tracks video playback metrics for pooled video player (media_kit)
// ABOUTME: Publishes Kind 22236 ephemeral view events for decentralized analytics
// ABOUTME: Companion to VideoMetricsTracker, adapted for Player stream-based API

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

/// Tracks video playback metrics for pooled videos using media_kit Player.
///
/// This is the pooled video equivalent of [VideoMetricsTracker].
/// It subscribes to the [Player]'s streams to track actual playback time
/// and publishes Kind 22236 ephemeral view events on video end.
class PooledVideoMetricsTracker extends ConsumerStatefulWidget {
  const PooledVideoMetricsTracker({
    required this.video,
    required this.player,
    required this.isActive,
    required this.child,
    this.trafficSource = ViewTrafficSource.unknown,
    super.key,
  });

  final VideoEvent video;
  final Player player;
  final bool isActive;
  final Widget child;

  /// Traffic source for analytics (home feed, discovery, profile, etc.)
  final ViewTrafficSource trafficSource;

  @override
  ConsumerState<PooledVideoMetricsTracker> createState() =>
      _PooledVideoMetricsTrackerState();
}

class _PooledVideoMetricsTrackerState
    extends ConsumerState<PooledVideoMetricsTracker> {
  DateTime? _lastPlayStartTime;
  Duration _totalWatchDuration = Duration.zero;
  bool _isPlaying = false;
  bool _hasSentEndEvent = false;
  int _loopCount = 0;
  Duration _lastPosition = Duration.zero;

  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;

  // Save provider references for safe access during dispose
  // CRITICAL: Never use ref.read() in dispose-related methods
  dynamic _analyticsService;
  dynamic _authService;
  dynamic _seenVideosService;
  ViewEventPublisher? _viewEventPublisher;

  @override
  void initState() {
    super.initState();
    _analyticsService = ref.read(analyticsServiceProvider);
    _authService = ref.read(authServiceProvider);
    _seenVideosService = ref.read(seenVideosServiceProvider);
    _viewEventPublisher = ref.read(viewEventPublisherProvider);

    if (widget.isActive) {
      _startTracking();
    }
  }

  @override
  void didUpdateWidget(PooledVideoMetricsTracker oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Video changed — publish for old video, start tracking new one
    if (oldWidget.video.id != widget.video.id) {
      _finalizeAndPublish();
      _resetTracking();
      if (widget.isActive) _startTracking();
      return;
    }

    // Became inactive — publish metrics
    if (oldWidget.isActive && !widget.isActive) {
      _finalizeAndPublish();
      _cancelSubscriptions();
    }

    // Became active — start tracking
    if (!oldWidget.isActive && widget.isActive) {
      _resetTracking();
      _startTracking();
    }

    // Player instance changed (pool reassigned)
    if (oldWidget.player != widget.player) {
      _cancelSubscriptions();
      if (widget.isActive) {
        _subscribeToPlayer();
      }
    }
  }

  void _startTracking() {
    _hasSentEndEvent = false;
    _subscribeToPlayer();

    // Track view start with analytics
    try {
      _analyticsService.trackDetailedVideoViewWithUser(
        widget.video,
        userId: _authService.currentPublicKeyHex,
        source: 'mobile',
        eventType: 'view_start',
      );
    } catch (e) {
      Log.debug(
        'Failed to track view start: $e',
        name: 'PooledVideoMetricsTracker',
        category: LogCategory.video,
      );
    }

    Log.debug(
      'Started tracking pooled video ${widget.video.id}',
      name: 'PooledVideoMetricsTracker',
      category: LogCategory.video,
    );
  }

  void _subscribeToPlayer() {
    _cancelSubscriptions();

    final player = widget.player;

    // Track playing state to accumulate actual watch time
    _playingSub = player.stream.playing.listen((isPlaying) {
      if (isPlaying && !_isPlaying) {
        // Started playing
        _lastPlayStartTime = DateTime.now();
      } else if (!isPlaying && _isPlaying && _lastPlayStartTime != null) {
        // Stopped playing — accumulate watch time
        _totalWatchDuration += DateTime.now().difference(_lastPlayStartTime!);
        _lastPlayStartTime = null;
      }
      _isPlaying = isPlaying;
    });

    // Track position for loop detection
    _positionSub = player.stream.position.listen((position) {
      try {
        final duration = player.state.duration;
        // Detect loop: position jumps back to near start after being near end
        if (_lastPosition > const Duration(seconds: 1) &&
            position < const Duration(seconds: 1) &&
            duration > Duration.zero &&
            _lastPosition.inMilliseconds > duration.inMilliseconds - 1000) {
          _loopCount++;
          Log.debug(
            'Video looped (count: $_loopCount) for ${widget.video.id}',
            name: 'PooledVideoMetricsTracker',
            category: LogCategory.video,
          );
        }
        _lastPosition = position;
      } catch (_) {
        // Player may be disposed during stream delivery
      }
    });

    // Check if already playing when we subscribe
    try {
      if (player.state.playing) {
        _isPlaying = true;
        _lastPlayStartTime = DateTime.now();
      }
    } catch (_) {
      // Player may be disposed
    }
  }

  void _cancelSubscriptions() {
    _playingSub?.cancel();
    _playingSub = null;
    _positionSub?.cancel();
    _positionSub = null;
  }

  void _finalizeAndPublish() {
    // Accumulate any remaining playing time
    if (_isPlaying && _lastPlayStartTime != null) {
      _totalWatchDuration += DateTime.now().difference(_lastPlayStartTime!);
      _lastPlayStartTime = null;
    }
    _isPlaying = false;
    _publishEvents();
  }

  void _publishEvents() {
    if (_hasSentEndEvent) return;
    if (_totalWatchDuration.inSeconds < 1) return;

    _hasSentEndEvent = true;

    try {
      Duration? videoDuration;
      try {
        videoDuration = widget.player.state.duration;
      } catch (_) {
        // Player may be disposed
      }

      // Analytics service — view end
      _analyticsService.trackDetailedVideoViewWithUser(
        widget.video,
        userId: _authService.currentPublicKeyHex,
        source: 'mobile',
        eventType: 'view_end',
        watchDuration: _totalWatchDuration,
        totalDuration: videoDuration,
        loopCount: _loopCount,
        completedVideo:
            _loopCount > 0 ||
            (videoDuration != null &&
                videoDuration > Duration.zero &&
                _totalWatchDuration.inMilliseconds >=
                    videoDuration.inMilliseconds * 0.9),
      );

      // Persist to local storage for "show fresh content" feature
      _seenVideosService.recordVideoView(
        widget.video.id,
        loopCount: _loopCount,
        watchDuration: _totalWatchDuration,
      );

      // Publish Kind 22236 ephemeral view event
      _publishNostrViewEvent();

      Log.debug(
        'Video end: duration=${_totalWatchDuration.inSeconds}s, '
        'loops=$_loopCount',
        name: 'PooledVideoMetricsTracker',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.warning(
        'Failed to send video end event: $e',
        name: 'PooledVideoMetricsTracker',
        category: LogCategory.video,
      );
    }
  }

  /// Publish Kind 22236 ephemeral view event to Nostr relays.
  void _publishNostrViewEvent() {
    final viewPublisher = _viewEventPublisher;
    if (viewPublisher == null) return;
    if (_totalWatchDuration.inSeconds < 1) return;

    // Fire-and-forget: don't await, don't block dispose
    viewPublisher
        .publishViewEvent(
          video: widget.video,
          startSeconds: 0,
          endSeconds: _totalWatchDuration.inSeconds,
          source: widget.trafficSource,
        )
        .then((success) {
          if (success) {
            Log.debug(
              'Published Nostr view event for ${widget.video.id}',
              name: 'PooledVideoMetricsTracker',
              category: LogCategory.video,
            );
          }
        })
        .catchError((Object error) {
          // Silently ignore errors — view events are best-effort
          Log.debug(
            'Failed to publish Nostr view event: $error',
            name: 'PooledVideoMetricsTracker',
            category: LogCategory.video,
          );
        });
  }

  void _resetTracking() {
    _totalWatchDuration = Duration.zero;
    _lastPlayStartTime = null;
    _isPlaying = false;
    _hasSentEndEvent = false;
    _loopCount = 0;
    _lastPosition = Duration.zero;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    _finalizeAndPublish();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Transparent wrapper — just return the child
    return widget.child;
  }
}
