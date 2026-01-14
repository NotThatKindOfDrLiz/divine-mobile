import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/repositories/video_controller_pool.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/blossom_auth_service.dart';
import 'package:openvine/services/video_cache_manager.dart';

@GenerateNiceMocks([
  MockSpec<VideoCacheManager>(),
  MockSpec<AgeVerificationService>(),
  MockSpec<BlossomAuthService>(),
  MockSpec<File>(),
])
import 'video_controller_pool_test.mocks.dart';

void main() {
  group('VideoControllerPool', () {
    late MockVideoCacheManager mockCacheManager;
    late MockAgeVerificationService mockAgeVerificationService;
    late MockBlossomAuthService mockBlossomAuthService;
    late VideoControllerPool pool;

    setUp(() {
      mockCacheManager = MockVideoCacheManager();
      mockAgeVerificationService = MockAgeVerificationService();
      mockBlossomAuthService = MockBlossomAuthService();

      pool = VideoControllerPool(
        cacheManager: mockCacheManager,
        ageVerificationService: mockAgeVerificationService,
        blossomAuthService: mockBlossomAuthService,
      );
    });

    tearDown(() {
      pool.dispose();
    });

    group('checkout', () {
      test('creates network controller when no cache exists', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        final result = pool.checkout(params);

        // Assert
        expect(result.controller, isNotNull);
        expect(result.isFromCache, isFalse);
        expect(result.wasExisting, isFalse);
        expect(result.videoUrl, equals('https://example.com/video.mp4'));
        expect(pool.activeCount, equals(1));
      });

      test('returns existing controller when already acquired', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act - acquire twice
        final result1 = pool.checkout(params);
        final result2 = pool.checkout(params);

        // Assert
        expect(result2.wasExisting, isTrue);
        expect(result2.controller, same(result1.controller));
        expect(pool.activeCount, equals(1)); // Only one in pool
      });

      test('normalizes .bin URL to .mp4 based on MIME type', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final mockVideoEvent = _MockVideoEvent(mimeType: 'video/mp4');
        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/abc123.bin',
          videoEvent: mockVideoEvent,
        );

        // Act
        final result = pool.checkout(params);

        // Assert
        expect(result.videoUrl, equals('https://example.com/abc123.mp4'));
      });

      test('normalizes .bin URL to .webm based on MIME type', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final mockVideoEvent = _MockVideoEvent(mimeType: 'video/webm');
        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/abc123.bin',
          videoEvent: mockVideoEvent,
        );

        // Act
        final result = pool.checkout(params);

        // Assert
        expect(result.videoUrl, equals('https://example.com/abc123.webm'));
      });

      test('does not normalize non-.bin URLs', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        final result = pool.checkout(params);

        // Assert
        expect(result.videoUrl, equals('https://example.com/video.mp4'));
      });
    });

    group('pool management', () {
      test('tracks active count correctly', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        // Act & Assert
        expect(pool.activeCount, equals(0));
        expect(pool.availableSlots, equals(4));
        expect(pool.isAtLimit, isFalse);

        pool.checkout(
          VideoControllerParams(
            videoId: 'video-1',
            videoUrl: 'https://example.com/1.mp4',
          ),
        );
        expect(pool.activeCount, equals(1));
        expect(pool.availableSlots, equals(3));

        pool.checkout(
          VideoControllerParams(
            videoId: 'video-2',
            videoUrl: 'https://example.com/2.mp4',
          ),
        );
        expect(pool.activeCount, equals(2));
        expect(pool.availableSlots, equals(2));
      });

      test('evicts LRU controller when at capacity', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        // Fill up the pool (4 controllers)
        for (int i = 1; i <= 4; i++) {
          final result = pool.checkout(
            VideoControllerParams(
              videoId: 'video-$i',
              videoUrl: 'https://example.com/$i.mp4',
            ),
          );
          // Mark as initialized so they can be evicted
          pool.markInitialized('video-$i');
          expect(result.wasExisting, isFalse);
        }

        expect(pool.activeCount, equals(4));
        expect(pool.isAtLimit, isTrue);

        // Act - add one more, should evict video-1 (LRU)
        final newResult = pool.checkout(
          VideoControllerParams(
            videoId: 'video-5',
            videoUrl: 'https://example.com/5.mp4',
          ),
        );

        // Assert
        expect(newResult.wasExisting, isFalse);
        expect(pool.activeCount, equals(4)); // Still at limit
        expect(pool.hasController('video-1'), isFalse); // Evicted
        expect(pool.hasController('video-5'), isTrue); // New one added
      });

      test('does not evict currently playing controller', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        // Fill up the pool
        for (int i = 1; i <= 4; i++) {
          pool.checkout(
            VideoControllerParams(
              videoId: 'video-$i',
              videoUrl: 'https://example.com/$i.mp4',
            ),
          );
          pool.markInitialized('video-$i');
        }

        // Mark video-1 as playing (would normally be LRU candidate)
        pool.markPlaying('video-1');

        // Act - add one more
        pool.checkout(
          VideoControllerParams(
            videoId: 'video-5',
            videoUrl: 'https://example.com/5.mp4',
          ),
        );

        // Assert - video-1 should NOT be evicted because it's playing
        expect(pool.hasController('video-1'), isTrue);
        // video-2 should be evicted instead (next LRU)
        expect(pool.hasController('video-2'), isFalse);
      });

      test('does not evict controllers still initializing', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        // Fill up the pool but don't mark video-1 as initialized
        pool.checkout(
          VideoControllerParams(
            videoId: 'video-1',
            videoUrl: 'https://example.com/1.mp4',
          ),
        );
        // video-1 is NOT marked as initialized

        for (int i = 2; i <= 4; i++) {
          pool.checkout(
            VideoControllerParams(
              videoId: 'video-$i',
              videoUrl: 'https://example.com/$i.mp4',
            ),
          );
          pool.markInitialized('video-$i');
        }

        // Act - add one more
        pool.checkout(
          VideoControllerParams(
            videoId: 'video-5',
            videoUrl: 'https://example.com/5.mp4',
          ),
        );

        // Assert - video-1 should NOT be evicted because it's initializing
        expect(pool.hasController('video-1'), isTrue);
        // video-2 should be evicted instead
        expect(pool.hasController('video-2'), isFalse);
      });
    });

    group('checkin (pool model)', () {
      test('keeps controller in pool but marks as idle', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        pool.checkout(params);
        expect(pool.activeCount, equals(1));
        expect(pool.checkedOutCount, equals(1));

        // Act - checkin returns to pool but does NOT remove
        pool.checkin('test-video-id');

        // Assert - controller still in pool
        expect(pool.activeCount, equals(1));
        expect(pool.hasController('test-video-id'), isTrue);
        // But now idle (not checked out)
        expect(pool.checkedOutCount, equals(0));
        expect(pool.idleCount, equals(1));
      });

      test('idle controllers are evicted first', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        // Fill up pool with 4 controllers
        for (int i = 1; i <= 4; i++) {
          pool.checkout(
            VideoControllerParams(
              videoId: 'video-$i',
              videoUrl: 'https://example.com/$i.mp4',
            ),
          );
          pool.markInitialized('video-$i');
        }

        // Checkin video-1 (make it idle)
        pool.checkin('video-1');
        expect(pool.idleCount, equals(1));

        // Act - add new controller, should evict idle video-1
        pool.checkout(
          VideoControllerParams(
            videoId: 'video-5',
            videoUrl: 'https://example.com/5.mp4',
          ),
        );

        // Assert - video-1 (idle) was evicted, not the checked-out ones
        expect(pool.hasController('video-1'), isFalse);
        expect(pool.hasController('video-5'), isTrue);
        // video-2,3,4 still present (were checked out)
        expect(pool.hasController('video-2'), isTrue);
      });
    });

    group('evict (explicit disposal)', () {
      test('removes and disposes controller from pool', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        pool.checkout(
          VideoControllerParams(
            videoId: 'test-video-id',
            videoUrl: 'https://example.com/video.mp4',
          ),
        );
        expect(pool.activeCount, equals(1));

        // Act
        pool.evict('test-video-id');

        // Assert
        expect(pool.activeCount, equals(0));
        expect(pool.hasController('test-video-id'), isFalse);
      });

      test('clears currently playing if evicted', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        pool.checkout(
          VideoControllerParams(
            videoId: 'test-video-id',
            videoUrl: 'https://example.com/video.mp4',
          ),
        );
        pool.markPlaying('test-video-id');
        expect(pool.currentlyPlayingVideoId, equals('test-video-id'));

        // Act
        pool.evict('test-video-id');

        // Assert
        expect(pool.currentlyPlayingVideoId, isNull);
      });
    });

    group('markPlaying and markNotPlaying', () {
      test('updates currently playing video', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        pool.checkout(
          VideoControllerParams(
            videoId: 'video-1',
            videoUrl: 'https://example.com/1.mp4',
          ),
        );
        pool.checkout(
          VideoControllerParams(
            videoId: 'video-2',
            videoUrl: 'https://example.com/2.mp4',
          ),
        );

        // Act & Assert
        expect(pool.currentlyPlayingVideoId, isNull);

        pool.markPlaying('video-1');
        expect(pool.currentlyPlayingVideoId, equals('video-1'));

        pool.markPlaying('video-2');
        expect(pool.currentlyPlayingVideoId, equals('video-2'));

        pool.markNotPlaying('video-2');
        expect(pool.currentlyPlayingVideoId, isNull);
      });
    });

    group('shouldCacheVideo', () {
      test('returns false when video is already cached', () {
        // Arrange
        final mockFile = MockFile();
        when(mockFile.existsSync()).thenReturn(true);
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(mockFile);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        final shouldCache = pool.shouldCacheVideo(params);

        // Assert
        expect(shouldCache, isFalse);
      });

      test('returns true when video is not cached', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        final shouldCache = pool.shouldCacheVideo(params);

        // Assert
        expect(shouldCache, isTrue);
      });

      test('returns true when cached file does not exist', () {
        // Arrange
        final mockFile = MockFile();
        when(mockFile.existsSync()).thenReturn(false);
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(mockFile);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        final shouldCache = pool.shouldCacheVideo(params);

        // Assert
        expect(shouldCache, isTrue);
      });
    });

    group('cacheAuthHeaders', () {
      test('does not cache when user has not verified adult content', () async {
        // Arrange
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        await pool.cacheAuthHeaders(params);

        // Assert
        verifyNever(
          mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: anyNamed('sha256Hash'),
            serverUrl: anyNamed('serverUrl'),
          ),
        );
      });

      test('caches auth headers when conditions are met', () async {
        // Arrange
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(true);
        when(mockBlossomAuthService.canCreateHeaders).thenReturn(true);
        when(
          mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: anyNamed('sha256Hash'),
            serverUrl: anyNamed('serverUrl'),
          ),
        ).thenAnswer((_) async => 'Bearer new-token');
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);

        final mockVideoEvent = _MockVideoEvent(sha256: 'abc123');
        final params = VideoControllerParams(
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
          videoEvent: mockVideoEvent,
        );

        // Act
        await pool.cacheAuthHeaders(params);

        // Assert - verify the method was called
        verify(
          mockBlossomAuthService.createGetAuthHeader(
            sha256Hash: 'abc123',
            serverUrl: 'https://example.com',
          ),
        ).called(1);
      });
    });

    group('clear', () {
      test('removes all controllers', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        for (int i = 1; i <= 3; i++) {
          pool.checkout(
            VideoControllerParams(
              videoId: 'video-$i',
              videoUrl: 'https://example.com/$i.mp4',
            ),
          );
        }
        pool.markPlaying('video-1');

        expect(pool.activeCount, equals(3));
        expect(pool.currentlyPlayingVideoId, equals('video-1'));

        // Act
        pool.clear();

        // Assert
        expect(pool.activeCount, equals(0));
        expect(pool.currentlyPlayingVideoId, isNull);
        expect(pool.hasController('video-1'), isFalse);
        expect(pool.hasController('video-2'), isFalse);
        expect(pool.hasController('video-3'), isFalse);
      });
    });

    group('toString', () {
      test('returns descriptive string', () {
        // Arrange
        when(mockCacheManager.getCachedVideoSync(any)).thenReturn(null);
        when(
          mockAgeVerificationService.isAdultContentVerified,
        ).thenReturn(false);

        pool.checkout(
          VideoControllerParams(
            videoId: 'test-video',
            videoUrl: 'https://example.com/video.mp4',
          ),
        );
        pool.markPlaying('test-video');

        // Act
        final result = pool.toString();

        // Assert
        expect(
          result,
          equals('VideoControllerPool(active: 1/4, playing: test-video)'),
        );
      });
    });
  });
}

/// Mock video event for testing
class _MockVideoEvent {
  _MockVideoEvent({this.mimeType, this.sha256});

  final String? mimeType;
  final String? sha256;
}
