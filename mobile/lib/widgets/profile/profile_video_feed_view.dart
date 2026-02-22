// ABOUTME: Fullscreen video feed view for profile screens
// ABOUTME: Reusable between own profile and others' profile screens

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/mixins/page_controller_sync_mixin.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/quiet_hours.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

/// Fullscreen video feed view for profile screens.
///
/// Displays videos in a vertical PageView with URL sync, prefetching,
/// and pagination support.
class ProfileVideoFeedView extends ConsumerStatefulWidget {
  const ProfileVideoFeedView({
    required this.npub,
    required this.userIdHex,
    required this.isOwnProfile,
    required this.videos,
    required this.videoIndex,
    required this.onPageChanged,
    super.key,
  });

  /// The npub of the profile (for URL updates).
  final String npub;

  /// The hex public key of the profile.
  final String userIdHex;

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  /// List of videos to display.
  final List<VideoEvent> videos;

  /// Current video index from URL.
  final int videoIndex;

  /// Callback when page changes (for URL updates).
  final void Function(int newIndex) onPageChanged;

  @override
  ConsumerState<ProfileVideoFeedView> createState() =>
      _ProfileVideoFeedViewState();
}

class _ProfileVideoFeedViewState extends ConsumerState<ProfileVideoFeedView>
    with VideoPrefetchMixin, PageControllerSyncMixin {
  PageController? _pageController;
  int? _lastVideoUrlIndex;
  bool _awaitingLoadMoreConfirmation = false;
  bool _isLoadingMoreFromNudge = false;
  int? _lastPromptedVideoCount;
  bool _shouldResumeAfterBreakPrompt = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(ProfileVideoFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.videos.length != oldWidget.videos.length) {
      _awaitingLoadMoreConfirmation = false;
      _isLoadingMoreFromNudge = false;
      _lastPromptedVideoCount = null;
      _shouldResumeAfterBreakPrompt = false;
    }

    // Handle video index changes from URL
    if (widget.videoIndex != oldWidget.videoIndex) {
      _syncControllerToUrl();
    }
  }

  void _initializeController() {
    final safeIndex = widget.videoIndex.clamp(0, widget.videos.length - 1);

    Log.debug(
      '🎬 ProfileVideoFeedView init: videoIndex=${widget.videoIndex}, '
      'safeIndex=$safeIndex, videos.length=${widget.videos.length}',
      name: 'ProfileVideoFeedView',
      category: LogCategory.video,
    );

    _pageController = PageController(initialPage: safeIndex);
    _lastVideoUrlIndex = widget.videoIndex;

    // Pre-initialize controllers for adjacent videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      preInitializeControllers(
        ref: ref,
        currentIndex: safeIndex,
        videos: widget.videos,
      );
    });
  }

  void _syncControllerToUrl() {
    if (_pageController == null) return;

    final listIndex = widget.videoIndex;
    final targetIndex = listIndex.clamp(0, widget.videos.length - 1);
    final currentPage = _pageController!.hasClients
        ? _pageController!.page?.round()
        : null;

    Log.debug(
      '🔄 Checking sync: urlIndex=$listIndex, lastUrlIndex=$_lastVideoUrlIndex, '
      'hasClients=${_pageController!.hasClients}, currentPage=$currentPage, '
      'targetIndex=$targetIndex',
      name: 'ProfileVideoFeedView',
      category: LogCategory.video,
    );

    if (shouldSync(
      urlIndex: listIndex,
      lastUrlIndex: _lastVideoUrlIndex,
      controller: _pageController,
      targetIndex: targetIndex,
    )) {
      Log.info(
        '📍 Syncing PageController: $currentPage → $targetIndex',
        name: 'ProfileVideoFeedView',
        category: LogCategory.video,
      );
      _lastVideoUrlIndex = listIndex;
      syncPageController(
        controller: _pageController!,
        targetIndex: listIndex,
        itemCount: widget.videos.length,
      );
    }
  }

  Future<void> _triggerLoadMore(int currentVideoCount) async {
    if (_isLoadingMoreFromNudge) return;

    await _resumeCurrentVideoAfterBreakPrompt();

    setState(() {
      _awaitingLoadMoreConfirmation = false;
      _isLoadingMoreFromNudge = true;
      _lastPromptedVideoCount = currentVideoCount;
    });

    try {
      await ref.read(profileFeedProvider(widget.userIdHex).notifier).loadMore();
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingMoreFromNudge = false;
      });
    }
  }

  Future<void> _pauseCurrentVideoForBreakPrompt() async {
    final currentIndex = _pageController?.hasClients == true
        ? (_pageController!.page?.round() ?? widget.videoIndex)
        : widget.videoIndex;
    if (currentIndex < 0 || currentIndex >= widget.videos.length) return;

    final video = widget.videos[currentIndex];
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

  Future<void> _resumeCurrentVideoAfterBreakPrompt() async {
    if (!_shouldResumeAfterBreakPrompt) return;

    final currentIndex = _pageController?.hasClients == true
        ? (_pageController!.page?.round() ?? widget.videoIndex)
        : widget.videoIndex;
    if (currentIndex < 0 || currentIndex >= widget.videos.length) return;

    final video = widget.videos[currentIndex];
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

  Future<void> _dismissBreakPrompt() async {
    if (_awaitingLoadMoreConfirmation) {
      setState(() {
        _awaitingLoadMoreConfirmation = false;
      });
    }
    await _resumeCurrentVideoAfterBreakPrompt();
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

  void _showBreakPrompt() {
    if (_awaitingLoadMoreConfirmation ||
        _lastPromptedVideoCount == widget.videos.length) {
      return;
    }

    setState(() {
      _awaitingLoadMoreConfirmation = true;
    });
    _pauseCurrentVideoForBreakPrompt();
  }

  void _handlePageChanged(
    int newIndex, {
    required bool hasMoreContent,
    required bool nudgesEnabled,
  }) {
    final isAtEnd = newIndex >= widget.videos.length - 1;

    // Update URL when swiping
    if (newIndex != widget.videoIndex) {
      widget.onPageChanged(newIndex);
    }

    if (!nudgesEnabled && hasMoreContent && isAtEnd) {
      ref.read(profileFeedProvider(widget.userIdHex).notifier).loadMore();
    } else if (_awaitingLoadMoreConfirmation && !isAtEnd) {
      _dismissBreakPrompt();
    }

    // Prefetch videos around current index
    checkForPrefetch(currentIndex: newIndex, videos: widget.videos);

    // Pre-initialize controllers for adjacent videos
    preInitializeControllers(
      ref: ref,
      currentIndex: newIndex,
      videos: widget.videos,
    );

    // Dispose controllers outside the keep range to free memory
    disposeControllersOutsideRange(
      ref: ref,
      currentIndex: newIndex,
      videos: widget.videos,
    );
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileFeedState = ref
        .watch(profileFeedProvider(widget.userIdHex))
        .asData
        ?.value;
    final hasMoreContent = profileFeedState?.hasMoreContent ?? false;
    final isLoadingMore =
        profileFeedState?.isLoadingMore == true || _isLoadingMoreFromNudge;
    final nudgesEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.feedBreakNudges),
    );
    final useSleepCopy = isQuietHoursNow();
    final itemCount = widget.videos.length;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            final isAtEnd =
                (_pageController?.page?.round() ?? widget.videoIndex) >=
                widget.videos.length - 1;

            if (nudgesEnabled &&
                isAtEnd &&
                _isForwardSwipeAtFeedEnd(notification)) {
              if (!_awaitingLoadMoreConfirmation &&
                  _lastPromptedVideoCount != widget.videos.length) {
                _showBreakPrompt();
              } else if (_awaitingLoadMoreConfirmation && hasMoreContent) {
                _triggerLoadMore(widget.videos.length);
              }
            }
            return false;
          },
          child: PageView.builder(
            key: const Key('profile-video-page-view'),
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: itemCount,
            onPageChanged: (index) => _handlePageChanged(
              index,
              hasMoreContent: hasMoreContent,
              nudgesEnabled: nudgesEnabled,
            ),
            itemBuilder: (context, index) {
              // Use PageController as source of truth for active video
              final currentPage =
                  _pageController?.page?.round() ?? widget.videoIndex;
              final isActive = index == currentPage;

              final video = widget.videos[index];
              return VideoFeedItem(
                key: ValueKey('video-${video.stableId}'),
                video: video,
                index: index,
                hasBottomNavigation: false,
                forceShowOverlay: widget.isOwnProfile,
                isActiveOverride: isActive,
                contextTitle: ref
                    .read(fetchUserProfileProvider(widget.userIdHex))
                    .value
                    ?.betterDisplayName('Profile'),
                hideFollowButtonIfFollowing:
                    true, // Hide if already following this profile's user
                trafficSource: ViewTrafficSource.profile,
              );
            },
          ),
        ),
        if (nudgesEnabled &&
            _awaitingLoadMoreConfirmation &&
            (_pageController?.page?.round() ?? widget.videoIndex) >=
                widget.videos.length - 1)
          _ProfileFeedBreakOverlay(
            useSleepCopy: useSleepCopy,
            showLoadMoreAction: hasMoreContent,
            isLoadingMore: isLoadingMore,
            onShowMore: () => _triggerLoadMore(widget.videos.length),
            onDismiss: _dismissBreakPrompt,
            videosSeen: widget.videos.length,
          ),
      ],
    );
  }
}

class _ProfileFeedBreakOverlay extends StatelessWidget {
  const _ProfileFeedBreakOverlay({
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
        ? "You've watched a lot on this profile tonight."
        : "You've watched a lot from this creator...";
    final subtitle = useSleepCopy
        ? 'You are caught up here. Time to sleep and make tomorrow.'
        : 'You are caught up here. Now go MAKE some.';

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
                    color: Colors.greenAccent.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.park_outlined, color: Colors.greenAccent),
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
                      'You watched $videosSeen video${videosSeen == 1 ? '' : 's'} from this profile.',
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
                        if (showLoadMoreAction)
                          OutlinedButton(
                            onPressed: isLoadingMore ? null : onShowMore,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.greenAccent,
                              side: const BorderSide(color: Colors.greenAccent),
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
