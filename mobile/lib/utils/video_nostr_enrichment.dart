import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Filter;
import 'package:openvine/utils/unified_logger.dart';

/// Enrich REST API videos with full Nostr event data.
///
/// REST API responses may be missing fields that are present in the raw
/// Nostr event (rawTags for ProofMode/C2PA badges, dimensions, hashtags,
/// blurhash, content-warning labels, etc.). This function fetches the full
/// events from Nostr relays by ID and merges any missing fields into the
/// REST API videos.
Future<List<VideoEvent>> enrichVideosWithNostrTags(
  List<VideoEvent> videos, {
  required NostrClient nostrService,
  String callerName = 'VideoEnrichment',
}) async {
  if (videos.isEmpty) return videos;

  // Collect IDs of videos that need enrichment.
  //
  // Videos from the REST API have minimal rawTags (just 'loops'/'views')
  // because the API returns denormalized data without the full Nostr tags
  // array. Videos already enriched from Nostr WebSocket have many rawTags
  // (title, url, thumb, d, x, blurhash, etc. — typically 6+).
  //
  // We use a threshold of 5 to distinguish REST API videos (0-2 rawTags)
  // from already-enriched Nostr videos (6+ rawTags). This ensures
  // content-warning labels, hashtags, and other tag-based fields get
  // populated for REST API videos.
  final idsToEnrich = videos
      .where((v) => v.rawTags.length < 5)
      .map((v) => v.id)
      .toList();

  Log.info(
    '$callerName: enrichVideosWithNostrTags called with '
    '${videos.length} videos, ${idsToEnrich.length} need enrichment '
    '(rawTags < 5)',
    name: callerName,
    category: LogCategory.video,
  );

  // Log rawTags distribution for first few videos to help diagnose issues
  if (videos.length <= 5) {
    for (final v in videos) {
      Log.debug(
        '$callerName: Video rawTags=${v.rawTags.length} '
        'cwl=${v.contentWarningLabels.length} id=${v.id}',
        name: callerName,
        category: LogCategory.video,
      );
    }
  } else {
    // Sample first 3 videos for diagnostic logging
    final tagLengths = videos.map((v) => v.rawTags.length).toList();
    final minTags = tagLengths.reduce((a, b) => a < b ? a : b);
    final maxTags = tagLengths.reduce((a, b) => a > b ? a : b);
    final cwlCount = videos
        .where((v) => v.contentWarningLabels.isNotEmpty)
        .length;
    Log.info(
      '$callerName: rawTags range: $minTags-$maxTags, '
      '$cwlCount/${videos.length} already have CW labels',
      name: callerName,
      category: LogCategory.video,
    );
  }

  if (idsToEnrich.isEmpty) {
    Log.info(
      '$callerName: All ${videos.length} videos already enriched '
      '(rawTags >= 5) — skipping Nostr query',
      name: callerName,
      category: LogCategory.video,
    );
    return videos;
  }

  try {
    // Wait for relay connectivity — relays connect asynchronously after
    // NostrClient creation, so at app startup the relay pool may still be
    // empty when feeds try to enrich. Without connected relays the query
    // silently returns zero events and content-warning labels are lost.
    if (nostrService.connectedRelayCount == 0) {
      Log.info(
        '$callerName: Waiting for relay connection before enrichment '
        '(${idsToEnrich.length} videos need tags)...',
        name: callerName,
        category: LogCategory.video,
      );
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (nostrService.connectedRelayCount > 0) break;
      }
      if (nostrService.connectedRelayCount == 0) {
        Log.warning(
          '$callerName: No relays connected after 5 s — '
          'skipping enrichment for ${idsToEnrich.length} videos',
          name: callerName,
          category: LogCategory.video,
        );
        return videos;
      }
      Log.info(
        '$callerName: Relay connected '
        '(${nostrService.connectedRelayCount} relays), '
        'proceeding with enrichment',
        name: callerName,
        category: LogCategory.video,
      );
    }

    // Batch query Nostr relays for the full events
    final filter = Filter(
      ids: idsToEnrich,
      kinds: NIP71VideoKinds.getAllVideoKinds(),
      limit: idsToEnrich.length,
    );
    final nostrEvents = await nostrService
        .queryEvents([filter])
        .timeout(const Duration(seconds: 5));

    Log.info(
      '$callerName: Enrichment queried ${idsToEnrich.length} IDs, '
      'got ${nostrEvents.length} events from relays '
      '(${nostrService.connectedRelayCount} relays connected)',
      name: callerName,
      category: LogCategory.video,
    );

    if (nostrEvents.isEmpty) {
      Log.warning(
        '$callerName: Relay returned 0 events for '
        '${idsToEnrich.length} IDs — content warnings unavailable',
        name: callerName,
        category: LogCategory.video,
      );
      return videos;
    }

    // Build a lookup map: event ID -> parsed VideoEvent for enrichment
    final nostrEventsMap = <String, VideoEvent>{};
    for (final event in nostrEvents) {
      try {
        final parsed = VideoEvent.fromNostrEvent(event, permissive: true);
        if (parsed.rawTags.isNotEmpty) {
          nostrEventsMap[parsed.id] = parsed;
        }
      } catch (_) {
        // Skip events that fail to parse
      }
    }

    if (nostrEventsMap.isEmpty) {
      Log.warning(
        '$callerName: All ${nostrEvents.length} Nostr events failed '
        'to parse — content warnings unavailable',
        name: callerName,
        category: LogCategory.video,
      );
      return videos;
    }

    // Count how many enriched events have content warning labels
    var cwlCount = 0;
    for (final parsed in nostrEventsMap.values) {
      if (parsed.contentWarningLabels.isNotEmpty) cwlCount++;
    }
    Log.info(
      '$callerName: Enrichment parsed ${nostrEventsMap.length} events, '
      '$cwlCount have content-warning labels',
      name: callerName,
      category: LogCategory.video,
    );

    // Merge Nostr-parsed fields into REST API videos
    return videos.map((video) {
      final parsed = nostrEventsMap[video.id];
      if (parsed != null) {
        return video.copyWith(
          rawTags: parsed.rawTags,
          // Enrich with all missing fields from Nostr event
          title: video.title ?? parsed.title,
          videoUrl: video.videoUrl ?? parsed.videoUrl,
          thumbnailUrl: video.thumbnailUrl ?? parsed.thumbnailUrl,
          duration: video.duration ?? parsed.duration,
          dimensions: video.dimensions ?? parsed.dimensions,
          mimeType: video.mimeType ?? parsed.mimeType,
          sha256: video.sha256 ?? parsed.sha256,
          fileSize: video.fileSize ?? parsed.fileSize,
          hashtags: video.hashtags.isEmpty ? parsed.hashtags : video.hashtags,
          publishedAt: video.publishedAt ?? parsed.publishedAt,
          vineId: video.vineId ?? parsed.vineId,
          group: video.group ?? parsed.group,
          altText: video.altText ?? parsed.altText,
          blurhash: video.blurhash ?? parsed.blurhash,
          // Original Vine metrics: use Nostr values, clear if no tag exists
          originalLoops: parsed.originalLoops,
          originalLikes: parsed.originalLikes,
          originalComments: parsed.originalComments,
          originalReposts: parsed.originalReposts,
          clearOriginalLoops: parsed.originalLoops == null,
          clearOriginalLikes: parsed.originalLikes == null,
          clearOriginalComments: parsed.originalComments == null,
          clearOriginalReposts: parsed.originalReposts == null,
          collaboratorPubkeys: video.collaboratorPubkeys.isEmpty
              ? parsed.collaboratorPubkeys
              : video.collaboratorPubkeys,
          inspiredByVideo: video.inspiredByVideo ?? parsed.inspiredByVideo,
          textTrackRef: video.textTrackRef ?? parsed.textTrackRef,
          nostrEventTags: video.nostrEventTags.isEmpty
              ? parsed.nostrEventTags
              : video.nostrEventTags,
          contentWarningLabels: video.contentWarningLabels.isEmpty
              ? parsed.contentWarningLabels
              : video.contentWarningLabels,
        );
      }
      return video;
    }).toList();
  } catch (e) {
    // Non-fatal: return original videos if enrichment fails
    Log.warning(
      '$callerName: Failed to enrich with Nostr tags: $e',
      name: callerName,
      category: LogCategory.video,
    );
    return videos;
  }
}
