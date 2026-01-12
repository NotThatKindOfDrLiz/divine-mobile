// ABOUTME: Tests for ProfileProviderCacheManager LRU cache functionality
// ABOUTME: Verifies that cache correctly tracks recent profiles and evicts old ones

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_provider_cache_manager.dart';
import 'package:openvine/services/video_event_service.dart';

import 'profile_provider_cache_manager_test.mocks.dart';

@GenerateMocks([VideoEventService])
void main() {
  group('ProfileProviderCacheManager', () {
    late ProviderContainer container;
    late MockVideoEventService mockVideoEventService;

    setUp(() {
      mockVideoEventService = MockVideoEventService();

      // Default stubs for VideoEventService
      when(mockVideoEventService.addListener(any)).thenAnswer((_) {});
      when(mockVideoEventService.removeListener(any)).thenAnswer((_) {});
      when(mockVideoEventService.addVideoUpdateListener(any))
          .thenReturn(() {});
      when(mockVideoEventService.addNewVideoListener(any)).thenReturn(() {});
      when(mockVideoEventService.authorVideos(any)).thenReturn([]);
      when(
        mockVideoEventService.subscribeToUserVideos(any, limit: anyNamed('limit')),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should start with empty cache', () {
      final cacheManager =
          container.read(profileProviderCacheManagerProvider.notifier);

      expect(cacheManager.cachedUserIds, isEmpty);
    });

    test('should add user to cache on recordAccess', () {
      final cacheManager =
          container.read(profileProviderCacheManagerProvider.notifier);

      cacheManager.recordAccess('user_1');

      expect(cacheManager.cachedUserIds, equals(['user_1']));
    });

    test('should maintain LRU order (most recent at end)', () {
      final cacheManager =
          container.read(profileProviderCacheManagerProvider.notifier);

      cacheManager.recordAccess('user_1');
      cacheManager.recordAccess('user_2');
      cacheManager.recordAccess('user_3');

      expect(cacheManager.cachedUserIds, equals(['user_1', 'user_2', 'user_3']));
    });

    test('should move existing user to end on re-access', () {
      final cacheManager =
          container.read(profileProviderCacheManagerProvider.notifier);

      cacheManager.recordAccess('user_1');
      cacheManager.recordAccess('user_2');
      cacheManager.recordAccess('user_3');
      cacheManager.recordAccess('user_1'); // Re-access user_1

      expect(cacheManager.cachedUserIds, equals(['user_2', 'user_3', 'user_1']));
    });

    test('should evict oldest user when cache exceeds max size', () {
      final cacheManager =
          container.read(profileProviderCacheManagerProvider.notifier);

      cacheManager.recordAccess('user_1');
      cacheManager.recordAccess('user_2');
      cacheManager.recordAccess('user_3');
      cacheManager.recordAccess('user_4'); // Should evict user_1

      expect(cacheManager.cachedUserIds, equals(['user_2', 'user_3', 'user_4']));
      expect(cacheManager.cachedUserIds.contains('user_1'), isFalse);
    });

    test('should keep only maxCachedProfiles users', () {
      final cacheManager =
          container.read(profileProviderCacheManagerProvider.notifier);

      // Add 5 users
      cacheManager.recordAccess('user_1');
      cacheManager.recordAccess('user_2');
      cacheManager.recordAccess('user_3');
      cacheManager.recordAccess('user_4');
      cacheManager.recordAccess('user_5');

      // Should only have last 3
      expect(cacheManager.cachedUserIds.length, equals(3));
      expect(cacheManager.cachedUserIds, equals(['user_3', 'user_4', 'user_5']));
    });

    test('should not duplicate user on multiple accesses', () {
      final cacheManager =
          container.read(profileProviderCacheManagerProvider.notifier);

      cacheManager.recordAccess('user_1');
      cacheManager.recordAccess('user_1');
      cacheManager.recordAccess('user_1');

      expect(cacheManager.cachedUserIds, equals(['user_1']));
      expect(cacheManager.cachedUserIds.length, equals(1));
    });

    test('evictUser should remove specific user from cache', () {
      final cacheManager =
          container.read(profileProviderCacheManagerProvider.notifier);

      cacheManager.recordAccess('user_1');
      cacheManager.recordAccess('user_2');
      cacheManager.recordAccess('user_3');

      cacheManager.evictUser('user_2');

      expect(cacheManager.cachedUserIds, equals(['user_1', 'user_3']));
    });

    test('evictUser should do nothing for non-cached user', () {
      final cacheManager =
          container.read(profileProviderCacheManagerProvider.notifier);

      cacheManager.recordAccess('user_1');
      cacheManager.evictUser('user_999'); // Not in cache

      expect(cacheManager.cachedUserIds, equals(['user_1']));
    });

    test('clearAll should empty the cache', () {
      final cacheManager =
          container.read(profileProviderCacheManagerProvider.notifier);

      cacheManager.recordAccess('user_1');
      cacheManager.recordAccess('user_2');
      cacheManager.recordAccess('user_3');

      cacheManager.clearAll();

      expect(cacheManager.cachedUserIds, isEmpty);
    });

    test('re-accessing evicted user should add them back', () {
      final cacheManager =
          container.read(profileProviderCacheManagerProvider.notifier);

      // Fill cache
      cacheManager.recordAccess('user_1');
      cacheManager.recordAccess('user_2');
      cacheManager.recordAccess('user_3');

      // Evict user_1 by adding user_4
      cacheManager.recordAccess('user_4');
      expect(cacheManager.cachedUserIds.contains('user_1'), isFalse);

      // Re-access user_1 - should add back and evict user_2
      cacheManager.recordAccess('user_1');
      expect(cacheManager.cachedUserIds, equals(['user_3', 'user_4', 'user_1']));
    });
  });
}
