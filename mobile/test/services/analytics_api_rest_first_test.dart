// ABOUTME: Unit tests for AnalyticsApiService REST-first with Nostr fallback behavior
// ABOUTME: Tests availability checks and the critical path for non-funnelcake users

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/analytics_api_service.dart';

@GenerateMocks([http.Client])
import 'analytics_api_rest_first_test.mocks.dart';

void main() {
  group('AnalyticsApiService availability check tests', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test(
      'checkAvailability() sets _isReachable = true on successful health check',
      () async {
        // Arrange
        final service = AnalyticsApiService(
          baseUrl: 'https://funnelcake.test',
          httpClient: mockClient,
        );

        when(
          mockClient.get(any, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('OK', 200));

        // Before checkAvailability, isAvailable should be false (not checked yet)
        expect(service.isAvailable, isFalse);

        // Act
        await service.checkAvailability();

        // Assert
        expect(service.isAvailable, isTrue);
        verify(
          mockClient.get(
            Uri.parse('https://funnelcake.test/readyz'),
            headers: anyNamed('headers'),
          ),
        ).called(1);
      },
    );

    test('checkAvailability() sets _isReachable = false on timeout', () async {
      // Arrange
      final service = AnalyticsApiService(
        baseUrl: 'https://funnelcake.test',
        httpClient: mockClient,
      );

      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => throw TimeoutException('Connection timed out'));

      // Act
      await service.checkAvailability();

      // Assert
      expect(service.isAvailable, isFalse);
    });

    test(
      'checkAvailability() sets _isReachable = false on network error',
      () async {
        // Arrange
        final service = AnalyticsApiService(
          baseUrl: 'https://funnelcake.test',
          httpClient: mockClient,
        );

        when(
          mockClient.get(any, headers: anyNamed('headers')),
        ).thenThrow(Exception('Network error'));

        // Act
        await service.checkAvailability();

        // Assert
        expect(service.isAvailable, isFalse);
      },
    );

    test(
      'checkAvailability() sets _isReachable = false on non-200 status',
      () async {
        // Arrange
        final service = AnalyticsApiService(
          baseUrl: 'https://funnelcake.test',
          httpClient: mockClient,
        );

        when(
          mockClient.get(any, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('Service Unavailable', 503));

        // Act
        await service.checkAvailability();

        // Assert
        expect(service.isAvailable, isFalse);
      },
    );

    test(
      'checkAvailability() sets _isReachable = false when no baseUrl configured',
      () async {
        // Arrange - null baseUrl
        final serviceNull = AnalyticsApiService(
          baseUrl: null,
          httpClient: mockClient,
        );

        // Act
        await serviceNull.checkAvailability();

        // Assert
        expect(serviceNull.isAvailable, isFalse);
        // Should not make any HTTP calls
        verifyNever(mockClient.get(any, headers: anyNamed('headers')));
      },
    );

    test(
      'checkAvailability() sets _isReachable = false when baseUrl is empty',
      () async {
        // Arrange - empty baseUrl
        final serviceEmpty = AnalyticsApiService(
          baseUrl: '',
          httpClient: mockClient,
        );

        // Act
        await serviceEmpty.checkAvailability();

        // Assert
        expect(serviceEmpty.isAvailable, isFalse);
        // Should not make any HTTP calls
        verifyNever(mockClient.get(any, headers: anyNamed('headers')));
      },
    );

    test('isAvailable returns false before checkAvailability() is called', () {
      // Arrange - service with valid baseUrl but no availability check
      final service = AnalyticsApiService(
        baseUrl: 'https://funnelcake.test',
        httpClient: mockClient,
      );

      // Assert - should be false because _isReachable is null (not checked)
      expect(service.isAvailable, isFalse);
    });

    test(
      'isAvailable returns false when baseUrl is null regardless of reachability',
      () {
        // Arrange
        final service = AnalyticsApiService(
          baseUrl: null,
          httpClient: mockClient,
        );

        // Assert
        expect(service.isAvailable, isFalse);
      },
    );
  });

  group('REST-first pattern tests', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('getTrendingVideos uses REST when isAvailable returns true', () async {
      // Arrange
      final service = AnalyticsApiService(
        baseUrl: 'https://funnelcake.test',
        httpClient: mockClient,
      );

      // Setup health check to pass
      when(
        mockClient.get(
          Uri.parse('https://funnelcake.test/readyz'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('OK', 200));

      // Setup video API response
      when(
        mockClient.get(
          argThat(predicate<Uri>((uri) => uri.path == '/api/videos')),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '[{"id":"video1","pubkey":"pub1","created_at":1700000000,'
          '"kind":34236,"d_tag":"","title":"Test Video",'
          '"thumbnail":"","video_url":"https://example.com/video.mp4",'
          '"reactions":10,"comments":2,"reposts":1,"engagement_score":15}]',
          200,
        ),
      );

      // Check availability first
      await service.checkAvailability();
      expect(service.isAvailable, isTrue);

      // Act
      final videos = await service.getTrendingVideos();

      // Assert
      expect(videos.length, 1);
      expect(videos.first.title, 'Test Video');
      verify(
        mockClient.get(
          argThat(predicate<Uri>((uri) => uri.path == '/api/videos')),
          headers: anyNamed('headers'),
        ),
      ).called(1);
    });

    test(
      'getTrendingVideos returns empty list when REST throws exception after available',
      () async {
        // Arrange
        final service = AnalyticsApiService(
          baseUrl: 'https://funnelcake.test',
          httpClient: mockClient,
        );

        // Setup health check to pass
        when(
          mockClient.get(
            Uri.parse('https://funnelcake.test/readyz'),
            headers: anyNamed('headers'),
          ),
        ).thenAnswer((_) async => http.Response('OK', 200));

        // Setup video API to throw exception
        when(
          mockClient.get(
            argThat(predicate<Uri>((uri) => uri.path == '/api/videos')),
            headers: anyNamed('headers'),
          ),
        ).thenThrow(Exception('API Error'));

        await service.checkAvailability();
        expect(service.isAvailable, isTrue);

        // Act - service handles exception gracefully
        final videos = await service.getTrendingVideos();

        // Assert - returns empty list (caller can fall back to Nostr)
        expect(videos, isEmpty);
      },
    );

    test(
      'getTrendingVideos skips REST entirely when isAvailable is false (no timeout delay)',
      () async {
        // Arrange - service not available (no baseUrl)
        final service = AnalyticsApiService(
          baseUrl: null,
          httpClient: mockClient,
        );

        // Act - should return immediately without HTTP call
        final stopwatch = Stopwatch()..start();
        final videos = await service.getTrendingVideos();
        stopwatch.stop();

        // Assert
        expect(videos, isEmpty);
        // Should complete quickly (no timeout waiting)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        // Should not make any HTTP calls
        verifyNever(mockClient.get(any, headers: anyNamed('headers')));
      },
    );

    test(
      'API methods return empty results without HTTP calls when unavailable',
      () async {
        // Arrange - service with failed availability check
        final service = AnalyticsApiService(
          baseUrl: 'https://funnelcake.test',
          httpClient: mockClient,
        );

        // Setup health check to fail
        when(
          mockClient.get(any, headers: anyNamed('headers')),
        ).thenThrow(Exception('Connection refused'));

        await service.checkAvailability();
        expect(service.isAvailable, isFalse);

        // Reset mock to track only subsequent calls
        reset(mockClient);

        // Act - try various API methods
        final trending = await service.getTrendingVideos();
        final recent = await service.getRecentVideos();
        final hashtag = await service.getVideosByHashtag(hashtag: 'test');
        final search = await service.searchVideos(query: 'test');
        final stats = await service.getVideoStats('eventId');
        final authorVideos = await service.getVideosByAuthor(pubkey: 'pubkey');

        // Assert - all should return empty/null without HTTP calls
        expect(trending, isEmpty);
        expect(recent, isEmpty);
        expect(hashtag, isEmpty);
        expect(search, isEmpty);
        expect(stats, isNull);
        expect(authorVideos, isEmpty);

        // Should not make any HTTP calls after availability check failed
        verifyNever(mockClient.get(any, headers: anyNamed('headers')));
        verifyNever(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        );
      },
    );

    test('REST result is cached appropriately', () async {
      // Arrange
      final service = AnalyticsApiService(
        baseUrl: 'https://funnelcake.test',
        httpClient: mockClient,
      );

      // Setup health check to pass
      when(
        mockClient.get(
          Uri.parse('https://funnelcake.test/readyz'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('OK', 200));

      // Setup video API response
      when(
        mockClient.get(
          argThat(predicate<Uri>((uri) => uri.path == '/api/videos')),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '[{"id":"video1","pubkey":"pub1","created_at":1700000000,'
          '"kind":34236,"d_tag":"","title":"Cached Video",'
          '"thumbnail":"","video_url":"https://example.com/video.mp4",'
          '"reactions":10,"comments":2,"reposts":1,"engagement_score":15}]',
          200,
        ),
      );

      await service.checkAvailability();

      // Act - call twice
      final firstCall = await service.getTrendingVideos();
      final secondCall = await service.getTrendingVideos();

      // Assert
      expect(firstCall.length, 1);
      expect(secondCall.length, 1);
      expect(firstCall.first.title, 'Cached Video');
      expect(secondCall.first.title, 'Cached Video');

      // Should only make one API call (second call uses cache)
      verify(
        mockClient.get(
          argThat(predicate<Uri>((uri) => uri.path == '/api/videos')),
          headers: anyNamed('headers'),
        ),
      ).called(1);
    });

    test('forceRefresh bypasses cache', () async {
      // Arrange
      final service = AnalyticsApiService(
        baseUrl: 'https://funnelcake.test',
        httpClient: mockClient,
      );

      // Setup health check to pass
      when(
        mockClient.get(
          Uri.parse('https://funnelcake.test/readyz'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('OK', 200));

      var callCount = 0;
      when(
        mockClient.get(
          argThat(predicate<Uri>((uri) => uri.path == '/api/videos')),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        return http.Response(
          '[{"id":"video$callCount","pubkey":"pub1","created_at":1700000000,'
          '"kind":34236,"d_tag":"","title":"Video $callCount",'
          '"thumbnail":"","video_url":"https://example.com/video.mp4",'
          '"reactions":10,"comments":2,"reposts":1,"engagement_score":15}]',
          200,
        );
      });

      await service.checkAvailability();

      // Act - call with forceRefresh
      final firstCall = await service.getTrendingVideos();
      final secondCall = await service.getTrendingVideos(forceRefresh: true);

      // Assert
      expect(firstCall.first.title, 'Video 1');
      expect(secondCall.first.title, 'Video 2');

      // Should make two API calls
      verify(
        mockClient.get(
          argThat(predicate<Uri>((uri) => uri.path == '/api/videos')),
          headers: anyNamed('headers'),
        ),
      ).called(2);
    });
  });

  group('Non-funnelcake user critical path tests', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('users without funnelcake config experience no delays', () async {
      // This test ensures non-funnelcake users don't wait for timeouts

      // Arrange - no baseUrl configured (standard relay user)
      final service = AnalyticsApiService(
        baseUrl: null,
        httpClient: mockClient,
      );

      // Act - time multiple API calls
      final stopwatch = Stopwatch()..start();

      await service.checkAvailability();
      await service.getTrendingVideos();
      await service.getRecentVideos();
      await service.getVideosByHashtag(hashtag: 'nostr');
      await service.searchVideos(query: 'test');

      stopwatch.stop();

      // Assert - all calls should complete nearly instantly
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
      expect(service.isAvailable, isFalse);

      // No HTTP calls should be made
      verifyNever(mockClient.get(any, headers: anyNamed('headers')));
    });

    test(
      'availability check only happens once and is quick for unavailable services',
      () async {
        // Arrange
        final service = AnalyticsApiService(
          baseUrl: 'https://funnelcake.unreachable',
          httpClient: mockClient,
        );

        // Setup health check to timeout quickly (our internal timeout is 2 seconds)
        when(
          mockClient.get(any, headers: anyNamed('headers')),
        ).thenAnswer((_) async => throw TimeoutException('Timed out'));

        // Act
        final stopwatch = Stopwatch()..start();
        await service.checkAvailability();
        stopwatch.stop();

        // Assert - availability check should fail but not block for long
        expect(service.isAvailable, isFalse);
        // HTTP call was attempted
        verify(mockClient.get(any, headers: anyNamed('headers'))).called(1);

        // Subsequent API calls should not retry availability
        reset(mockClient);
        await service.getTrendingVideos();
        verifyNever(mockClient.get(any, headers: anyNamed('headers')));
      },
    );
  });
}
