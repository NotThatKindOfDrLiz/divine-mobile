// ABOUTME: Video file cache singleton using media_cache package
// ABOUTME: Replaces video_cache_manager.dart with cleaner abstraction

import 'package:flutter/foundation.dart';
import 'package:media_cache/media_cache.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'openvine_media_cache.g.dart';

/// OpenVine video file cache singleton using media_cache package.
///
/// Configured for video caching with:
/// - 30 day stale period
/// - 1000 max cached objects
/// - Sync manifest for instant cache lookups
///
/// This singleton is used directly in main() for early initialization,
/// and exposed via [mediaCacheProvider] for dependency injection in
/// Riverpod contexts.
///
/// Usage:
/// ```dart
/// // Direct access (in main.dart or non-Riverpod code)
/// await openVineMediaCache.initialize();
/// final cachedFile = openVineMediaCache.getCachedFileSync(videoId);
///
/// // Via provider (in widgets/providers - preferred for testability)
/// final cache = ref.read(mediaCacheProvider);
/// final cachedFile = cache.getCachedFileSync(videoId);
/// ```
// TODO(any): move declaration to provider or inject in packages in the future
// Lazy initialization to avoid dart:io crash on web (HttpClient / Platform).
late final openVineMediaCache = MediaCacheManager(
  config: const MediaCacheConfig.video(cacheKey: 'openvine_video_cache'),
);

/// Provider exposing the media cache singleton for dependency injection.
///
/// Use this in Riverpod contexts for testability - can be overridden in tests.
/// The underlying singleton is initialized in main.dart before Riverpod.
///
/// On web, accessing this provider will throw because dart:io HttpClient
/// is not available. Guard with `kIsWeb` before reading.
@Riverpod(keepAlive: true)
MediaCacheManager mediaCache(Ref ref) => openVineMediaCache;

/// Initialize video file cache on app startup.
///
/// Loads the in-memory manifest for synchronous cache lookups.
/// Call this in main.dart after WidgetsFlutterBinding.ensureInitialized().
/// No-op on web where MediaCacheManager is not available.
Future<void> initializeMediaCache() async {
  if (kIsWeb) return;
  await openVineMediaCache.initialize();
}
