// ABOUTME: Generic fullscreen video feed screen (no bottom nav)
// ABOUTME: Displays videos with swipe navigation, used from profile/hashtag grids

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_liked_feed_provider.dart';
import 'package:openvine/providers/profile_originals_feed_provider.dart';
import 'package:openvine/providers/profile_reposts_feed_provider.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:video_player/video_player.dart';

/// Represents the source of videos for the fullscreen feed.
/// This allows the screen to reactively watch the appropriate provider.
sealed class VideoFeedSource {
  const VideoFeedSource();
}

/// Profile feed source - ALL videos from a specific user (originals + reposts)
/// Watches profileFeedProvider for reactive updates when loadMore is called
class ProfileFeedSource extends VideoFeedSource {
  const ProfileFeedSource(this.userId);
  final String userId;
}

/// Profile originals feed source - only original videos from a user
/// Watches profileOriginalsFeedProvider for reactive updates
class ProfileOriginalsFeedSource extends VideoFeedSource {
  const ProfileOriginalsFeedSource(this.userId);
  final String userId;
}

/// Profile reposts feed source - only reposted videos from a user
/// Watches profileRepostsFeedProvider for reactive updates
class ProfileRepostsFeedSource extends VideoFeedSource {
  const ProfileRepostsFeedSource(this.userId);
  final String userId;
}

/// Liked videos feed source - user's liked videos
/// Watches profileLikedFeedProvider for reactive updates
class LikedVideosFeedSource extends VideoFeedSource {
  const LikedVideosFeedSource(this.userId);
  final String userId;
}

/// Static feed source - for cases where we just have a list of videos
/// Note: This source does NOT support reactive updates when loadMore fetches
/// new videos
/// Use this for hashtag feeds or other sources that don't have a family
/// provider
class StaticFeedSource extends VideoFeedSource {
  const StaticFeedSource(this.videos, {this.onLoadMore});
  final List<VideoEvent> videos;
  final VoidCallback? onLoadMore;
}

/// Arguments for navigating to FullscreenVideoFeedScreen
class FullscreenVideoFeedArgs {
  const FullscreenVideoFeedArgs({
    required this.source,
    required this.initialIndex,
    this.contextTitle,
  });

  final VideoFeedSource source;
  final int initialIndex;
  final String? contextTitle;
}

/// Generic fullscreen video feed screen.
///
/// This screen is pushed outside the shell route so it doesn't show
/// the bottom navigation bar. It provides a fullscreen video viewing
/// experience with swipe up/down navigation.
///
/// The screen watches the appropriate provider based on [source] to receive
/// reactive updates when new videos are loaded via pagination.
class FullscreenVideoFeedScreen extends ConsumerStatefulWidget {
  const FullscreenVideoFeedScreen({
    required this.source,
    required this.initialIndex,
    this.contextTitle,
    super.key,
  });

  final VideoFeedSource source;
  final int initialIndex;
  final String? contextTitle;

  @override
  ConsumerState<FullscreenVideoFeedScreen> createState() =>
      _FullscreenVideoFeedScreenState();
}

class _FullscreenVideoFeedScreenState
    extends ConsumerState<FullscreenVideoFeedScreen>
    with VideoPrefetchMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _initializedPageController = false;

  @override
  void initState() {
    super.initState();
    // We'll initialize the page controller once we have videos from the
    // provider
    _currentIndex = widget.initialIndex;
  }

  @override
  void deactivate() {
    // Pause video when widget is deactivated (before dispose).
    // This is called before the widget is removed from the tree,
    // so ref is still safe to use here.
    _pauseCurrentVideo();
    super.deactivate();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Get videos from the appropriate source, filtering out broken videos
  List<VideoEvent> _getVideos() {
    final source = widget.source;
    final List<VideoEvent> sourceVideos;

    Log.info(
      'FullscreenVideoFeedScreen: _getVideos() called, source=${source.runtimeType}',
      name: 'FullscreenVideoFeedScreen',
      category: LogCategory.system,
    );

    switch (source) {
      case ProfileFeedSource(:final userId):
        final feedState = ref.watch(profileFeedProvider(userId));
        sourceVideos = feedState.asData?.value.videos ?? [];
      case ProfileOriginalsFeedSource(:final userId):
        final feedState = ref.watch(profileOriginalsFeedProvider(userId));
        sourceVideos = feedState.asData?.value.videos ?? [];
      case ProfileRepostsFeedSource(:final userId):
        final feedState = ref.watch(profileRepostsFeedProvider(userId));
        sourceVideos = feedState.asData?.value.videos ?? [];
      case LikedVideosFeedSource(:final userId):
        final feedState = ref.watch(profileLikedFeedProvider(userId));
        sourceVideos = feedState.asData?.value.videos ?? [];
      case StaticFeedSource(:final videos):
        sourceVideos = videos;
    }

    Log.info(
      'FullscreenVideoFeedScreen: Got ${sourceVideos.length} videos from source',
      name: 'FullscreenVideoFeedScreen',
      category: LogCategory.system,
    );

    // Filter out broken videos
    final trackerAsync = ref.watch(brokenVideoTrackerProvider);
    final tracker = trackerAsync.asData?.value;
    if (tracker == null) {
      // Tracker not ready yet, return unfiltered
      Log.info(
        'FullscreenVideoFeedScreen: Tracker not ready, returning unfiltered',
        name: 'FullscreenVideoFeedScreen',
        category: LogCategory.system,
      );
      return sourceVideos;
    }

    final filtered = sourceVideos
        .where((video) => !tracker.isVideoBroken(video.id))
        .toList();

    Log.info(
      'FullscreenVideoFeedScreen: Filtered to ${filtered.length} videos (removed ${sourceVideos.length - filtered.length} broken)',
      name: 'FullscreenVideoFeedScreen',
      category: LogCategory.system,
    );

    return filtered;
  }

  /// Trigger load more for the appropriate source
  void _loadMore() {
    final source = widget.source;
    switch (source) {
      case ProfileFeedSource(:final userId):
        ref.read(profileFeedProvider(userId).notifier).loadMore();
      case ProfileOriginalsFeedSource(:final userId):
        ref.read(profileOriginalsFeedProvider(userId).notifier).loadMore();
      case ProfileRepostsFeedSource(:final userId):
        ref.read(profileRepostsFeedProvider(userId).notifier).loadMore();
      case LikedVideosFeedSource(:final userId):
        ref.read(profileLikedFeedProvider(userId).notifier).loadMore();
      case StaticFeedSource(:final onLoadMore):
        // Static source uses callback for loading more
        onLoadMore?.call();
    }
  }

  /// Pause the currently active video to prevent background playback.
  /// Called when navigating away from this screen.
  void _pauseCurrentVideo() {
    final videos = _getVideos();
    if (_currentIndex < 0 || _currentIndex >= videos.length) {
      return;
    }

    final video = videos[_currentIndex];
    if (video.videoUrl == null) {
      return;
    }

    VideoPlayerController? controller;
    try {
      final controllerParams = VideoControllerParams(
        videoId: video.id,
        videoUrl: video.videoUrl!,
        videoEvent: video,
      );
      controller = ref.read(
        individualVideoControllerProvider(controllerParams),
      );
    } catch (e) {
      // Controller may not exist yet
      return;
    }

    if (controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isPlaying) {
      return;
    }

    safePause(controller, video.id);
  }

  void _onPageChanged(int newIndex, List<VideoEvent> videos) {
    setState(() {
      _currentIndex = newIndex;
    });

    // Trigger pagination near end
    if (newIndex >= videos.length - 2) {
      _loadMore();
    }

    // Prefetch videos around current index
    checkForPrefetch(currentIndex: newIndex, videos: videos);

    // Pre-initialize controllers for adjacent videos
    preInitializeControllers(ref: ref, currentIndex: newIndex, videos: videos);

    // Dispose controllers outside the keep range to free memory
    disposeControllersOutsideRange(
      ref: ref,
      currentIndex: newIndex,
      videos: videos,
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = _getVideos();

    // Initialize page controller once we have videos
    if (!_initializedPageController && videos.isNotEmpty) {
      _currentIndex = widget.initialIndex.clamp(0, videos.length - 1);
      _pageController = PageController(initialPage: _currentIndex);
      _initializedPageController = true;

      // Pre-initialize controllers for adjacent videos
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        preInitializeControllers(
          ref: ref,
          currentIndex: _currentIndex,
          videos: videos,
        );
      });
    }

    // Show loading state if we don't have videos yet
    if (videos.isEmpty || !_initializedPageController) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: videos.length,
        onPageChanged: (index) => _onPageChanged(index, videos),
        itemBuilder: (context, index) {
          if (index >= videos.length) return const SizedBox.shrink();

          final video = videos[index];
          return VideoFeedItem(
            key: ValueKey('video-${video.stableId}'),
            video: video,
            index: index,
            hasBottomNavigation: false,
            contextTitle: widget.contextTitle,
            // Use isActiveOverride since this screen manages its own active
            // state (not using URL-based routing for video index)
            isActiveOverride: index == _currentIndex,
            disableTapNavigation: true,
            // Fullscreen mode - add extra padding to avoid back button
            isFullscreen: true,
          );
        },
      ),
    );
  }
}
