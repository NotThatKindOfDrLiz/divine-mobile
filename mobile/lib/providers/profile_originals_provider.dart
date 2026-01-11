// ABOUTME: Provider for fetching a user's original videos (excluding reposts)
// ABOUTME: Filters profile feed events to show only original content by the
// user

import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_originals_provider.g.dart';

/// Provider that returns only the user's original videos (excluding reposts)
///
/// Watches the profile feed provider and filters for videos where:
/// - isRepost == false
/// - pubkey == userIdHex (original author)
@riverpod
Future<List<VideoEvent>> profileOriginals(Ref ref, String userIdHex) async {
  // Watch the full profile feed
  final profileFeed = await ref.watch(profileFeedProvider(userIdHex).future);

  // Filter for only original videos by this user (not reposts)
  final originals = profileFeed.videos
      .where((video) => !video.isRepost && video.pubkey == userIdHex)
      .toList();

  return originals;
}
