// ABOUTME: PopularNow feed provider showing newest videos with REST API + Nostr fallback
// ABOUTME: Tries Funnelcake REST API first, falls back to Nostr subscription if unavailable

import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/helpers/video_feed_builder.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'popular_now_feed_provider.g.dart';

/// PopularNow feed provider - shows newest videos (sorted by creation time)
///
/// Strategy: Try Funnelcake REST API first for better performance and engagement
/// sorting, fall back to Nostr subscription if REST API is unavailable.
///
/// Rebuilds when:
/// - Poll interval elapses (uses same auto-refresh as home feed)
/// - User pulls to refresh
/// - VideoEventService updates with new videos
/// - appReady gate becomes true (triggers rebuild to start subscription)
@Riverpod(keepAlive: true) // Keep alive to prevent state loss on tab switches
class PopularNowFeed extends _$PopularNowFeed {
  VideoFeedBuilder? _builder;
  bool _usingRestApi = false;
  int? _nextCursor; // Cursor for REST API pagination

  @override
  Future<VideoFeedState> build() async {
    // Reset cursor state at start of build to ensure clean state
    _usingRestApi = false;
    _nextCursor = null;

    // Watch appReady gate - provider rebuilds when this changes
    final isAppReady = ref.watch(appReadyProvider);

    Log.info(
      '🆕 PopularNowFeed: Building feed for newest videos (appReady: $isAppReady)',
      name: 'PopularNowFeedProvider',
      category: LogCategory.video,
    );

    final videoEventService = ref.watch(videoEventServiceProvider);

    // If app is not ready, return empty state - will rebuild when appReady becomes true
    if (!isAppReady) {
      Log.info(
        '🆕 PopularNowFeed: App not ready, returning empty state (will rebuild when ready)',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );
      return VideoFeedState(
        videos: const [],
        hasMoreContent: true, // Assume there's content to load when ready
        isLoadingMore: false,
      );
    }

    // Try REST API first if available (use centralized availability check)
    final funnelcakeAvailable =
        ref.watch(funnelcakeAvailableProvider).asData?.value ?? false;
    final analyticsService = ref.read(analyticsApiServiceProvider);
    if (funnelcakeAvailable) {
      Log.info(
        '🆕 PopularNowFeed: Trying Funnelcake REST API first',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );

      try {
        final apiVideos = await analyticsService.getRecentVideos(limit: 100);
        if (apiVideos.isNotEmpty) {
          _usingRestApi = true;
          // Store cursor for pagination (oldest video timestamp)
          _nextCursor = _getOldestTimestamp(apiVideos);

          // Filter for platform compatibility
          final platformFiltered = apiVideos
              .where((v) => v.isSupportedOnCurrentPlatform)
              .toList();

          // Log incoming videos before deduplication to diagnose issues
          Log.debug(
            '📝 PopularNowFeed build(): ${platformFiltered.length} videos before dedup: ${platformFiltered.map((v) => '"${v.title}" vineId=${(v.vineId ?? 'null').length >= 8 ? (v.vineId ?? 'null').substring(0, 8) : v.vineId ?? 'null'}').join(', ')}',
            name: 'PopularNowFeedProvider',
            category: LogCategory.video,
          );

          // Deduplicate by vineId + pubkey, keeping newest version of each video
          // REST API may return multiple events for the same addressable video
          // (previous edit versions), so we must keep only the newest
          // Note: if vineId is null (shouldn't happen for NIP-71), fall back to event id
          final videosByStableId = <String, VideoEvent>{};
          var duplicatesFound = 0;
          for (final v in platformFiltered) {
            // Use vineId for addressable events, fall back to event id if null
            final stableId = '${v.pubkey}:${v.vineId ?? v.id}';
            final existing = videosByStableId[stableId];
            if (existing == null) {
              videosByStableId[stableId] = v;
            } else if (v.createdAt > existing.createdAt) {
              // Found a newer version of the same video
              duplicatesFound++;
              Log.debug(
                '📝 PopularNowFeed dedup: Replacing "${existing.title}" (ts=${existing.createdAt}) with "${v.title}" (ts=${v.createdAt}) for vineId=${v.vineId}',
                name: 'PopularNowFeedProvider',
                category: LogCategory.video,
              );
              videosByStableId[stableId] = v;
            } else {
              // Found an older version, skip it
              duplicatesFound++;
              Log.debug(
                '📝 PopularNowFeed dedup: Skipping older "${v.title}" (ts=${v.createdAt}) keeping "${existing.title}" (ts=${existing.createdAt}) for vineId=${v.vineId}',
                name: 'PopularNowFeedProvider',
                category: LogCategory.video,
              );
            }
          }
          final filteredVideos = videosByStableId.values.toList();

          Log.info(
            '✅ PopularNowFeed: Got ${filteredVideos.length} videos from REST API (deduped $duplicatesFound from ${platformFiltered.length}), cursor: $_nextCursor',
            name: 'PopularNowFeedProvider',
            category: LogCategory.video,
          );

          return VideoFeedState(
            videos: filteredVideos,
            hasMoreContent:
                apiVideos.length >= AppConstants.paginationBatchSize,
            isLoadingMore: false,
            lastUpdated: DateTime.now(),
          );
        }
        Log.warning(
          '🆕 PopularNowFeed: REST API returned empty, falling back to Nostr',
          name: 'PopularNowFeedProvider',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          '🆕 PopularNowFeed: REST API failed ($e), falling back to Nostr',
          name: 'PopularNowFeedProvider',
          category: LogCategory.video,
        );
      }
    }

    // Fall back to Nostr subscription
    _usingRestApi = false;
    _builder = VideoFeedBuilder(videoEventService);

    // Configure feed for popularNow subscription type
    final config = VideoFeedConfig(
      subscriptionType: SubscriptionType.popularNow,
      subscribe: (service) async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.popularNow,
          limit: 100,
          sortBy: VideoSortField.createdAt, // Newest videos first
        );
      },
      getVideos: (service) => service.popularNowVideos,
      filterVideos: (videos) {
        // Filter out WebM videos on iOS/macOS (not supported by AVPlayer)
        return videos.where((v) => v.isSupportedOnCurrentPlatform).toList();
      },
      sortVideos: (videos) {
        final sorted = List<VideoEvent>.from(videos);
        sorted.sort((a, b) {
          final timeCompare = b.timestamp.compareTo(a.timestamp);
          if (timeCompare != 0) return timeCompare;
          // Secondary sort by ID for stable ordering
          return a.id.compareTo(b.id);
        });
        return sorted;
      },
    );

    // Build feed using helper
    final state = await _builder!.buildFeed(config: config);

    // Check if still mounted after async gap
    if (!ref.mounted) {
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
      );
    }

    // Set up continuous listener for updates
    _builder!.setupContinuousListener(
      config: config,
      onUpdate: (newState) {
        if (ref.mounted) {
          this.state = AsyncData(newState);
        }
      },
    );

    // Register for video update callbacks to auto-refresh when any video is updated
    final unregisterVideoUpdate = videoEventService.addVideoUpdateListener((
      updated,
    ) {
      if (ref.mounted) {
        refreshFromService(updated);
      }
    });

    // Clean up on dispose
    ref.onDispose(() {
      _builder?.cleanup();
      _builder = null;
      unregisterVideoUpdate(); // Clean up video update callback
      Log.info(
        '🆕 PopularNowFeed: Disposed',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );
    });

    Log.info(
      '✅ PopularNowFeed: Feed built with ${state.videos.length} videos (Nostr fallback)',
      name: 'PopularNowFeedProvider',
      category: LogCategory.video,
    );

    return state;
  }

  /// Load more historical events
  Future<void> loadMore() async {
    final currentState = await future;

    if (!ref.mounted || currentState.isLoadingMore) {
      return;
    }

    // Update state to show loading
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      // If using REST API, load more using cursor-based pagination
      if (_usingRestApi) {
        final analyticsService = ref.read(analyticsApiServiceProvider);

        Log.info(
          '🆕 PopularNowFeed: Loading more from REST API with cursor: $_nextCursor',
          name: 'PopularNowFeedProvider',
          category: LogCategory.video,
        );

        // Use cursor (before parameter) for pagination
        final apiVideos = await analyticsService.getRecentVideos(
          limit: 50,
          before: _nextCursor,
        );

        if (!ref.mounted) return;

        if (apiVideos.isNotEmpty) {
          // Deduplicate by vineId + pubkey (stable identifier for addressable events)
          // not event ID, since edits create new IDs but same vineId
          // Note: if vineId is null (shouldn't happen for NIP-71), fall back to event id
          final existingByStableId = <String, VideoEvent>{};
          for (final v in currentState.videos) {
            existingByStableId['${v.pubkey}:${v.vineId ?? v.id}'] = v;
          }

          final newVideos = <VideoEvent>[];
          for (final v in apiVideos) {
            if (!v.isSupportedOnCurrentPlatform) continue;
            final stableId = '${v.pubkey}:${v.vineId ?? v.id}';
            final existing = existingByStableId[stableId];
            if (existing == null) {
              // Truly new video
              newVideos.add(v);
            } else if (v.createdAt > existing.createdAt) {
              // Newer version of existing video
              existingByStableId[stableId] = v;
            }
          }

          // Rebuild current videos with any updated versions
          final updatedCurrentVideos = currentState.videos.map((v) {
            final stableId = '${v.pubkey}:${v.vineId ?? v.id}';
            return existingByStableId[stableId] ?? v;
          }).toList();

          // Update cursor for next pagination
          _nextCursor = _getOldestTimestamp(apiVideos);

          if (newVideos.isNotEmpty) {
            final allVideos = [...updatedCurrentVideos, ...newVideos];
            Log.info(
              '🆕 PopularNowFeed: Loaded ${newVideos.length} new videos from REST API (total: ${allVideos.length})',
              name: 'PopularNowFeedProvider',
              category: LogCategory.video,
            );

            state = AsyncData(
              VideoFeedState(
                videos: allVideos,
                hasMoreContent:
                    apiVideos.length >= AppConstants.paginationBatchSize,
                isLoadingMore: false,
                lastUpdated: DateTime.now(),
              ),
            );
          } else {
            Log.info(
              '🆕 PopularNowFeed: All returned videos already in state',
              name: 'PopularNowFeedProvider',
              category: LogCategory.video,
            );
            // Still use updatedCurrentVideos in case existing videos were refreshed
            state = AsyncData(
              VideoFeedState(
                videos: updatedCurrentVideos,
                hasMoreContent:
                    apiVideos.length >= AppConstants.paginationBatchSize,
                isLoadingMore: false,
                lastUpdated: DateTime.now(),
              ),
            );
          }
        } else {
          Log.info(
            '🆕 PopularNowFeed: No more videos available from REST API',
            name: 'PopularNowFeedProvider',
            category: LogCategory.video,
          );
          state = AsyncData(
            currentState.copyWith(hasMoreContent: false, isLoadingMore: false),
          );
        }
        return;
      }

      // Nostr mode - load more from relay
      final videoEventService = ref.read(videoEventServiceProvider);
      final eventCountBefore = videoEventService.getEventCount(
        SubscriptionType.popularNow,
      );

      // Load more events for popularNow subscription type
      await videoEventService.loadMoreEvents(
        SubscriptionType.popularNow,
        limit: 50,
      );

      if (!ref.mounted) return;

      final eventCountAfter = videoEventService.getEventCount(
        SubscriptionType.popularNow,
      );
      final newEventsLoaded = eventCountAfter - eventCountBefore;

      Log.info(
        '🆕 PopularNowFeed: Loaded $newEventsLoaded new events from Nostr (total: $eventCountAfter)',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );

      // Reset loading state - state will auto-update via listener
      final newState = await future;
      if (!ref.mounted) return;
      state = AsyncData(
        newState.copyWith(
          isLoadingMore: false,
          hasMoreContent: newEventsLoaded > 0,
        ),
      );
    } catch (e) {
      Log.error(
        '🆕 PopularNowFeed: Error loading more: $e',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );

      if (!ref.mounted) return;
      final currentState = await future;
      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
  }

  /// Refresh state from VideoEventService without re-subscribing to relay
  /// Call this after a video is updated to sync the provider's state
  void refreshFromService([VideoEvent? updatedVideo]) {
    Log.info(
      '📝 PopularNowFeed.refreshFromService called: updatedVideo=${updatedVideo != null}, _usingRestApi=$_usingRestApi',
      name: 'PopularNowFeedProvider',
      category: LogCategory.video,
    );

    if (!state.hasValue || state.value == null) return;
    final currentState = state.value!;

    List<VideoEvent> updatedVideos;

    if (_usingRestApi) {
      // REST API mode: update the specific video in our cached list
      if (updatedVideo != null) {
        int updatedCount = 0;
        updatedVideos = currentState.videos.map((v) {
          // Match by stable identifier (vineId + pubkey) for addressable events
          if (v.vineId == updatedVideo.vineId &&
              v.pubkey == updatedVideo.pubkey) {
            updatedCount++;
            return updatedVideo;
          }
          return v;
        }).toList();
        Log.info(
          '📝 PopularNowFeed.refreshFromService: REST API mode - updated $updatedCount video(s) with title="${updatedVideo.title}"',
          name: 'PopularNowFeedProvider',
          category: LogCategory.video,
        );
      } else {
        // No specific video to update, keep current state
        return;
      }
    } else {
      // Nostr mode: get fresh list from service
      final videoEventService = ref.read(videoEventServiceProvider);
      updatedVideos = videoEventService.popularNowVideos.toList();
    }

    // Apply same filtering as build()
    updatedVideos = updatedVideos
        .where((v) => v.isSupportedOnCurrentPlatform)
        .toList();

    // Sort by timestamp (newest first)
    updatedVideos.sort((a, b) {
      final timeCompare = b.timestamp.compareTo(a.timestamp);
      if (timeCompare != 0) return timeCompare;
      return a.id.compareTo(b.id);
    });

    state = AsyncData(
      VideoFeedState(
        videos: updatedVideos,
        hasMoreContent:
            updatedVideos.length >= AppConstants.hasMoreContentThreshold,
        isLoadingMore: false,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  /// Refresh the feed - invalidates self to re-run build() with REST API fallback logic
  Future<void> refresh() async {
    Log.info(
      '🆕 PopularNowFeed: Refreshing feed (will try REST API first)',
      name: 'PopularNowFeedProvider',
      category: LogCategory.video,
    );

    // If using REST API, try to refresh from there first
    if (_usingRestApi) {
      try {
        final analyticsService = ref.read(analyticsApiServiceProvider);
        final apiVideos = await analyticsService.getRecentVideos(
          limit: 100,
          forceRefresh: true,
        );

        // Check if provider is still mounted after async gap
        if (!ref.mounted) return;

        if (apiVideos.isNotEmpty) {
          // Reset cursor for pagination
          _nextCursor = _getOldestTimestamp(apiVideos);

          // Filter for platform compatibility
          final platformFiltered = apiVideos
              .where((v) => v.isSupportedOnCurrentPlatform)
              .toList();

          // Deduplicate by vineId + pubkey, keeping newest version of each video
          // REST API may return multiple events for the same addressable video
          // (previous edit versions), so we must keep only the newest
          // Note: if vineId is null (shouldn't happen for NIP-71), fall back to event id
          final videosByStableId = <String, VideoEvent>{};
          var duplicatesFound = 0;
          for (final v in platformFiltered) {
            final stableId = '${v.pubkey}:${v.vineId ?? v.id}';
            final existing = videosByStableId[stableId];
            if (existing == null) {
              videosByStableId[stableId] = v;
            } else if (v.createdAt > existing.createdAt) {
              duplicatesFound++;
              videosByStableId[stableId] = v;
            } else {
              duplicatesFound++;
            }
          }
          final filteredVideos = videosByStableId.values.toList();

          state = AsyncData(
            VideoFeedState(
              videos: filteredVideos,
              hasMoreContent:
                  apiVideos.length >= AppConstants.paginationBatchSize,
              isLoadingMore: false,
              lastUpdated: DateTime.now(),
            ),
          );

          Log.info(
            '✅ PopularNowFeed: Refreshed ${filteredVideos.length} videos from REST API (deduped $duplicatesFound from ${platformFiltered.length}), cursor: $_nextCursor',
            name: 'PopularNowFeedProvider',
            category: LogCategory.video,
          );
          return;
        }
      } catch (e) {
        Log.warning(
          '🆕 PopularNowFeed: REST API refresh failed, falling back to Nostr',
          name: 'PopularNowFeedProvider',
          category: LogCategory.video,
        );
      }
    }

    // Reset cursor state before invalidating
    _usingRestApi = false;
    _nextCursor = null;

    // Invalidate to re-run build() which will try REST API then Nostr
    ref.invalidateSelf();
  }

  /// Get oldest timestamp from videos for cursor pagination
  int? _getOldestTimestamp(List<VideoEvent> videos) {
    if (videos.isEmpty) return null;
    return videos.map((v) => v.createdAt).reduce((a, b) => a < b ? a : b);
  }
}

/// Provider to check if popularNow feed is loading
@riverpod
bool popularNowFeedLoading(Ref ref) {
  final asyncState = ref.watch(popularNowFeedProvider);
  if (asyncState.isLoading) return true;

  final state = asyncState.hasValue ? asyncState.value : null;
  if (state == null) return false;

  return state.isLoadingMore;
}

/// Provider to get current popularNow feed video count
@riverpod
int popularNowFeedCount(Ref ref) {
  final asyncState = ref.watch(popularNowFeedProvider);
  return asyncState.hasValue ? (asyncState.value?.videos.length ?? 0) : 0;
}
