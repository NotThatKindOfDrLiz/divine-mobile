// ABOUTME: Provider for fetching pubkeys of users who reposted a video.
// ABOUTME: Queries relay for Kind 16 repost events referencing the video ID.

import 'package:openvine/providers/app_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'video_reposters_provider.g.dart';

/// Fetches the pubkeys of users who reposted a video.
///
/// Queries the relay for Kind 16 (NIP-18 generic repost) events that reference
/// [videoId]. Uses the existing [VideoEventService.getRepostersForVideo] which
/// has a 5-second timeout.
///
/// Auto-disposes when the metadata sheet closes.
@riverpod
Future<List<String>> videoReposters(Ref ref, String videoId) async {
  if (videoId.isEmpty) return [];
  final videoEventService = ref.watch(videoEventServiceProvider);
  return videoEventService.getRepostersForVideo(videoId);
}
