// ABOUTME: Feed provider for user's original videos with pagination support
// ABOUTME: Wraps profileOriginalsProvider with VideoFeedState for fullscreen feed

import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_originals_provider.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_originals_feed_provider.g.dart';

/// Feed provider for user's original videos (excluding reposts)
///
/// Provides VideoFeedState with loadMore() support for use in
/// FullscreenVideoFeedScreen with ProfileOriginalsFeedSource.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileOriginalsFeedProvider(userId));
/// await ref.read(profileOriginalsFeedProvider(userId).notifier).loadMore();
/// ```
@Riverpod(keepAlive: true)
class ProfileOriginalsFeed extends _$ProfileOriginalsFeed {
  @override
  Future<VideoFeedState> build(String userId) async {
    // Watch the filtered originals list - this will auto-update when
    // profileFeedProvider changes
    final originals = await ref.watch(profileOriginalsProvider(userId).future);

    return VideoFeedState(
      videos: originals,
      hasMoreContent: originals.length >= 10,
      isLoadingMore: false,
      lastUpdated: DateTime.now(),
    );
  }

  /// Load more videos by delegating to the base profile feed provider
  ///
  /// When base provider loads more, profileOriginalsProvider will re-filter
  /// and this provider will automatically rebuild with new originals.
  Future<void> loadMore() async {
    final currentState = await future;

    if (currentState.isLoadingMore || !currentState.hasMoreContent) {
      return;
    }

    // Delegate to base provider's loadMore - it handles the actual relay query
    await ref.read(profileFeedProvider(userId).notifier).loadMore();

    // No need to manually update state - watching profileOriginalsProvider
    // will trigger a rebuild when the base provider updates
  }
}
