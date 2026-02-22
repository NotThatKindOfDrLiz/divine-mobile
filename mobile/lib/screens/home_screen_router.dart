// ABOUTME: Router-driven HomeScreen implementation (clean room)
// ABOUTME: Pure presentation with no lifecycle mutations - URL is source of truth

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/mixins/async_value_ui_helpers_mixin.dart';
import 'package:openvine/mixins/page_controller_sync_mixin.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/providers/home_screen_controllers.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/utils/quiet_hours.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

/// Router-driven HomeScreen - PageView syncs with URL bidirectionally
class HomeScreenRouter extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'home';

  /// Path for this route.
  static const path = '/home';

  /// Path for this route with index.
  static const pathWithIndex = '/home/:index';

  /// Build path for a specific index.
  static String pathForIndex(int index) => '/home/$index';

  const HomeScreenRouter({super.key});

  @override
  ConsumerState<HomeScreenRouter> createState() => _HomeScreenRouterState();
}

class _HomeScreenRouterState extends ConsumerState<HomeScreenRouter>
    with VideoPrefetchMixin, PageControllerSyncMixin, AsyncValueUIHelpersMixin {
  PageController? _controller;
  int? _lastUrlIndex;
  int? _lastPrefetchIndex;
  bool _awaitingLoadMoreConfirmation = false;
  bool _isLoadingMoreFromNudge = false;
  int? _lastPromptedVideoCount;
  int? _lastObservedVideoCount;
  bool _shouldResumeAfterBreakPrompt = false;

  @override
  void initState() {
    super.initState();

    final videosAsync = ref.read(homeFeedProvider);

    // Pre-initialize controllers on next frame (don't redirect - respect URL)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initial build pre initialization
      videosAsync.whenData((state) {
        preInitializeControllers(
          ref: ref,
          currentIndex: 0,
          videos: state.videos,
        );
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pauseCurrentVideoForBreakPrompt(List<VideoEvent> videos) async {
    final currentIndex = _controller?.hasClients == true
        ? (_controller!.page?.round() ?? 0)
        : (_lastUrlIndex ?? 0);
    if (currentIndex < 0 || currentIndex >= videos.length) return;

    final video = videos[currentIndex];
    final videoUrl = video.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return;

    final params = VideoControllerParams(
      videoId: video.id,
      videoUrl: videoUrl,
      videoEvent: video,
    );
    final controller = ref.read(individualVideoControllerProvider(params));
    _shouldResumeAfterBreakPrompt = controller.value.isPlaying;
    if (_shouldResumeAfterBreakPrompt) {
      await safePause(controller, video.id);
    }
  }

  Future<void> _resumeCurrentVideoAfterBreakPrompt(
    List<VideoEvent> videos,
  ) async {
    if (!_shouldResumeAfterBreakPrompt) return;

    final currentIndex = _controller?.hasClients == true
        ? (_controller!.page?.round() ?? 0)
        : (_lastUrlIndex ?? 0);
    if (currentIndex < 0 || currentIndex >= videos.length) return;

    final video = videos[currentIndex];
    final videoUrl = video.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return;

    final params = VideoControllerParams(
      videoId: video.id,
      videoUrl: videoUrl,
      videoEvent: video,
    );
    final controller = ref.read(individualVideoControllerProvider(params));
    await safePlay(controller, video.id);
    _shouldResumeAfterBreakPrompt = false;
  }

  Future<void> _dismissBreakPrompt(List<VideoEvent> videos) async {
    if (_awaitingLoadMoreConfirmation) {
      setState(() {
        _awaitingLoadMoreConfirmation = false;
      });
    }
    await _resumeCurrentVideoAfterBreakPrompt(videos);
  }

  void _showBreakPrompt(List<VideoEvent> videos) {
    if (_awaitingLoadMoreConfirmation ||
        _lastPromptedVideoCount == videos.length) {
      return;
    }

    setState(() {
      _awaitingLoadMoreConfirmation = true;
    });
    _pauseCurrentVideoForBreakPrompt(videos);
  }

  Future<void> _triggerLoadMore(List<VideoEvent> videos) async {
    if (_isLoadingMoreFromNudge) return;

    await _resumeCurrentVideoAfterBreakPrompt(videos);

    final currentVideoCount = videos.length;
    setState(() {
      _awaitingLoadMoreConfirmation = false;
      _isLoadingMoreFromNudge = true;
      _lastPromptedVideoCount = currentVideoCount;
    });

    try {
      await ref.read(homePaginationControllerProvider).maybeLoadMore();
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingMoreFromNudge = false;
      });
    }
  }

  bool _isForwardSwipeAtFeedEnd(ScrollNotification notification) {
    final isAtMaxExtent =
        notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 0.5;

    if (!isAtMaxExtent) return false;

    if (notification is OverscrollNotification) {
      return notification.overscroll > 0;
    }
    if (notification is ScrollUpdateNotification) {
      return (notification.scrollDelta ?? 0) > 0;
    }
    if (notification is UserScrollNotification) {
      return notification.direction == ScrollDirection.reverse;
    }

    return false;
  }

  static int _buildCount = 0;
  static DateTime? _lastBuildTime;

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    final now = DateTime.now();
    final timeSinceLastBuild = _lastBuildTime != null
        ? now.difference(_lastBuildTime!).inMilliseconds
        : null;
    if (timeSinceLastBuild != null && timeSinceLastBuild < 100) {
      Log.warning(
        '⚠️ HomeScreenRouter: RAPID REBUILD #$_buildCount! Only ${timeSinceLastBuild}ms since last build',
        name: 'HomeScreenRouter',
        category: LogCategory.video,
      );
    }
    _lastBuildTime = now;

    // Read the URL index synchronously from GoRouter instead of the
    // pageContextProvider stream. The stream oscillates during post-login
    // transitions (emitting stale /welcome/* locations after /home/0),
    // which prevents the home feed from ever loading.
    // HomeScreenRouter KNOWS it's the home screen — it's only mounted at
    // /home/:index — so it doesn't need route-type gating.
    final router = ref.read(goRouterProvider);
    final location = router.routeInformationProvider.value.uri.toString();
    final locationSegments = location
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    int urlIndex = 0;
    if (locationSegments.length > 1 && locationSegments[0] == 'home') {
      urlIndex = int.tryParse(locationSegments[1]) ?? 0;
      if (urlIndex < 0) urlIndex = 0;
    }

    // Watch homeFeedProvider directly — no route-type gate needed.
    // videosForHomeRouteProvider gates on pageContextProvider which
    // oscillates during post-login, causing the feed to never load.
    final videosAsync = ref.watch(homeFeedProvider);
    final nudgesEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.feedBreakNudges),
    );
    final useSleepCopy = isQuietHoursNow();

    return buildAsyncUI(
      videosAsync,
      onLoading: () => const Center(child: BrandedLoadingIndicator(size: 80)),
      onData: (state) {
        final videos = state.videos;

        if (state.lastUpdated == null && state.videos.isEmpty) {
          return const Center(child: BrandedLoadingIndicator(size: 80));
        }

        if (videos.isEmpty) {
          return const _EmptyHomeFeed();
        }

        if (_lastObservedVideoCount != videos.length) {
          _lastObservedVideoCount = videos.length;
          _awaitingLoadMoreConfirmation = false;
          _isLoadingMoreFromNudge = false;
          _lastPromptedVideoCount = null;
          _shouldResumeAfterBreakPrompt = false;
        }

        ScreenAnalyticsService().markDataLoaded(
          'home_feed',
          dataMetrics: {'video_count': videos.length},
        );

        // Clamp URL index to valid range
        urlIndex = urlIndex.clamp(0, videos.length - 1);

        final itemCount = videos.length;

        // Initialize controller once with URL index
        if (_controller == null) {
          final safeIndex = urlIndex.clamp(0, itemCount - 1);
          _controller = PageController(initialPage: safeIndex);
          _lastUrlIndex = safeIndex;
        }

        // Sync controller when URL changes externally (back/forward/deeplink)
        final syncTargetIndex = urlIndex.clamp(0, videos.length - 1);

        final shouldSyncNow = shouldSync(
          urlIndex: urlIndex,
          lastUrlIndex: _lastUrlIndex,
          controller: _controller,
          targetIndex: syncTargetIndex,
        );

        if (shouldSyncNow) {
          Log.debug(
            '🔄 SYNCING PageController: urlIndex=$urlIndex, lastUrlIndex=$_lastUrlIndex, currentPage=${_controller?.page?.round()}',
            name: 'HomeScreenRouter',
            category: LogCategory.video,
          );
          _lastUrlIndex = urlIndex;
          syncPageController(
            controller: _controller!,
            targetIndex: syncTargetIndex,
            itemCount: itemCount,
          );
        }

        // Prefetch profiles for adjacent videos (±1 index) only when URL index changes
        if (urlIndex != _lastPrefetchIndex) {
          _lastPrefetchIndex = urlIndex;
          final safeIndex = urlIndex.clamp(0, itemCount - 1);
          final pubkeysToPrefetech = <String>[];

          // Prefetch previous video's profile
          if (safeIndex > 0) {
            pubkeysToPrefetech.add(videos[safeIndex - 1].pubkey);
          }

          // Prefetch next video's profile
          if (safeIndex < itemCount - 1) {
            pubkeysToPrefetech.add(videos[safeIndex + 1].pubkey);
          }

          // Schedule prefetch for next frame to avoid doing work during build
          if (pubkeysToPrefetech.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref
                  .read(userProfileProvider.notifier)
                  .prefetchProfilesImmediately(pubkeysToPrefetech);
            });
          }
        }

        return RefreshIndicator(
          color: VineTheme.onPrimary,
          backgroundColor: VineTheme.vineGreen,
          semanticsLabel: 'searching for more videos',
          onRefresh: () => ref.read(homeRefreshControllerProvider).refresh(),
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  final currentIndex = _controller?.page?.round() ?? urlIndex;
                  final isAtEnd = currentIndex >= videos.length - 1;

                  if (nudgesEnabled &&
                      isAtEnd &&
                      _isForwardSwipeAtFeedEnd(notification)) {
                    if (!_awaitingLoadMoreConfirmation &&
                        _lastPromptedVideoCount != videos.length) {
                      _showBreakPrompt(videos);
                    } else if (_awaitingLoadMoreConfirmation &&
                        state.hasMoreContent) {
                      _triggerLoadMore(videos);
                    }
                  }
                  return false;
                },
                child: PageView.builder(
                  key: const Key('home-video-page-view'),
                  itemCount: itemCount,
                  controller: _controller,
                  scrollDirection: Axis.vertical,
                  onPageChanged: (newIndex) {
                    final isAtEnd = newIndex >= videos.length - 1;

                    // Guard: only navigate if URL doesn't match
                    if (newIndex != urlIndex) {
                      context.go(HomeScreenRouter.pathForIndex(newIndex));
                    }

                    if (!nudgesEnabled && state.hasMoreContent && isAtEnd) {
                      ref
                          .read(homePaginationControllerProvider)
                          .maybeLoadMore();
                    } else if (_awaitingLoadMoreConfirmation && !isAtEnd) {
                      _dismissBreakPrompt(videos);
                    }

                    // Prefetch videos around current index
                    checkForPrefetch(currentIndex: newIndex, videos: videos);

                    // Pre-initialize controllers for adjacent videos
                    preInitializeControllers(
                      ref: ref,
                      currentIndex: newIndex,
                      videos: videos,
                    );

                    // Dispose controllers outside the keep range to free memory
                    disposeControllersOutsideRange(
                      ref: ref,
                      currentIndex: newIndex,
                      videos: videos,
                    );

                    Log.debug(
                      '📄 Page changed to index $newIndex (${videos[newIndex].id}...)',
                      name: 'HomeScreenRouter',
                      category: LogCategory.video,
                    );
                  },
                  itemBuilder: (context, index) {
                    // Use PageController as source of truth for active video,
                    // not URL index. This prevents race conditions when videos
                    // reorder and URL update is pending.
                    final currentPage = _controller?.page?.round() ?? urlIndex;
                    final isActive = index == currentPage;

                    return VideoFeedItem(
                      key: ValueKey('video-${videos[index].id}'),
                      video: videos[index],
                      index: index,
                      hasBottomNavigation: false,
                      contextTitle: '', // Home feed has no context title
                      hideFollowButtonIfFollowing:
                          true, // Home feed only shows followed users
                      isActiveOverride: isActive,
                      trafficSource: ViewTrafficSource.home,
                    );
                  },
                ),
              ),
              if (nudgesEnabled &&
                  _awaitingLoadMoreConfirmation &&
                  (_controller?.page?.round() ?? urlIndex) >= videos.length - 1)
                _HomeFeedBreakOverlay(
                  useSleepCopy: useSleepCopy,
                  showLoadMoreAction: state.hasMoreContent,
                  isLoadingMore: _isLoadingMoreFromNudge || state.isLoadingMore,
                  onShowMore: () => _triggerLoadMore(videos),
                  onDismiss: () => _dismissBreakPrompt(videos),
                  videosSeen: videos.length,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyHomeFeed extends StatelessWidget {
  const _EmptyHomeFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Your Home Feed is Empty',
              style: TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Follow creators to see their videos here',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go(ExploreScreen.path),
              icon: const Icon(Icons.explore),
              label: const Text('Explore Videos'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeFeedBreakOverlay extends StatelessWidget {
  const _HomeFeedBreakOverlay({
    required this.useSleepCopy,
    required this.showLoadMoreAction,
    required this.isLoadingMore,
    required this.onShowMore,
    required this.onDismiss,
    required this.videosSeen,
  });

  final bool useSleepCopy;
  final bool showLoadMoreAction;
  final bool isLoadingMore;
  final VoidCallback onShowMore;
  final VoidCallback onDismiss;
  final int videosSeen;

  @override
  Widget build(BuildContext context) {
    final title = useSleepCopy
        ? "You've watched a lot tonight."
        : "You've watched a lot of videos...";
    final subtitle = useSleepCopy
        ? 'End of feed. Time to sleep and make tomorrow.'
        : 'Now go MAKE some.';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        if ((details.primaryDelta ?? 0) > 14) {
          onDismiss();
        }
      },
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 220) {
          onDismiss();
        }
      },
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: VineTheme.vineGreen.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: VineTheme.vineGreen),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You watched $videosSeen video${videosSeen == 1 ? '' : 's'} in Home.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: onDismiss,
                          child: const Text('Keep Watching'),
                        ),
                        const SizedBox(width: 8),
                        showLoadMoreAction
                            ? OutlinedButton(
                                onPressed: isLoadingMore ? null : onShowMore,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: VineTheme.vineGreen,
                                  side: const BorderSide(
                                    color: VineTheme.vineGreen,
                                  ),
                                ),
                                child: isLoadingMore
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Show More'),
                              )
                            : OutlinedButton.icon(
                                onPressed: () => context.go(ExploreScreen.path),
                                icon: const Icon(Icons.explore_outlined),
                                label: const Text('Explore'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: VineTheme.vineGreen,
                                  side: const BorderSide(
                                    color: VineTheme.vineGreen,
                                  ),
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Swipe down to dismiss this prompt.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
