// ABOUTME: Data models for Funnelcake REST API responses
// ABOUTME: Simple Dart classes with factory fromJson constructors for API integration

import 'package:openvine/services/analytics_api_service.dart';

/// User profile information from Funnelcake REST API
///
/// Contains profile metadata like name, picture, about, etc.
class RestUserProfile {
  const RestUserProfile({
    this.name,
    this.picture,
    this.about,
    this.nip05,
    this.banner,
    this.lud16,
  });

  factory RestUserProfile.fromJson(Map<String, dynamic> json) {
    return RestUserProfile(
      name: json['name'] as String?,
      picture: json['picture'] as String?,
      about: json['about'] as String?,
      nip05: json['nip05'] as String?,
      banner: json['banner'] as String?,
      lud16: json['lud16'] as String?,
    );
  }

  final String? name;
  final String? picture;
  final String? about;
  final String? nip05;
  final String? banner;
  final String? lud16;

  Map<String, dynamic> toJson() => {
    'name': name,
    'picture': picture,
    'about': about,
    'nip05': nip05,
    'banner': banner,
    'lud16': lud16,
  };

  @override
  String toString() =>
      'RestUserProfile(name: $name, hasAvatar: ${picture != null})';
}

/// User statistics from Funnelcake REST API
///
/// Contains counts for videos, followers, following, and total views.
class UserStats {
  const UserStats({
    this.videoCount = 0,
    this.followers = 0,
    this.following = 0,
    this.totalViews = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      videoCount: _parseIntField(json, 'videoCount', 'video_count'),
      followers: _parseIntField(json, 'followers', null),
      following: _parseIntField(json, 'following', null),
      totalViews: _parseIntField(json, 'totalViews', 'total_views'),
    );
  }

  final int videoCount;
  final int followers;
  final int following;
  final int totalViews;

  Map<String, dynamic> toJson() => {
    'videoCount': videoCount,
    'followers': followers,
    'following': following,
    'totalViews': totalViews,
  };

  @override
  String toString() =>
      'UserStats(videos: $videoCount, followers: $followers, following: $following)';
}

/// Combined user data response from GET /api/users/{pubkey}
///
/// Contains profile information and aggregated statistics.
class UserData {
  const UserData({
    required this.pubkey,
    required this.profile,
    required this.stats,
    required this.updatedAt,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    // Parse pubkey - handle byte array format from ClickHouse
    String pubkey;
    if (json['pubkey'] is List) {
      pubkey = String.fromCharCodes((json['pubkey'] as List).cast<int>());
    } else {
      pubkey = json['pubkey']?.toString() ?? '';
    }

    // Parse nested profile object (may be at top level or nested)
    final profileJson = json['profile'] as Map<String, dynamic>? ?? json;

    // Parse nested stats object (may be at top level or nested)
    final statsJson = json['stats'] as Map<String, dynamic>? ?? json;

    // Parse updatedAt timestamp
    DateTime updatedAt;
    if (json['updatedAt'] != null) {
      updatedAt = _parseDateTime(json['updatedAt']);
    } else if (json['updated_at'] != null) {
      updatedAt = _parseDateTime(json['updated_at']);
    } else {
      updatedAt = DateTime.now();
    }

    return UserData(
      pubkey: pubkey,
      profile: RestUserProfile.fromJson(profileJson),
      stats: UserStats.fromJson(statsJson),
      updatedAt: updatedAt,
    );
  }

  final String pubkey;
  final RestUserProfile profile;
  final UserStats stats;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'pubkey': pubkey,
    'profile': profile.toJson(),
    'stats': stats.toJson(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  String toString() =>
      'UserData(pubkey: ${pubkey.length > 16 ? '${pubkey.substring(0, 8)}...' : pubkey}, '
      'profile: $profile, stats: $stats)';
}

/// Social statistics response from GET /api/users/{pubkey}/social
///
/// Lighter response containing only follower/following counts.
class SocialStats {
  const SocialStats({this.followers = 0, this.following = 0});

  factory SocialStats.fromJson(Map<String, dynamic> json) {
    return SocialStats(
      followers: _parseIntField(json, 'followers', null),
      following: _parseIntField(json, 'following', null),
    );
  }

  final int followers;
  final int following;

  Map<String, dynamic> toJson() => {
    'followers': followers,
    'following': following,
  };

  @override
  String toString() =>
      'SocialStats(followers: $followers, following: $following)';
}

/// Paginated feed response from GET /api/users/{pubkey}/feed
///
/// Contains a list of videos with pagination cursor support.
class FeedResponse {
  const FeedResponse({
    required this.videos,
    this.nextCursor,
    this.hasMore = false,
  });

  /// Creates an empty FeedResponse for error cases
  factory FeedResponse.empty() =>
      const FeedResponse(videos: [], hasMore: false);

  factory FeedResponse.fromJson(Map<String, dynamic> json) {
    final videosJson = json['videos'] as List<dynamic>? ?? [];

    return FeedResponse(
      videos: videosJson
          .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
          .toList(),
      nextCursor:
          json['nextCursor'] as String? ?? json['next_cursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? json['has_more'] as bool? ?? false,
    );
  }

  final List<VideoStats> videos;
  final String? nextCursor;
  final bool hasMore;

  Map<String, dynamic> toJson() => {
    'videos': videos.map((v) => _videoStatsToJson(v)).toList(),
    'nextCursor': nextCursor,
    'hasMore': hasMore,
  };

  @override
  String toString() =>
      'FeedResponse(videos: ${videos.length}, hasMore: $hasMore, cursor: $nextCursor)';
}

/// Event reference for bulk requests
///
/// Used in POST /api/users/bulk and POST /api/videos/bulk request bodies.
class FromEventRef {
  const FromEventRef({required this.kind, required this.pubkey, this.dTag});

  factory FromEventRef.fromJson(Map<String, dynamic> json) {
    // Parse pubkey - handle byte array format from ClickHouse
    String pubkey;
    if (json['pubkey'] is List) {
      pubkey = String.fromCharCodes((json['pubkey'] as List).cast<int>());
    } else {
      pubkey = json['pubkey']?.toString() ?? '';
    }

    return FromEventRef(
      kind: json['kind'] as int? ?? 0,
      pubkey: pubkey,
      dTag: json['dTag'] as String? ?? json['d_tag'] as String?,
    );
  }

  final int kind;
  final String pubkey;
  final String? dTag;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'pubkey': pubkey,
    if (dTag != null) 'dTag': dTag,
  };

  @override
  String toString() =>
      'FromEventRef(kind: $kind, pubkey: ${pubkey.length > 16 ? '${pubkey.substring(0, 8)}...' : pubkey})';
}

/// Bulk users response from POST /api/users/bulk
///
/// Returns user data for multiple pubkeys with a list of missing ones.
class BulkUsersResponse {
  const BulkUsersResponse({
    required this.users,
    required this.missing,
    this.sourceEventId,
  });

  /// Creates an empty BulkUsersResponse for error cases
  factory BulkUsersResponse.empty() =>
      const BulkUsersResponse(users: [], missing: []);

  factory BulkUsersResponse.fromJson(Map<String, dynamic> json) {
    final usersJson = json['users'] as List<dynamic>? ?? [];
    final missingJson = json['missing'] as List<dynamic>? ?? [];

    // Parse sourceEventId - handle byte array format from ClickHouse
    String? sourceEventId;
    if (json['sourceEventId'] != null) {
      if (json['sourceEventId'] is List) {
        sourceEventId = String.fromCharCodes(
          (json['sourceEventId'] as List).cast<int>(),
        );
      } else {
        sourceEventId = json['sourceEventId']?.toString();
      }
    } else if (json['source_event_id'] != null) {
      if (json['source_event_id'] is List) {
        sourceEventId = String.fromCharCodes(
          (json['source_event_id'] as List).cast<int>(),
        );
      } else {
        sourceEventId = json['source_event_id']?.toString();
      }
    }

    return BulkUsersResponse(
      users: usersJson
          .map((u) => UserData.fromJson(u as Map<String, dynamic>))
          .toList(),
      missing: missingJson.map((m) => m.toString()).toList(),
      sourceEventId: sourceEventId,
    );
  }

  final List<UserData> users;
  final List<String> missing;
  final String? sourceEventId;

  Map<String, dynamic> toJson() => {
    'users': users.map((u) => u.toJson()).toList(),
    'missing': missing,
    if (sourceEventId != null) 'sourceEventId': sourceEventId,
  };

  @override
  String toString() =>
      'BulkUsersResponse(users: ${users.length}, missing: ${missing.length})';
}

/// Bulk videos response from POST /api/videos/bulk
///
/// Returns video stats for multiple video identifiers with a list of missing ones.
class BulkVideosResponse {
  const BulkVideosResponse({required this.videos, required this.missing});

  /// Creates an empty BulkVideosResponse for error cases
  factory BulkVideosResponse.empty() =>
      const BulkVideosResponse(videos: [], missing: []);

  factory BulkVideosResponse.fromJson(Map<String, dynamic> json) {
    final videosJson = json['videos'] as List<dynamic>? ?? [];
    final missingJson = json['missing'] as List<dynamic>? ?? [];

    return BulkVideosResponse(
      videos: videosJson
          .map((v) => VideoStats.fromJson(v as Map<String, dynamic>))
          .toList(),
      missing: missingJson.map((m) => m.toString()).toList(),
    );
  }

  final List<VideoStats> videos;
  final List<String> missing;

  Map<String, dynamic> toJson() => {
    'videos': videos.map((v) => _videoStatsToJson(v)).toList(),
    'missing': missing,
  };

  @override
  String toString() =>
      'BulkVideosResponse(videos: ${videos.length}, missing: ${missing.length})';
}

// Helper functions for JSON parsing

/// Parse an integer field with fallback to snake_case key
int _parseIntField(
  Map<String, dynamic> json,
  String camelKey,
  String? snakeKey,
) {
  final value = json[camelKey] ?? (snakeKey != null ? json[snakeKey] : null);
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is double) return value.toInt();
  return 0;
}

/// Parse a DateTime from various formats
DateTime _parseDateTime(dynamic value) {
  if (value is int) {
    // Unix timestamp in seconds
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  } else if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  } else if (value is DateTime) {
    return value;
  }
  return DateTime.now();
}

/// Convert VideoStats to JSON (helper since VideoStats doesn't have toJson)
Map<String, dynamic> _videoStatsToJson(VideoStats stats) => {
  'id': stats.id,
  'pubkey': stats.pubkey,
  'created_at': stats.createdAt.millisecondsSinceEpoch ~/ 1000,
  'kind': stats.kind,
  'd_tag': stats.dTag,
  'title': stats.title,
  'thumbnail': stats.thumbnail,
  'video_url': stats.videoUrl,
  'reactions': stats.reactions,
  'comments': stats.comments,
  'reposts': stats.reposts,
  'engagement_score': stats.engagementScore,
  if (stats.trendingScore != null) 'trending_score': stats.trendingScore,
};
