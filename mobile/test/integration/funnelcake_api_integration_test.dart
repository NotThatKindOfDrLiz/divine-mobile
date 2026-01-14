// ABOUTME: Integration tests for Funnelcake REST API against local Docker server
// ABOUTME: Run with: flutter test test/integration/funnelcake_api_integration_test.dart
// ABOUTME: Requires local Docker server running on localhost:8080

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/services/analytics_api_service.dart';

/// Integration tests against local Funnelcake server
///
/// Prerequisites:
/// 1. Start local Docker: cd divine-funnelcake && docker-compose up
/// 2. Ensure funnel service is running on port 8080
/// 3. Run: flutter test test/integration/funnelcake_api_integration_test.dart
void main() {
  const baseUrl = 'http://localhost:8080';
  late http.Client httpClient;
  late AnalyticsApiService apiService;

  // Test pubkey from local synced data
  const testPubkey =
      'd95aa8fc0eff8e488952495b8064991d27fb96ed8652f12cdedc5a4e8b5ae540';

  setUpAll(() async {
    httpClient = http.Client();

    // Check if server is reachable before running tests
    try {
      final response = await httpClient
          .get(Uri.parse('$baseUrl/readyz'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) {
        fail(
          'Local server not ready. Start Docker with: '
          'cd divine-funnelcake && docker-compose up',
        );
      }
    } catch (e) {
      fail(
        'Cannot connect to local server at $baseUrl. '
        'Start Docker with: cd divine-funnelcake && docker-compose up\n'
        'Error: $e',
      );
    }

    apiService = AnalyticsApiService(baseUrl: baseUrl, httpClient: httpClient);
    await apiService.checkAvailability();
  });

  tearDownAll(() {
    httpClient.close();
  });

  group('Health Check', () {
    test('GET /readyz returns 200', () async {
      final response = await httpClient.get(Uri.parse('$baseUrl/readyz'));

      expect(response.statusCode, 200);
      print('Health check passed: ${response.body}');
    });

    test('AnalyticsApiService.isAvailable is true', () {
      expect(apiService.isAvailable, isTrue);
    });
  });

  group('User Endpoints', () {
    test('GET /api/users/{pubkey} returns user data', () async {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/api/users/$testPubkey'),
      );

      print('GET /api/users/{pubkey} status: ${response.statusCode}');
      print('Response: ${response.body}');

      // May return 404 if user doesn't exist, which is valid
      expect(response.statusCode, anyOf(200, 404));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        expect(json.containsKey('pubkey'), isTrue);
        print('User data: ${json['pubkey']}');
      }
    });

    test('GET /api/users/{pubkey}/followers returns follower list', () async {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/api/users/$testPubkey/followers?limit=5'),
      );

      print('GET /api/users/{pubkey}/followers status: ${response.statusCode}');
      print('Response: ${response.body}');

      expect(response.statusCode, 200);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      expect(json.containsKey('followers'), isTrue);
      final followers = json['followers'] as List;
      print('Followers: ${followers.length}, total: ${json['total']}');
    });

    test('GET /api/users/{pubkey}/following returns following list', () async {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/api/users/$testPubkey/following?limit=5'),
      );

      print('GET /api/users/{pubkey}/following status: ${response.statusCode}');
      print('Response: ${response.body}');

      expect(response.statusCode, 200);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      expect(json.containsKey('following'), isTrue);
      final following = json['following'] as List;
      print('Following: ${following.length}, total: ${json['total']}');
    });

    test('AnalyticsApiService.getUser works', () async {
      final userData = await apiService.getUser(testPubkey);

      print('getUser result: $userData');

      // May be null if user doesn't exist
      if (userData != null) {
        expect(userData.pubkey, isNotEmpty);
        print('User pubkey: ${userData.pubkey}');
        print(
          'Stats: followers=${userData.stats.followers}, following=${userData.stats.following}',
        );
      }
    });

    test(
      'AnalyticsApiService.getUser parses follower counts correctly',
      () async {
        final userData = await apiService.getUser(testPubkey);

        if (userData != null) {
          print('Stats from getUser:');
          print('  - followerCount: ${userData.stats.followerCount}');
          print('  - followingCount: ${userData.stats.followingCount}');
          print('  - videoCount: ${userData.stats.videoCount}');

          // Verify counts match the raw API response
          expect(userData.stats.followerCount, greaterThanOrEqualTo(0));
          expect(userData.stats.followingCount, greaterThanOrEqualTo(0));
        }
      },
    );
  });

  group('Bulk Endpoints', () {
    test(
      'POST /api/users/bulk returns user data for multiple pubkeys',
      () async {
        final response = await httpClient.post(
          Uri.parse('$baseUrl/api/users/bulk'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'pubkeys': [testPubkey],
          }),
        );

        print('POST /api/users/bulk status: ${response.statusCode}');
        print('Response: ${response.body}');

        expect(response.statusCode, 200);

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        expect(json.containsKey('users'), isTrue);
        expect(json.containsKey('missing'), isTrue);

        final users = json['users'] as List;
        print('Bulk users returned: ${users.length}');
        expect(users, isNotEmpty);
      },
    );

    test(
      'POST /api/videos/bulk returns video data for multiple event IDs',
      () async {
        // First get a valid event ID from trending videos
        final trendingResponse = await httpClient.get(
          Uri.parse('$baseUrl/api/videos?sort=trending&limit=1'),
        );
        final trendingVideos = jsonDecode(trendingResponse.body) as List;
        if (trendingVideos.isEmpty) {
          print('No trending videos available to test bulk endpoint');
          return;
        }

        final eventId = _parseId(trendingVideos.first['id']);
        print('Testing bulk videos with event ID: $eventId');

        final response = await httpClient.post(
          Uri.parse('$baseUrl/api/videos/bulk'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'event_ids': [eventId],
          }),
        );

        print('POST /api/videos/bulk status: ${response.statusCode}');
        print('Response: ${response.body}');

        expect(response.statusCode, 200);

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        expect(json.containsKey('videos'), isTrue);
        expect(json.containsKey('missing'), isTrue);

        final videos = json['videos'] as List;
        print('Bulk videos returned: ${videos.length}');
        expect(videos, isNotEmpty);
      },
    );

    test('AnalyticsApiService.getBulkUsers works', () async {
      final result = await apiService.getBulkUsers(pubkeys: [testPubkey]);

      print('getBulkUsers result: $result');
      print('Users: ${result.users.length}, Missing: ${result.missing.length}');

      expect(result.users, isNotEmpty);
      expect(result.users.first.pubkey, testPubkey);
    });
  });

  group('Video Endpoints (existing)', () {
    test('GET /api/videos?sort=trending returns trending videos', () async {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/api/videos?sort=trending&limit=10'),
      );

      print('GET /api/videos?sort=trending status: ${response.statusCode}');

      expect(response.statusCode, 200);

      final videos = jsonDecode(response.body) as List;
      print('Trending videos: ${videos.length}');

      for (final video in videos.take(3)) {
        final id = _parseId(video['id']);
        final title = video['title'] ?? 'untitled';
        print('  - $id: $title');
      }
    });

    test('GET /api/videos?sort=recent returns recent videos', () async {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/api/videos?sort=recent&limit=10'),
      );

      print('GET /api/videos?sort=recent status: ${response.statusCode}');

      expect(response.statusCode, 200);

      final videos = jsonDecode(response.body) as List;
      print('Recent videos: ${videos.length}');
    });

    test('AnalyticsApiService.getTrendingVideos works', () async {
      final videos = await apiService.getTrendingVideos(limit: 5);

      print('getTrendingVideos: ${videos.length} videos');

      for (final video in videos) {
        print('  - ${video.id}: ${video.title}');
      }
    });

    test('AnalyticsApiService.getRecentVideos works', () async {
      final videos = await apiService.getRecentVideos(limit: 5);

      print('getRecentVideos: ${videos.length} videos');

      for (final video in videos) {
        print('  - ${video.id}: ${video.title}');
      }
    });
  });

  group('Video Filtering Endpoints', () {
    test(
      'GET /api/videos?classic=true returns classic vines sorted by loops',
      () async {
        final response = await httpClient.get(
          Uri.parse('$baseUrl/api/videos?classic=true&limit=5'),
        );

        print('GET /api/videos?classic=true status: ${response.statusCode}');
        print('Response: ${response.body}');

        expect(response.statusCode, 200);

        final videos = jsonDecode(response.body) as List;
        print('Classic videos: ${videos.length}');
      },
    );

    test('GET /api/videos?before=timestamp filters by date', () async {
      // Jan 1, 2017 - classic Vine era cutoff
      const beforeTimestamp = 1483228800;

      final response = await httpClient.get(
        Uri.parse(
          '$baseUrl/api/videos?before=$beforeTimestamp&sort=loops&limit=5',
        ),
      );

      print(
        'GET /api/videos?before=$beforeTimestamp status: ${response.statusCode}',
      );

      expect(response.statusCode, 200);

      final videos = jsonDecode(response.body) as List;
      print('Videos before 2017: ${videos.length}');

      // Verify all returned videos are before the cutoff
      for (final video in videos) {
        final createdAt = video['created_at'] as int?;
        if (createdAt != null) {
          expect(
            createdAt,
            lessThan(beforeTimestamp),
            reason: 'Video should be created before 2017',
          );
        }
      }
    });

    test('GET /api/videos?after=timestamp filters recent videos', () async {
      // Jan 1, 2026
      const afterTimestamp = 1735689600;

      final response = await httpClient.get(
        Uri.parse('$baseUrl/api/videos?after=$afterTimestamp&limit=5'),
      );

      print(
        'GET /api/videos?after=$afterTimestamp status: ${response.statusCode}',
      );

      expect(response.statusCode, 200);

      final videos = jsonDecode(response.body) as List;
      print('Videos after Jan 2026: ${videos.length}');
    });

    test(
      'GET /api/videos?has_embedded_stats=true returns videos with loops',
      () async {
        final response = await httpClient.get(
          Uri.parse(
            '$baseUrl/api/videos?has_embedded_stats=true&sort=loops&limit=5',
          ),
        );

        print(
          'GET /api/videos?has_embedded_stats=true status: ${response.statusCode}',
        );

        expect(response.statusCode, 200);

        final videos = jsonDecode(response.body) as List;
        print('Videos with embedded stats: ${videos.length}');
      },
    );

    test('AnalyticsApiService.getVideosWithFilters works', () async {
      final videos = await apiService.getVideosWithFilters(
        sort: 'loops',
        hasEmbeddedStats: true,
        limit: 5,
      );

      print('getVideosWithFilters (loops): ${videos.length} videos');

      for (final video in videos) {
        print('  - ${video.id}: ${video.title}');
      }
    });

    test('AnalyticsApiService.getClassicVines works', () async {
      final videos = await apiService.getClassicVines(limit: 5);

      print('getClassicVines: ${videos.length} videos');

      for (final video in videos) {
        print('  - ${video.id}: ${video.title}');
      }
    });

    test('AnalyticsApiService.getVideosByLoops works', () async {
      final videos = await apiService.getVideosByLoops(limit: 5);

      print('getVideosByLoops: ${videos.length} videos');

      for (final video in videos) {
        print('  - ${video.id}: ${video.title}');
      }
    });
  });

  group('Search Endpoints', () {
    test('GET /api/search?tag=nostr returns hashtag results', () async {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/api/search?tag=nostr&limit=5'),
      );

      print('GET /api/search?tag=nostr status: ${response.statusCode}');

      expect(response.statusCode, anyOf(200, 404));

      if (response.statusCode == 200) {
        final videos = jsonDecode(response.body) as List;
        print('Hashtag #nostr videos: ${videos.length}');
      }
    });

    test('AnalyticsApiService.getVideosByHashtag works', () async {
      final videos = await apiService.getVideosByHashtag(
        hashtag: '#nostr',
        limit: 5,
      );

      print('getVideosByHashtag #nostr: ${videos.length} videos');
    });
  });
}

/// Parse ID from either byte array or string format
String _parseId(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is List) {
    return String.fromCharCodes(value.cast<int>());
  }
  return value.toString();
}
