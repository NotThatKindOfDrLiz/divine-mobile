// ABOUTME: Centralized video deduplication utility for NIP-71 addressable events
// ABOUTME: Uses vineId (d-tag) + pubkey as stable identifier, keeping newest version

import 'package:models/models.dart';

/// Utility class for video deduplication across the app.
///
/// NIP-71 addressable video events (kind 34236) can be edited, which creates
/// a new event ID while keeping the same d-tag (vineId). This utility ensures
/// consistent deduplication by:
/// - Using `pubkey:vineId` as the stable identifier
/// - Always keeping the version with the latest `createdAt` timestamp
class VideoDeduplication {
  /// Generate a stable identifier for a video event.
  ///
  /// For addressable events, the combination of pubkey and vineId (d-tag)
  /// uniquely identifies the video across edits. Falls back to event ID
  /// if vineId is not available.
  static String stableId(VideoEvent video) {
    if (video.vineId != null && video.vineId!.isNotEmpty) {
      return '${video.pubkey}:${video.vineId}';
    }
    // Fallback for non-addressable events (kinds 21, 22)
    return video.id;
  }

  /// Deduplicate a list of videos, keeping the newest version of each.
  ///
  /// When multiple videos have the same stable ID (pubkey:vineId), only
  /// the one with the latest `createdAt` timestamp is kept.
  ///
  /// Returns a new list with duplicates removed.
  static List<VideoEvent> deduplicate(List<VideoEvent> videos) {
    final map = <String, VideoEvent>{};
    for (final video in videos) {
      final id = stableId(video);
      final existing = map[id];
      if (existing == null || video.createdAt > existing.createdAt) {
        map[id] = video;
      }
    }
    return map.values.toList();
  }

  /// Merge incoming videos into an existing list with deduplication.
  ///
  /// For videos with the same stable ID, the version with the latest
  /// `createdAt` timestamp is kept. This handles the case where an edited
  /// video arrives and should replace the older version.
  ///
  /// Returns a new list containing the merged and deduplicated videos.
  static List<VideoEvent> merge(
    List<VideoEvent> existing,
    List<VideoEvent> incoming,
  ) {
    final map = <String, VideoEvent>{};

    // Process existing videos first
    for (final video in existing) {
      final id = stableId(video);
      final current = map[id];
      if (current == null || video.createdAt > current.createdAt) {
        map[id] = video;
      }
    }

    // Process incoming videos, replacing if newer
    for (final video in incoming) {
      final id = stableId(video);
      final current = map[id];
      if (current == null || video.createdAt > current.createdAt) {
        map[id] = video;
      }
    }

    return map.values.toList();
  }

  /// Check if a video should replace an existing one.
  ///
  /// Returns true if:
  /// - They have the same stable ID (pubkey:vineId)
  /// - The new video has a later `createdAt` timestamp
  static bool shouldReplace(VideoEvent existing, VideoEvent incoming) {
    return stableId(existing) == stableId(incoming) &&
        incoming.createdAt > existing.createdAt;
  }

  /// Find and replace an existing video with a newer version in a list.
  ///
  /// If a video with the same stable ID exists and the incoming video
  /// is newer, replaces it in place. Otherwise, returns false.
  ///
  /// Returns true if a replacement was made, false otherwise.
  static bool replaceIfNewer(List<VideoEvent> list, VideoEvent incoming) {
    final incomingId = stableId(incoming);

    for (var i = 0; i < list.length; i++) {
      if (stableId(list[i]) == incomingId) {
        if (incoming.createdAt > list[i].createdAt) {
          list[i] = incoming;
          return true;
        }
        // Same ID but incoming is older or same age - no replacement needed
        return false;
      }
    }

    // No existing video with this stable ID found
    return false;
  }

  /// Check if a list already contains a video with the same stable ID.
  static bool containsStableId(List<VideoEvent> list, VideoEvent video) {
    final videoId = stableId(video);
    return list.any((v) => stableId(v) == videoId);
  }
}
