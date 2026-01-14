// ABOUTME: Reusable video prefetch mixin for PageView-based video feeds
// ABOUTME: Handles file caching and controller pre-initialization for instant playback
// ABOUTME: Pool-aware to respect max concurrent controller limits

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/repositories/video_controller_pool.dart';
import 'package:openvine/services/video_cache_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Mixin that provides video prefetching logic for PageView-based feeds
///
/// Provides two complementary prefetch mechanisms:
/// 1. File caching - downloads video files to disk for faster loading
/// 2. Controller pre-init - warms up controllers for instant playback
///
/// Note: Controller cleanup is handled automatically by the VideoControllerPool's
/// LRU eviction. No manual disposal is needed.
///
/// Usage:
/// ```dart
/// class _MyFeedState extends State<MyFeed> with VideoPrefetchMixin {
///   @override
///   VideoCacheManager get videoCacheManager => openVineVideoCache;
///
///   PageView.builder(
///     onPageChanged: (index) {
///       checkForPrefetch(currentIndex: index, videos: myVideos);
///       preInitializeControllers(ref: ref, currentIndex: index, videos: myVideos);
///     },
///   );
/// }
/// ```
mixin VideoPrefetchMixin {
  DateTime? _lastPrefetchCall;

  /// Override this to provide the cache manager instance
  /// Default uses the global singleton
  VideoCacheManager get videoCacheManager => openVineVideoCache;

  /// Override this to customize throttle duration (useful for testing)
  int get prefetchThrottleSeconds => 2;

  /// Check if videos should be prefetched and trigger prefetch if appropriate
  ///
  /// - [currentIndex]: Current video index in the feed
  /// - [videos]: Full list of videos in the feed
  void checkForPrefetch({
    required int currentIndex,
    required List<VideoEvent> videos,
  }) {
    // Skip if no videos
    if (videos.isEmpty) {
      return;
    }

    // Skip prefetch on web platform - file caching not supported
    if (kIsWeb) {
      return;
    }

    // Throttle prefetch calls to avoid excessive network activity
    final now = DateTime.now();
    if (_lastPrefetchCall != null &&
        now.difference(_lastPrefetchCall!).inSeconds <
            prefetchThrottleSeconds) {
      Log.debug(
        'Prefetch: Skipping - too soon since last call (index=$currentIndex)',
        name: 'VideoPrefetchMixin',
        category: LogCategory.video,
      );
      return;
    }

    _lastPrefetchCall = now;

    // Calculate prefetch range using app constants
    final startIndex = (currentIndex - AppConstants.preloadBefore).clamp(
      0,
      videos.length - 1,
    );
    final endIndex = (currentIndex + AppConstants.preloadAfter + 1).clamp(
      0,
      videos.length,
    );

    final videosToPreFetch = <VideoEvent>[];
    for (int i = startIndex; i < endIndex; i++) {
      // Skip current video and videos without URLs
      if (i != currentIndex && i >= 0 && i < videos.length) {
        final video = videos[i];
        if (video.videoUrl != null && video.videoUrl!.isNotEmpty) {
          videosToPreFetch.add(video);
        }
      }
    }

    if (videosToPreFetch.isEmpty) {
      return;
    }

    final videoUrls = videosToPreFetch.map((v) => v.videoUrl!).toList();
    final videoIds = videosToPreFetch.map((v) => v.id).toList();

    Log.info(
      '🎬 Prefetching ${videosToPreFetch.length} videos around index $currentIndex '
      '(before=${AppConstants.preloadBefore}, after=${AppConstants.preloadAfter})',
      name: 'VideoPrefetchMixin',
      category: LogCategory.video,
    );

    // Fire and forget - don't block on prefetch
    try {
      videoCacheManager.preCache(videoUrls, videoIds).catchError((error) {
        Log.error(
          '❌ Error prefetching videos: $error',
          name: 'VideoPrefetchMixin',
          category: LogCategory.video,
        );
      });
    } catch (error) {
      Log.error(
        '❌ Error prefetching videos: $error',
        name: 'VideoPrefetchMixin',
        category: LogCategory.video,
      );
    }
  }

  /// Reset prefetch throttle (useful after feed refresh or context change)
  void resetPrefetch() {
    _lastPrefetchCall = null;
    Log.debug(
      'Prefetch: Reset throttle',
      name: 'VideoPrefetchMixin',
      category: LogCategory.video,
    );
  }

  /// Pre-initialize video controllers for adjacent videos
  ///
  /// Triggers controller creation and initialization for videos before/after
  /// the current position. By the time user swipes, the controller should
  /// already be initialized for instant playback.
  ///
  /// This complements [checkForPrefetch] which caches video files to disk.
  /// Controller initialization happens in memory and includes codec setup.
  ///
  /// Pool-aware: Checks available slots and existing controllers to avoid
  /// exceeding the platform's concurrent controller limit.
  ///
  /// - [ref]: WidgetRef for reading the controller provider
  /// - [currentIndex]: Current video index in the feed
  /// - [videos]: Full list of videos in the feed
  void preInitializeControllers({
    required WidgetRef ref,
    required int currentIndex,
    required List<VideoEvent> videos,
  }) {
    if (videos.isEmpty) return;

    // Check pool capacity before pre-initializing
    final pool = ref.read(videoControllerPoolProvider);
    final availableSlots = pool.availableSlots;

    if (availableSlots <= 0) return;

    final videoList = _getVideosToPreInitialize(
      currentIndex: currentIndex,
      videos: videos,
      pool: pool,
    );

    // If there are no videos to pre-initialize, return
    if (videoList.isEmpty) return;

    // Pre-initialize controllers for the videos in the list
    for (final video in videoList) {
      final params = VideoControllerParams(
        videoId: video.id,
        videoUrl: video.videoUrl!,
        videoEvent: video,
      );

      // Read the controller provider for the video
      // This is a fire-and-forget call to warm up the video controller
      ref.read(individualVideoControllerProvider(params));
    }

    Log.debug(
      '🎬 Pre-initialized ${videoList.length} controllers for videos around index $currentIndex',
      name: 'VideoPrefetchMixin',
      category: LogCategory.video,
    );
  }

  List<VideoEvent> _getVideosToPreInitialize({
    required int currentIndex,
    required List<VideoEvent> videos,
    required VideoControllerPool pool,
  }) {
    final videoList = <VideoEvent>[];

    var offset = 1;
    var beforeCount = 0;
    var afterCount = 0;

    bool canContinue() {
      if (currentIndex + offset >= videos.length && currentIndex - offset < 0) {
        return false;
      }

      return _canAddBefore(beforeCount) || _canAddAfter(afterCount);
    }

    while (canContinue()) {
      final beforeIndex = currentIndex - offset;
      final afterIndex = currentIndex + offset;

      if (_canAddBefore(beforeCount) && beforeIndex >= 0) {
        final before = videos[beforeIndex];
        if (_canPreInitialize(before, pool)) {
          videoList.add(before);
          beforeCount++;
        }
      }

      if (_canAddAfter(afterCount) && afterIndex < videos.length) {
        final after = videos[afterIndex];
        if (_canPreInitialize(after, pool)) {
          videoList.add(after);
          afterCount++;
        }
      }

      offset++;
    }

    return videoList;
  }

  bool _canAddBefore(int count) => count < AppConstants.controllerPreInitBefore;
  bool _canAddAfter(int count) => count < AppConstants.controllerPreInitAfter;

  /// Check if video can be pre-initialized (has URL and not already in pool)
  bool _canPreInitialize(VideoEvent video, dynamic pool) {
    final url = video.videoUrl ?? '';
    if (url.isEmpty) return false;

    // Use pool to check if controller already exists
    return !pool.hasController(video.id);
  }
}
