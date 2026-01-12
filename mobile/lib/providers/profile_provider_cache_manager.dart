// ABOUTME: LRU cache manager for profile feed providers
// ABOUTME: Keeps only the 3 most recently accessed profiles in memory

import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_liked_feed_provider.dart';
import 'package:openvine/providers/profile_originals_feed_provider.dart';
import 'package:openvine/providers/profile_reposts_feed_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_provider_cache_manager.g.dart';

/// Manages LRU cache for profile feed providers.
///
/// Tracks the most recently accessed user profiles and automatically
/// invalidates providers for older profiles when the cache limit is exceeded.
///
/// Usage:
/// ```dart
/// // In profile grid widgets:
/// ref.read(profileProviderCacheManagerProvider.notifier).recordAccess(userId);
/// ```
@Riverpod(keepAlive: true)
class ProfileProviderCacheManager extends _$ProfileProviderCacheManager {
  /// Maximum number of profile provider sets to keep in memory.
  static const int maxCachedProfiles = 3;

  @override
  List<String> build() => []; // LRU list: most recent at end

  /// Records access to a user profile, updating LRU order.
  ///
  /// If this causes the cache to exceed [maxCachedProfiles], the oldest
  /// profile's providers are invalidated.
  void recordAccess(String userId) {
    final current = [...state];

    // Remove if already in list (will re-add at end)
    current.remove(userId);

    // Add to end (most recently accessed)
    current.add(userId);

    // Evict oldest profiles if over limit
    while (current.length > maxCachedProfiles) {
      final evicted = current.removeAt(0);
      _invalidateUserProviders(evicted);
    }

    state = current;
  }

  /// Returns the list of currently cached user IDs (for debugging/testing).
  List<String> get cachedUserIds => List.unmodifiable(state);

  /// Manually evicts a specific user from the cache.
  void evictUser(String userId) {
    if (state.contains(userId)) {
      final current = [...state];
      current.remove(userId);
      _invalidateUserProviders(userId);
      state = current;
    }
  }

  /// Clears all cached profile providers.
  void clearAll() {
    for (final userId in state) {
      _invalidateUserProviders(userId);
    }
    state = [];
  }

  /// Invalidates all 4 profile providers for a given user.
  void _invalidateUserProviders(String userId) {
    ref.invalidate(profileFeedProvider(userId));
    ref.invalidate(profileOriginalsFeedProvider(userId));
    ref.invalidate(profileRepostsFeedProvider(userId));
    ref.invalidate(profileLikedFeedProvider(userId));
  }
}
