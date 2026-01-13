# Plan: Funnelcake REST API Integration

## Summary

Use REST API endpoints for slow queries when connected to a funnelcake relay, with automatic Nostr fallback.

**MVP Scope:** Profile loading, home feed, bulk profiles for feed authors.

## Why REST over WebSocket

| Aspect | REST API | Nostr WebSocket |
|--------|----------|-----------------|
| **Caching** | CDN + HTTP headers | Not cacheable |
| **Computation** | Pre-computed ClickHouse | Per-request |
| **Latency** | Single request | REQ → EVENTs → EOSE |

**Performance wins:**
- Profile page: ~3s → ~200ms
- Follower counts: 8s timeout → ~50ms
- Home feed (20k+ follows): works vs times out

## Fallback Behavior (CRITICAL)

**The app MUST work on any Nostr relay.** REST is an optimization, not a requirement.

| Scenario | Behavior |
|----------|----------|
| Funnelcake relay | REST API (fast) |
| **Any other Nostr relay** | **Standard Nostr queries (always works)** |
| Funnelcake down | Auto-fallback to Nostr |
| User switches relays | Detect and use appropriate method |

**Detection:** `EnvironmentConfig.apiBaseUrl` returns URL for funnelcake, `null` otherwise.

```dart
// In AnalyticsApiService
bool get isAvailable => _baseUrl != null && _isReachable;
```

When `isAvailable` is false, ALL queries go through existing Nostr code paths.

### No Timeout Delays (IMPORTANT)

**Problem:** If we try REST on every query and wait for timeout, non-funnelcake users get 10s delays.

**Solution:** Check availability ONCE at startup, cache the result.

```dart
class AnalyticsApiService {
  bool? _isReachable;  // null = not checked, true/false = cached result

  /// Fast sync check - no network call
  bool get isAvailable => _baseUrl != null && (_isReachable ?? false);

  /// Call once at app startup (non-blocking)
  Future<void> checkAvailability() async {
    if (_baseUrl == null) {
      _isReachable = false;  // No URL configured, skip forever
      return;
    }
    try {
      // Quick health check with SHORT timeout (2s, not 10s)
      final response = await _client
          .get(Uri.parse('$_baseUrl/readyz'))
          .timeout(const Duration(seconds: 2));
      _isReachable = response.statusCode == 200;
    } catch (e) {
      _isReachable = false;  // Failed, use Nostr for this session
    }
  }
}
```

**Behavior:**
| Scenario | `_baseUrl` | `_isReachable` | `isAvailable` | Result |
|----------|------------|----------------|---------------|--------|
| Non-funnelcake relay | `null` | `false` | `false` | **Instant skip to Nostr** |
| Funnelcake, healthy | URL | `true` | `true` | Use REST |
| Funnelcake, down | URL | `false` | `false` | **Instant skip to Nostr** |
| Before check runs | URL | `null` | `false` | Safe default to Nostr |

**No delays:** The `isAvailable` getter is synchronous. If REST isn't available, we skip it instantly with zero network calls.

## Server API Contract (from server plan)

**Combined endpoints** - server returns all data in single responses:

```
GET  /api/users/{pubkey}         → UserData (profile + stats + social)
GET  /api/users/{pubkey}/social  → SocialStats (just counts - lighter)
GET  /api/users/{pubkey}/feed    → FeedResponse (videos + pagination)
POST /api/users/bulk             → BulkUsersResponse (profiles + stats)
POST /api/users/social/bulk      → BulkSocialResponse (follower counts)
POST /api/videos/bulk            → BulkVideosResponse (from IDs or Kind 30005)
```

**Response structures:**
```dart
// GET /api/users/{pubkey}
class UserData {
  final String pubkey;
  final UserProfile profile;  // name, picture, about, nip05, etc.
  final UserStats stats;      // video_count, followers, following, total_views
  final DateTime updatedAt;
}

// GET /api/users/{pubkey}/feed
class FeedResponse {
  final List<VideoStats> videos;
  final String? nextCursor;  // Use as ?before= for pagination
  final bool hasMore;
}

// POST /api/users/bulk, /api/videos/bulk
class BulkUsersResponse {
  final List<UserData> users;
  final List<String> missing;
  final String? sourceEventId;  // If resolved from Kind 3/30005
}
```

**from_event resolution** (server resolves Nostr events → IDs):
```json
POST /api/users/bulk
{
  "from_event": { "kind": 3, "pubkey": "user_hex" }
}
// Server fetches user's Kind 3, extracts p tags, returns profiles

POST /api/videos/bulk
{
  "from_event": { "kind": 30005, "pubkey": "user_hex", "d_tag": "favorites" }
}
// Server fetches Kind 30005 list, extracts video IDs, returns videos
```

## Implementation Phases

**Key principle:** Existing Nostr code stays intact. REST is layered on top with try/catch fallback.

### Phase 0: Initialize Availability Check

**File:** App initialization (where services are created)

```dart
// During app startup, after environment is configured
final analyticsApi = ref.read(analyticsApiServiceProvider);
analyticsApi.checkAvailability();  // Fire-and-forget, non-blocking
```

This runs in background. Until it completes, `isAvailable` returns `false` (safe default).

### Phase 1: Enhance AnalyticsApiService

**File:** `lib/services/analytics_api_service.dart`

Add methods matching server endpoints:
```dart
/// Combined user data (profile + stats + social)
Future<UserData?> getUser(String pubkey) async { ... }

/// Personalized feed - server handles 20k+ follows
Future<FeedResponse> getUserFeed(String pubkey, {
  String sort = 'recent',
  int limit = 50,
  int? before,
}) async { ... }

/// Social counts only (lighter than full user)
Future<SocialStats?> getSocialStats(String pubkey) async { ... }

/// Bulk profiles - direct IDs or from Kind 3
Future<BulkUsersResponse> getBulkUsers({
  List<String>? pubkeys,
  FromEventRef? fromEvent,
}) async { ... }

/// Bulk videos - direct IDs or from Kind 30005
Future<BulkVideosResponse> getBulkVideos({
  List<String>? eventIds,
  FromEventRef? fromEvent,
}) async { ... }
```

### Phase 2: Update Services (REST-first)

**File:** `lib/services/user_profile_service.dart`
```dart
Future<UserProfile?> fetchProfile(String pubkey) async {
  // REST first if funnelcake
  if (_analyticsApi.isAvailable) {
    try {
      final userData = await _analyticsApi.getUser(pubkey);
      if (userData != null) return userData.profile;
    } catch (e) {
      Log.warning('REST failed: $e, falling back to Nostr');
    }
  }
  return _fetchProfileViaNostrs(pubkey);  // Existing Nostr path
}
```

**File:** `lib/services/social_service.dart`
```dart
Future<FollowerStats> getFollowerStats(String pubkey) async {
  // REST first - instant vs 8s scan
  if (_analyticsApi.isAvailable) {
    try {
      final userData = await _analyticsApi.getUser(pubkey);
      if (userData != null) {
        return FollowerStats(
          followers: userData.stats.followers,
          following: userData.stats.following,
        );
      }
    } catch (e) {
      Log.warning('REST failed: $e, falling back to Nostr');
    }
  }
  return _fetchFollowerStatsViaNostr(pubkey);  // Existing slow path
}
```

### Phase 3: Update Feed Providers

**File:** `lib/providers/home_feed_provider.dart`
```dart
Future<List<VideoEvent>> _fetchHomeFeed() async {
  // REST handles 20k+ follows efficiently
  if (_analyticsApi.isAvailable) {
    try {
      final response = await _analyticsApi.getUserFeed(
        _currentUserPubkey,
        sort: 'recent',
        limit: 100,
      );
      if (response.videos.isNotEmpty) return _mapToVideoEvents(response.videos);
    } catch (e) {
      Log.warning('REST feed failed: $e, falling back to Nostr');
    }
  }
  return _fetchHomeFeedViaNostr();  // Existing path
}
```

**No changes needed (already REST-first):**
- `lib/providers/popular_now_feed_provider.dart`
- `lib/providers/hashtag_feed_providers.dart`

## Files to Modify

| File | Change |
|------|--------|
| `lib/services/analytics_api_service.dart` | Add `getUser`, `getUserFeed`, `getSocialStats`, `getBulkUsers`, `getBulkVideos` |
| `lib/services/user_profile_service.dart` | REST-first in `fetchProfile()` |
| `lib/services/social_service.dart` | REST-first in `getFollowerStats()` |
| `lib/providers/home_feed_provider.dart` | REST-first via `/api/users/{pubkey}/feed` |

## Fallback Strategy

```
1. Check AnalyticsApiService.isAvailable
   ├── Yes → REST API (10s timeout)
   │         ├── Success → Return result
   │         └── Failure → Log warning, fall through
   └── No → Skip to Nostr

2. Nostr query/subscription
   ├── Success → Return result
   └── Failure → Return cached or empty

3. Real-time updates always via Nostr WebSocket
```

## Testing

### Unit Tests
```dart
group('REST-first with Nostr fallback', () {
  test('uses REST when available (funnelcake)', () async {
    when(mockAnalyticsApi.isAvailable).thenReturn(true);
    when(mockAnalyticsApi.getUser(any)).thenAnswer((_) async => userData);

    final result = await socialService.getFollowerStats(pubkey);

    verify(mockAnalyticsApi.getUser(pubkey)).called(1);
    verifyNever(mockNostrService.subscribe(any));
  });

  test('falls back to Nostr on REST failure', () async {
    when(mockAnalyticsApi.isAvailable).thenReturn(true);
    when(mockAnalyticsApi.getUser(any)).thenThrow(Exception('timeout'));

    await socialService.getFollowerStats(pubkey);

    verify(mockNostrService.subscribe(any)).called(1);
  });

  test('skips REST entirely on non-funnelcake relay', () async {
    // CRITICAL: When not on funnelcake, don't even try REST
    when(mockAnalyticsApi.isAvailable).thenReturn(false);

    await socialService.getFollowerStats(pubkey);

    verifyNever(mockAnalyticsApi.getUser(any));  // Never called
    verify(mockNostrService.subscribe(any)).called(1);  // Direct to Nostr
  });

  test('no delay when REST unavailable', () async {
    // CRITICAL: isAvailable is sync, no network call
    when(mockAnalyticsApi.isAvailable).thenReturn(false);

    final stopwatch = Stopwatch()..start();
    await socialService.getFollowerStats(pubkey);
    stopwatch.stop();

    // Should be instant (< 100ms), not waiting for any timeout
    expect(stopwatch.elapsedMilliseconds, lessThan(100));
  });
});
```

### Manual Verification

**On funnelcake relay (staging/productionNew):**
- [ ] Profile page loads fast (~200ms vs ~3s)
- [ ] Home feed works with 20k+ follows
- [ ] Bulk profile fetch works for feed authors

**On ANY other Nostr relay (critical!):**
- [ ] App works normally via Nostr queries
- [ ] No REST errors in logs (should skip REST entirely)
- [ ] Profile page loads (slower but works)
- [ ] Home feed loads (may be slow with many follows)

**Fallback scenarios:**
- [ ] REST timeout → falls back to Nostr, no crash
- [ ] Network error → graceful degradation
- [ ] Switch relays mid-session → correct detection

## Deferred (Phase 2)

- ETag/If-None-Match conditional requests
- Persistent cache across app restarts
- `/api/users/social/bulk` for feed author counts
- from_event for Kind 10003, 30003 (bookmark sets)

## Cross-Reference

- **Server plan:** Backend team's funnelcake REST endpoint implementation
- Plans aligned on endpoint structure. Server implements, mobile consumes.
