// ABOUTME: Feed provider for user's reposted videos with pagination support
// ABOUTME: Wraps profileRepostsProvider with VideoFeedState for fullscreen feed

import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_reposts_provider.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_reposts_feed_provider.g.dart';

/// Feed provider for user's reposted videos
///
/// Provides VideoFeedState with loadMore() support for use in
/// FullscreenVideoFeedScreen with ProfileRepostsFeedSource.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileRepostsFeedProvider(userId));
/// await ref.read(profileRepostsFeedProvider(userId).notifier).loadMore();
/// ```
@Riverpod(keepAlive: true)
class ProfileRepostsFeed extends _$ProfileRepostsFeed {
  @override
  Future<VideoFeedState> build(String userId) async {
    // Watch the filtered reposts list - this will auto-update when
    // profileFeedProvider changes
    final reposts = await ref.watch(profileRepostsProvider(userId).future);

    return VideoFeedState(
      videos: reposts,
      hasMoreContent: reposts.length >= 10,
      isLoadingMore: false,
      lastUpdated: DateTime.now(),
    );
  }

  /// Load more videos by delegating to the base profile feed provider
  ///
  /// When base provider loads more, profileRepostsProvider will re-filter
  /// and this provider will automatically rebuild with new reposts.
  Future<void> loadMore() async {
    final currentState = await future;

    if (currentState.isLoadingMore || !currentState.hasMoreContent) {
      return;
    }

    // Delegate to base provider's loadMore - it handles the actual relay query
    await ref.read(profileFeedProvider(userId).notifier).loadMore();

    // No need to manually update state - watching profileRepostsProvider
    // will trigger a rebuild when the base provider updates
  }
}
