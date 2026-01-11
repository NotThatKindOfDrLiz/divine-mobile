// ABOUTME: Feed provider for user's liked videos with pagination support
// ABOUTME: Family provider that works for any user (current user or others)

import 'dart:async';

import 'package:likes_repository/likes_repository.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_liked_feed_provider.g.dart';

/// Kind 7 is the NIP-25 reaction event kind.
const _reactionKind = 7;

/// NIP-25 reaction content for a like.
const _likeContent = '+';

/// Default limit for fetching reactions from relays.
const _defaultReactionFetchLimit = 500;

/// Feed provider for a user's liked videos
///
/// Provides VideoFeedState with sync and loadMore support for use in
/// FullscreenVideoFeedScreen with LikedVideosFeedSource.
///
/// This provider:
/// - For current user: Uses LikesRepository (has local cache)
/// - For other users: Queries relays directly for Kind 7 reactions
/// - Fetches video data from cache first, then relays
/// - Filters out unsupported video formats
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileLikedFeedProvider(userId));
/// await ref.read(profileLikedFeedProvider(userId).notifier).loadMore();
/// ```
@Riverpod(keepAlive: true)
class ProfileLikedFeed extends _$ProfileLikedFeed {
  @override
  Future<VideoFeedState> build(String userId) async {
    // Riverpod's AsyncNotifier guarantees that multiple watchers of the same
    // provider instance share the same build() future. This ensures:
    // 1. Grid and fullscreen views always see the same data
    // 2. No race conditions from concurrent builds
    // 3. The loading state is shown consistently to all watchers

    final videoEventService = ref.read(videoEventServiceProvider);
    final nostrClient = ref.read(nostrServiceProvider);
    final isCurrentUser = userId == nostrClient.publicKey;

    Log.info(
      'ProfileLikedFeedProvider: Starting sync for $userId '
      '(isCurrentUser: $isCurrentUser)',
      name: 'ProfileLikedFeedProvider',
      category: LogCategory.video,
    );

    try {
      // Get liked event IDs - different paths for current user vs others
      final List<String> likedEventIds;
      if (isCurrentUser) {
        // For current user, use LikesRepository (has local cache + relay sync)
        final likesRepository = ref.read(likesRepositoryProvider);
        final syncResult = await likesRepository.syncUserReactions();
        likedEventIds = syncResult.orderedEventIds;
      } else {
        // For other users, query relays directly for their Kind 7 reactions
        likedEventIds = await _fetchUserLikedEventIds(userId, nostrClient);
      }

      Log.info(
        'ProfileLikedFeedProvider: Synced ${likedEventIds.length} liked IDs '
        'for $userId',
        name: 'ProfileLikedFeedProvider',
        category: LogCategory.video,
      );

      if (likedEventIds.isEmpty) {
        return VideoFeedState(
          videos: [],
          hasMoreContent: false,
          lastUpdated: DateTime.now(),
        );
      }

      // Fetch video data for the liked IDs
      final videos = await _fetchVideos(
        likedEventIds,
        videoEventService,
        nostrClient,
      );

      Log.info(
        'ProfileLikedFeedProvider: Loaded ${videos.length} videos for $userId',
        name: 'ProfileLikedFeedProvider',
        category: LogCategory.video,
      );

      return VideoFeedState(
        videos: videos,
        // Liked videos are currently loaded all at once
        // Set hasMoreContent based on whether we might have pagination later
        hasMoreContent: false,
        lastUpdated: DateTime.now(),
      );
    } on SyncFailedException catch (e) {
      Log.error(
        'ProfileLikedFeedProvider: Sync failed for $userId - ${e.message}',
        name: 'ProfileLikedFeedProvider',
        category: LogCategory.video,
      );
      return VideoFeedState(
        videos: [],
        hasMoreContent: false,
        error: 'Sync failed: ${e.message}',
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      Log.error(
        'ProfileLikedFeedProvider: Failed to load videos for $userId - $e',
        name: 'ProfileLikedFeedProvider',
        category: LogCategory.video,
      );
      return VideoFeedState(
        videos: [],
        hasMoreContent: false,
        error: 'Failed to load videos',
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Refresh the liked videos list
  ///
  /// Re-syncs liked IDs and fetches all videos again.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Load more videos (placeholder for future pagination support)
  ///
  /// Currently liked videos are loaded all at once during sync.
  /// This method is here for API consistency with other feed providers.
  Future<void> loadMore() async {
    final currentState = state.value;
    if (currentState == null ||
        currentState.isLoadingMore ||
        !currentState.hasMoreContent) {
      return;
    }

    // Pagination not yet implemented for liked videos
    // When implemented, this would fetch the next page of liked video IDs
    Log.info(
      'ProfileLikedFeedProvider: loadMore called '
      '(pagination not yet implemented)',
      name: 'ProfileLikedFeedProvider',
      category: LogCategory.video,
    );
  }

  /// Fetch liked event IDs for another user from relays
  ///
  /// Queries Kind 7 reactions by the specified user and extracts
  /// the target event IDs (the events they liked).
  Future<List<String>> _fetchUserLikedEventIds(
    String userPubkey,
    dynamic nostrClient,
  ) async {
    final completer = Completer<List<String>>();
    final likedIds = <String>[];
    final seenIds = <String>{}; // Deduplicate
    StreamSubscription<dynamic>? subscription;

    final subscriptionId =
        'liked_ids_${userPubkey.substring(0, 8)}_'
        '${DateTime.now().millisecondsSinceEpoch}';

    Future<void> cleanup() async {
      await subscription?.cancel();
      await nostrClient.unsubscribe(subscriptionId);
    }

    // Add timeout to prevent hanging
    final timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        Log.warning(
          'ProfileLikedFeedProvider: Liked IDs fetch timed out with ${likedIds.length} IDs',
          name: 'ProfileLikedFeedProvider',
          category: LogCategory.video,
        );
        cleanup();
        completer.complete(likedIds);
      }
    });

    try {
      // Query Kind 7 reactions by this user
      final filter = Filter(
        kinds: const [_reactionKind],
        authors: [userPubkey],
        limit: _defaultReactionFetchLimit,
      );

      final eventStream = nostrClient.subscribe(
        [filter],
        subscriptionId: subscriptionId,
        onEose: () {
          if (!completer.isCompleted) {
            Log.info(
              'ProfileLikedFeedProvider: EOSE received for liked IDs, '
              'got ${likedIds.length}',
              name: 'ProfileLikedFeedProvider',
              category: LogCategory.video,
            );
            timeoutTimer.cancel();
            cleanup();
            completer.complete(likedIds);
          }
        },
      );

      subscription = eventStream.listen(
        (event) {
          // Only count '+' reactions (likes, not other reactions)
          if (event.content == _likeContent) {
            final targetId = _extractTargetEventId(event);
            if (targetId != null && !seenIds.contains(targetId)) {
              seenIds.add(targetId);
              likedIds.add(targetId);
            }
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            timeoutTimer.cancel();
            cleanup();
            completer.complete(likedIds);
          }
        },
        onError: (Object error) {
          Log.error(
            'ProfileLikedFeedProvider: Stream error fetching liked IDs: $error',
            name: 'ProfileLikedFeedProvider',
            category: LogCategory.video,
          );
          if (!completer.isCompleted) {
            timeoutTimer.cancel();
            cleanup();
            completer.complete(likedIds);
          }
        },
      );

      return completer.future;
    } catch (e) {
      Log.error(
        'ProfileLikedFeedProvider: Failed to fetch liked IDs: $e',
        name: 'ProfileLikedFeedProvider',
        category: LogCategory.video,
      );
      timeoutTimer.cancel();
      await cleanup();
      return likedIds;
    }
  }

  /// Extract target event ID from a Kind 7 reaction event's 'e' tag
  String? _extractTargetEventId(dynamic event) {
    for (final tag in event.tags) {
      if (tag is List && tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
        return tag[1] as String;
      }
    }
    return null;
  }

  /// Fetch videos for the given event IDs
  ///
  /// 1. Check cache first
  /// 2. Fetch missing videos from relays
  /// 3. Return ordered list matching the input order
  Future<List<VideoEvent>> _fetchVideos(
    List<String> likedEventIds,
    dynamic videoEventService,
    dynamic nostrClient,
  ) async {
    final cachedVideosMap = <String, VideoEvent>{};
    final missingIds = <String>[];

    // Check cache first
    for (final eventId in likedEventIds) {
      final cached = videoEventService.getVideoById(eventId) as VideoEvent?;
      if (cached != null) {
        cachedVideosMap[eventId] = cached;
      } else {
        missingIds.add(eventId);
      }
    }

    Log.info(
      'ProfileLikedFeedProvider: Found ${cachedVideosMap.length} in cache, '
      '${missingIds.length} need relay fetch',
      name: 'ProfileLikedFeedProvider',
      category: LogCategory.video,
    );

    // Fetch missing videos from relays
    if (missingIds.isNotEmpty) {
      final fetchedVideos = await _fetchVideosFromRelay(
        missingIds,
        nostrClient,
      );
      for (final video in fetchedVideos) {
        cachedVideosMap[video.id] = video;
      }

      Log.info(
        'ProfileLikedFeedProvider: Fetched ${fetchedVideos.length} from relay',
        name: 'ProfileLikedFeedProvider',
        category: LogCategory.video,
      );
    }

    // Build ordered list using the recency-ordered IDs
    final orderedVideos = <VideoEvent>[];
    for (final eventId in likedEventIds) {
      final video = cachedVideosMap[eventId];
      if (video != null) {
        orderedVideos.add(video);
      }
    }

    // Filter out unsupported videos (WebM on iOS/macOS)
    return orderedVideos.where((v) => v.isSupportedOnCurrentPlatform).toList();
  }

  /// Fetch videos from relays by their event IDs
  Future<List<VideoEvent>> _fetchVideosFromRelay(
    List<String> eventIds,
    dynamic nostrClient,
  ) async {
    if (eventIds.isEmpty) return [];

    final completer = Completer<List<VideoEvent>>();
    final videos = <VideoEvent>[];
    StreamSubscription<dynamic>? subscription;

    // Generate unique subscription ID for cleanup
    final subscriptionId =
        'liked_videos_provider_${DateTime.now().millisecondsSinceEpoch}';

    Future<void> cleanup() async {
      await subscription?.cancel();
      await nostrClient.unsubscribe(subscriptionId);
    }

    // Add timeout to prevent hanging
    final timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        Log.warning(
          'ProfileLikedFeedProvider: Relay fetch timed out with '
          '${videos.length} videos',
          name: 'ProfileLikedFeedProvider',
          category: LogCategory.video,
        );
        cleanup();
        completer.complete(videos);
      }
    });

    try {
      // Create filter for video events by ID
      // NIP-71 kinds: 34235 (horizontal), 34236 (vertical/short)
      final filter = Filter(ids: eventIds, kinds: [34235, 34236]);

      final eventStream = nostrClient.subscribe(
        [filter],
        subscriptionId: subscriptionId,
        onEose: () {
          // Complete when all relays finish sending stored events
          if (!completer.isCompleted) {
            Log.info(
              'ProfileLikedFeedProvider: EOSE received, completing with '
              '${videos.length} videos',
              name: 'ProfileLikedFeedProvider',
              category: LogCategory.video,
            );
            timeoutTimer.cancel();
            cleanup();
            completer.complete(videos);
          }
        },
      );

      subscription = eventStream.listen(
        (event) {
          try {
            final video = VideoEvent.fromNostrEvent(event);
            videos.add(video);
          } catch (e) {
            Log.warning(
              'ProfileLikedFeedProvider: Failed to parse event ${event.id}: $e',
              name: 'ProfileLikedFeedProvider',
              category: LogCategory.video,
            );
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            timeoutTimer.cancel();
            cleanup();
            completer.complete(videos);
          }
        },
        onError: (Object error) {
          Log.error(
            'ProfileLikedFeedProvider: Stream error: $error',
            name: 'ProfileLikedFeedProvider',
            category: LogCategory.video,
          );
          if (!completer.isCompleted) {
            timeoutTimer.cancel();
            cleanup();
            completer.complete(videos);
          }
        },
      );

      return completer.future;
    } catch (e) {
      Log.error(
        'ProfileLikedFeedProvider: Failed to fetch from relay: $e',
        name: 'ProfileLikedFeedProvider',
        category: LogCategory.video,
      );
      timeoutTimer.cancel();
      await cleanup();
      return videos;
    }
  }
}
