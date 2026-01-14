// ABOUTME: Pool for managing video player controllers with LRU eviction
// ABOUTME: Owns controller lifecycle - controllers are only disposed on eviction or clear()
// ABOUTME: Providers "checkout" controllers and "checkin" when done (no disposal in provider)

import 'dart:collection';

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:openvine/providers/individual_video_providers.dart'
    show VideoControllerParams;
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/blossom_auth_service.dart';
import 'package:openvine/services/video_cache_manager.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:video_player/video_player.dart';

/// Result of acquiring a controller from the repository.
class VideoControllerResult {
  const VideoControllerResult({
    required this.controller,
    required this.videoUrl,
    required this.isFromCache,
    required this.wasExisting,
  });

  /// The video player controller (not yet initialized if newly created).
  final VideoPlayerController controller;

  /// The final video URL used (may be normalized from .bin).
  final String videoUrl;

  /// Whether the controller was created from a cached file.
  final bool isFromCache;

  /// Whether this controller already existed in the repository.
  /// If false, the controller was just created and needs initialization.
  final bool wasExisting;
}

/// Metadata tracked for each controller in the pool.
class _ControllerEntry {
  _ControllerEntry({
    required this.controller,
    required this.videoUrl,
    required this.isFromCache,
    required this.params,
  }) : lastAccessTime = DateTime.now();

  final VideoPlayerController controller;
  final String videoUrl;
  final bool isFromCache;
  final VideoControllerParams params;
  DateTime lastAccessTime;
  bool isInitializing = true;
  bool isPlaying = false;
  bool isCheckedOut = true; // Starts as checked out when created

  void recordAccess() {
    lastAccessTime = DateTime.now();
  }
}

/// Pool for managing video player controllers.
///
/// **Key Principle:** The pool OWNS controller lifecycle. Controllers are only
/// disposed during LRU eviction or when clear() is called. Providers "borrow"
/// controllers via checkout/checkin but never dispose them.
///
/// This prevents crashes from controller churn - iOS/Android have limited
/// concurrent players (~4-6), and rapid dispose/create exhausts resources.
///
/// Consolidates:
/// - Pool management (LRU eviction, concurrent controller limits)
/// - Controller creation (platform-specific, cache-aware)
/// - URL normalization (.bin extension rewriting)
/// - Auth header computation (NSFW content)
///
/// Usage:
/// ```dart
/// final pool = ref.read(videoControllerRepositoryProvider);
///
/// // Checkout a controller (handles pool limits, eviction, creation)
/// final result = pool.checkout(params);
///
/// // Mark playback state (protects from eviction)
/// pool.markPlaying(videoId);
/// pool.markNotPlaying(videoId);
///
/// // Return to pool when done (provider's onDispose) - does NOT dispose
/// pool.checkin(videoId);
/// ```
class VideoControllerRepository extends ChangeNotifier {
  VideoControllerRepository({
    required VideoCacheManager cacheManager,
    required AgeVerificationService ageVerificationService,
    required BlossomAuthService blossomAuthService,
  }) : _cacheManager = cacheManager,
       _ageVerificationService = ageVerificationService,
       _blossomAuthService = blossomAuthService;

  final VideoCacheManager _cacheManager;
  final AgeVerificationService _ageVerificationService;
  final BlossomAuthService _blossomAuthService;

  /// Maximum concurrent video controllers allowed.
  /// Platform limits: iOS/Android support ~4-6 concurrent players.
  /// Using 4 for safety margin.
  static const int maxConcurrentControllers = 4;

  /// Controller storage with LRU ordering.
  /// LinkedHashMap maintains insertion order; we re-insert on access for LRU.
  final LinkedHashMap<String, _ControllerEntry> _controllers = LinkedHashMap();

  /// In-memory cache for auth headers by video ID.
  final Map<String, Map<String, String>> _authHeadersCache = {};

  /// Currently playing video ID (protected from eviction).
  String? _currentlyPlayingVideoId;

  // ===========================================================================
  // Public API
  // ===========================================================================

  /// Checkout a controller for the given params.
  ///
  /// Returns existing controller if already in pool, otherwise creates new.
  /// Handles pool limits internally - may evict LRU controller if at capacity.
  /// Controller is NOT initialized if newly created - caller must initialize.
  ///
  /// The controller is marked as "checked out" and protected from eviction
  /// until [checkin] is called.
  VideoControllerResult checkout(VideoControllerParams params) {
    final videoId = params.videoId;

    // Check if we already have this controller in pool
    final existing = _controllers[videoId];
    if (existing != null) {
      existing.isCheckedOut = true; // Mark as in-use
      _recordAccess(videoId);
      Log.debug(
        '🎬 [POOL] Returning pooled controller for $videoId',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
      return VideoControllerResult(
        controller: existing.controller,
        videoUrl: existing.videoUrl,
        isFromCache: existing.isFromCache,
        wasExisting: true,
      );
    }

    // Evict if at capacity
    if (isAtLimit) {
      final evictId = _getEvictionCandidate();
      if (evictId != null) {
        _evictController(evictId);
      }
    }

    // Create new controller
    final result = _createController(params);

    // Store in pool (starts as checked out)
    _controllers[videoId] = _ControllerEntry(
      controller: result.controller,
      videoUrl: result.videoUrl,
      isFromCache: result.isFromCache,
      params: params,
    );

    Log.info(
      '🎬 [POOL] Created controller for $videoId (count: ${_controllers.length}/$maxConcurrentControllers)',
      name: 'VideoControllerRepository',
      category: LogCategory.video,
    );

    notifyListeners();

    return VideoControllerResult(
      controller: result.controller,
      videoUrl: result.videoUrl,
      isFromCache: result.isFromCache,
      wasExisting: false,
    );
  }

  /// Alias for [checkout] to maintain backward compatibility.
  @Deprecated('Use checkout() instead')
  VideoControllerResult acquireController(VideoControllerParams params) =>
      checkout(params);

  /// Return a controller to the pool (checkin).
  ///
  /// Call in provider's onDispose callback. The controller stays in the pool
  /// for potential reuse - it is NOT disposed. Controllers are only disposed
  /// during LRU eviction or when [clear] is called.
  ///
  /// This is the key difference from the old model: checkin does NOT dispose.
  void checkin(String videoId) {
    final entry = _controllers[videoId];

    if (entry != null) {
      entry.isCheckedOut = false; // Mark as available for eviction

      Log.debug(
        '📥 [POOL] Checked in controller for $videoId (stays in pool, count: ${_controllers.length}/$maxConcurrentControllers)',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
      notifyListeners();
    }
  }

  /// Alias for [checkin] to maintain backward compatibility.
  /// Note: The old releaseController removed from pool; checkin keeps it.
  @Deprecated('Use checkin() instead - controller stays in pool')
  void releaseController(String videoId) => checkin(videoId);

  /// Mark controller as initialized (no longer initializing).
  void markInitialized(String videoId) {
    final entry = _controllers[videoId];
    if (entry != null) {
      entry.isInitializing = false;
      Log.debug(
        '✅ [REPO] Controller initialized: $videoId',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
    }
  }

  /// Mark controller as currently playing (protects from eviction).
  void markPlaying(String videoId) {
    _currentlyPlayingVideoId = videoId;
    _recordAccess(videoId);

    final entry = _controllers[videoId];
    if (entry != null) {
      entry.isPlaying = true;
    }

    Log.debug(
      '▶️ [REPO] Now playing: $videoId',
      name: 'VideoControllerRepository',
      category: LogCategory.video,
    );

    notifyListeners();
  }

  /// Mark controller as not playing (eligible for eviction).
  void markNotPlaying(String videoId) {
    if (_currentlyPlayingVideoId == videoId) {
      _currentlyPlayingVideoId = null;
    }

    final entry = _controllers[videoId];
    if (entry != null) {
      entry.isPlaying = false;

      Log.debug(
        '⏸️ [REPO] Stopped playing: $videoId',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );

      notifyListeners();
    }
  }

  /// Check if repository has a controller for this video.
  bool hasController(String videoId) => _controllers.containsKey(videoId);

  /// Get the controller if it exists (for checking state).
  VideoPlayerController? getController(String videoId) =>
      _controllers[videoId]?.controller;

  /// Whether video caching should be triggered.
  bool shouldCacheVideo(VideoControllerParams params) {
    if (kIsWeb) return false;
    final cachedFile = _cacheManager.getCachedVideoSync(params.videoId);
    return cachedFile == null || !cachedFile.existsSync();
  }

  /// Generate and cache auth headers for future use.
  Future<void> cacheAuthHeaders(VideoControllerParams params) async {
    if (!_ageVerificationService.isAdultContentVerified) return;
    if (!_blossomAuthService.canCreateHeaders) return;
    if (params.videoEvent == null) return;
    if (_authHeadersCache.containsKey(params.videoId)) return;

    try {
      final videoEvent = params.videoEvent as dynamic;
      final sha256 = videoEvent.sha256 as String?;

      if (sha256 == null || sha256.isEmpty) return;

      String? serverUrl;
      try {
        final uri = Uri.parse(params.videoUrl);
        serverUrl = '${uri.scheme}://${uri.host}';
      } catch (e) {
        Log.warning(
          'Failed to parse video URL for server: $e',
          name: 'VideoControllerRepository',
          category: LogCategory.video,
        );
        return;
      }

      final authHeader = await _blossomAuthService.createGetAuthHeader(
        sha256Hash: sha256,
        serverUrl: serverUrl,
      );

      if (authHeader != null) {
        _authHeadersCache[params.videoId] = {'Authorization': authHeader};
        Log.info(
          '✅ Cached auth header for video ${params.videoId}',
          name: 'VideoControllerRepository',
          category: LogCategory.video,
        );
      }
    } catch (error) {
      Log.debug(
        'Failed to generate auth headers: $error',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
    }
  }

  // ===========================================================================
  // Pool Status Getters
  // ===========================================================================

  /// Current number of controllers in repository.
  int get activeCount => _controllers.length;

  /// Number of slots available for new controllers.
  int get availableSlots => (maxConcurrentControllers - _controllers.length)
      .clamp(0, maxConcurrentControllers);

  /// Whether repository is at maximum capacity.
  bool get isAtLimit => _controllers.length >= maxConcurrentControllers;

  /// Currently playing video ID.
  String? get currentlyPlayingVideoId => _currentlyPlayingVideoId;

  /// Get the cache manager for external caching operations.
  VideoCacheManager get cacheManager => _cacheManager;

  /// All registered video IDs (for debugging).
  List<String> get registeredVideoIds => _controllers.keys.toList();

  /// Number of controllers currently checked out (in active provider use).
  int get checkedOutCount =>
      _controllers.values.where((e) => e.isCheckedOut).length;

  /// Number of idle controllers (checked in, available for reuse or eviction).
  int get idleCount => _controllers.values.where((e) => !e.isCheckedOut).length;

  /// Force evict and dispose a specific controller.
  ///
  /// Use this for explicit cleanup, e.g., after a video load error or
  /// cache corruption. Unlike [checkin], this removes the controller
  /// from the pool entirely.
  void evict(String videoId) {
    _evictController(videoId);
    notifyListeners();
  }

  /// Clear all controllers and dispose them.
  ///
  /// Call when navigating away from video feeds to release all platform
  /// video player resources.
  void clear() {
    final count = _controllers.length;

    // Dispose each controller before clearing
    for (final entry in _controllers.values) {
      try {
        entry.controller.dispose();
      } catch (e) {
        Log.warning(
          'Failed to dispose controller during clear: $e',
          name: 'VideoControllerRepository',
          category: LogCategory.video,
        );
      }
    }

    _controllers.clear();
    _currentlyPlayingVideoId = null;

    Log.info(
      '🧹 [POOL] Cleared and disposed $count controllers',
      name: 'VideoControllerRepository',
      category: LogCategory.video,
    );

    notifyListeners();
  }

  @override
  void dispose() {
    // Dispose all controllers before clearing
    for (final entry in _controllers.values) {
      try {
        entry.controller.dispose();
      } catch (e) {
        // Ignore disposal errors during repository dispose
      }
    }
    _controllers.clear();
    _authHeadersCache.clear();
    super.dispose();
  }

  @override
  String toString() {
    return 'VideoControllerRepository('
        'active: $activeCount/$maxConcurrentControllers, '
        'playing: $_currentlyPlayingVideoId'
        ')';
  }

  // ===========================================================================
  // Private Methods
  // ===========================================================================

  /// Update LRU access time for a video.
  void _recordAccess(String videoId) {
    final entry = _controllers.remove(videoId);
    if (entry != null) {
      entry.recordAccess();
      _controllers[videoId] = entry; // Re-insert at end (most recent)
    }
  }

  /// Get the video ID to evict (oldest idle, non-playing, non-initializing).
  ///
  /// Priority for eviction (first match wins):
  /// 1. Skip currently playing video
  /// 2. Skip checked-out controllers (in active provider use)
  /// 3. Skip controllers still initializing
  /// 4. Return oldest idle controller
  String? _getEvictionCandidate() {
    // First pass: look for idle (checked-in) controllers
    for (final videoId in _controllers.keys) {
      final entry = _controllers[videoId]!;

      // Skip currently playing video
      if (videoId == _currentlyPlayingVideoId) continue;

      // Skip checked-out controllers (in active use by providers)
      if (entry.isCheckedOut) continue;

      // Skip controllers still initializing
      if (entry.isInitializing) continue;

      Log.debug(
        '🎯 [POOL] Eviction candidate (idle): $videoId',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
      return videoId;
    }

    // Second pass: if all idle controllers are protected, force evict oldest non-playing
    for (final videoId in _controllers.keys) {
      final entry = _controllers[videoId]!;

      // Never evict currently playing video
      if (videoId == _currentlyPlayingVideoId) continue;

      // Never evict initializing controllers (would cause crashes)
      if (entry.isInitializing) continue;

      Log.warning(
        '🎯 [POOL] Force eviction candidate (checked out): $videoId',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
      return videoId;
    }

    return null;
  }

  /// Evict and dispose a controller from the pool.
  ///
  /// This is where disposal happens - NOT in the provider's onDispose.
  void _evictController(String videoId) {
    final entry = _controllers.remove(videoId);
    if (entry != null) {
      Log.info(
        '🗑️ [POOL] Evicting and disposing controller for $videoId',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );

      // Remove state listener if any (prevent callbacks to disposed controller)
      try {
        entry.controller.dispose();
      } catch (e) {
        Log.warning(
          'Failed to dispose evicted controller: $e',
          name: 'VideoControllerRepository',
          category: LogCategory.video,
        );
      }

      if (_currentlyPlayingVideoId == videoId) {
        _currentlyPlayingVideoId = null;
      }
    }
  }

  /// Create a new controller for the given params.
  VideoControllerResult _createController(VideoControllerParams params) {
    // Normalize URL (.bin extension handling)
    final videoUrl = _normalizeVideoUrl(params);

    // Get auth headers if available
    final authHeaders = _getAuthHeaders(params);

    // Create controller based on platform
    if (kIsWeb) {
      return _createWebController(params, videoUrl, authHeaders);
    } else {
      return _createNativeController(params, videoUrl, authHeaders);
    }
  }

  /// Create controller for web platform.
  VideoControllerResult _createWebController(
    VideoControllerParams params,
    String videoUrl,
    Map<String, String>? authHeaders,
  ) {
    Log.debug(
      '🌐 Web platform - using NETWORK URL for video ${params.videoId}',
      name: 'VideoControllerRepository',
      category: LogCategory.video,
    );

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      httpHeaders: authHeaders ?? {},
    );

    return VideoControllerResult(
      controller: controller,
      videoUrl: videoUrl,
      isFromCache: false,
      wasExisting: false,
    );
  }

  /// Create controller for native platforms (uses cache when available).
  VideoControllerResult _createNativeController(
    VideoControllerParams params,
    String videoUrl,
    Map<String, String>? authHeaders,
  ) {
    final cachedFile = _cacheManager.getCachedVideoSync(params.videoId);

    if (cachedFile != null && cachedFile.existsSync()) {
      Log.info(
        '✅ Using CACHED FILE for video ${params.videoId}: ${cachedFile.path}',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );

      final controller = VideoPlayerController.file(cachedFile);

      return VideoControllerResult(
        controller: controller,
        videoUrl: videoUrl,
        isFromCache: true,
        wasExisting: false,
      );
    }

    Log.debug(
      '📡 Using NETWORK URL for video ${params.videoId}',
      name: 'VideoControllerRepository',
      category: LogCategory.video,
    );

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      httpHeaders: authHeaders ?? {},
    );

    return VideoControllerResult(
      controller: controller,
      videoUrl: videoUrl,
      isFromCache: false,
      wasExisting: false,
    );
  }

  /// Normalize .bin URLs based on MIME type.
  String _normalizeVideoUrl(VideoControllerParams params) {
    String videoUrl = params.videoUrl;

    if (videoUrl.toLowerCase().endsWith('.bin') && params.videoEvent != null) {
      final videoEvent = params.videoEvent as dynamic;
      final mimeType = videoEvent.mimeType as String?;

      if (mimeType != null) {
        String? newExtension;
        if (mimeType.contains('webm')) {
          newExtension = '.webm';
        } else if (mimeType.contains('mp4')) {
          newExtension = '.mp4';
        }

        if (newExtension != null) {
          videoUrl = videoUrl.substring(0, videoUrl.length - 4) + newExtension;
          Log.debug(
            '🔧 Normalized .bin URL based on MIME type $mimeType: $newExtension',
            name: 'VideoControllerRepository',
            category: LogCategory.video,
          );
        }
      }
    }

    return videoUrl;
  }

  /// Get auth headers for a video.
  Map<String, String>? _getAuthHeaders(VideoControllerParams params) {
    if (!_ageVerificationService.isAdultContentVerified) {
      return null;
    }

    if (!_blossomAuthService.canCreateHeaders || params.videoEvent == null) {
      return null;
    }

    final cachedHeaders = _authHeadersCache[params.videoId];
    if (cachedHeaders != null) {
      Log.debug(
        '🔐 Using cached auth headers for video ${params.videoId}',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
      return cachedHeaders;
    }

    return null;
  }
}
