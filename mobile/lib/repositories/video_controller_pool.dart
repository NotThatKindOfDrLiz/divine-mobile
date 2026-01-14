// ABOUTME: Pool for managing video player controllers with LRU eviction
// ABOUTME: Owns controller lifecycle - controllers are only disposed on eviction or clear()
// ABOUTME: Providers "checkout" controllers and "checkin" when done (no disposal in provider)
// ABOUTME: Handles full initialization including retry, loop enforcement, and state tracking

import 'dart:async';
import 'dart:collection';
import 'dart:ui' show VoidCallback;

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:openvine/providers/individual_video_providers.dart'
    show VideoControllerParams;
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/blossom_auth_service.dart';
import 'package:openvine/services/video_cache_manager.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:video_player/video_player.dart';

/// Maximum playback duration before looping (6.3 seconds)
/// Videos longer than this will loop back to beginning at this mark
const maxPlaybackDuration = Duration(milliseconds: 6300);

/// Interval for checking playback position (200ms = 5 checks/sec)
/// Balances responsiveness with performance (vs 60 checks/sec for per-frame)
const loopCheckInterval = Duration(milliseconds: 200);

/// Error types that can occur during controller initialization.
enum VideoControllerErrorType {
  /// No error occurred
  none,

  /// 401 Unauthorized - likely NSFW content requiring age verification
  unauthorized,

  /// Cache file is corrupted and should be cleared
  cacheCorrupted,

  /// Video URL is broken/non-functional (404, timeout, etc.)
  videoBroken,

  /// Initialization timed out
  timeout,

  /// Other initialization error
  other,
}

/// Result of acquiring a controller from the pool.
class VideoControllerResult {
  const VideoControllerResult({
    required this.controller,
    required this.videoUrl,
    required this.isFromCache,
    required this.wasExisting,
    this.errorType = VideoControllerErrorType.none,
    this.errorMessage,
  });

  /// The video player controller (initialized if no error).
  final VideoPlayerController controller;

  /// The final video URL used (may be normalized from .bin).
  final String videoUrl;

  /// Whether the controller was created from a cached file.
  final bool isFromCache;

  /// Whether this controller already existed in the pool.
  final bool wasExisting;

  /// Error type if initialization failed.
  final VideoControllerErrorType errorType;

  /// Error message if initialization failed.
  final String? errorMessage;

  /// Whether the controller initialized successfully.
  bool get hasError => errorType != VideoControllerErrorType.none;
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

  /// Timer for enforcing 6.3s loop on long videos.
  Timer? loopEnforcementTimer;

  /// State change listener attached to controller.
  VoidCallback? stateListener;

  void recordAccess() {
    lastAccessTime = DateTime.now();
  }

  /// Cleanup timers and listeners before disposal.
  void cleanup() {
    loopEnforcementTimer?.cancel();
    loopEnforcementTimer = null;
    if (stateListener != null) {
      controller.removeListener(stateListener!);
      stateListener = null;
    }
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
class VideoControllerPool extends ChangeNotifier {
  VideoControllerPool({
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
  /// Initialization happens in the background - callers should check
  /// `controller.value.isInitialized` before using.
  ///
  /// The controller is marked as "checked out" and protected from eviction
  /// until [checkin] is called.
  ///
  /// [onError] is called if initialization fails, allowing the caller to
  /// handle errors (e.g., mark video as broken, clear corrupted cache).
  VideoControllerResult checkout(
    VideoControllerParams params, {
    void Function(VideoControllerErrorType type, String message)? onError,
  }) {
    final videoId = params.videoId;

    // Check if we already have this controller in pool
    final existing = _controllers[videoId];
    if (existing != null) {
      existing.isCheckedOut = true; // Mark as in-use
      _recordAccess(videoId);
      Log.debug(
        '🎬 [POOL] Returning pooled controller for $videoId',
        name: 'VideoControllerPool',
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
    final createResult = _createController(params);
    final controller = createResult.controller;

    // Store in pool (starts as checked out and initializing)
    final entry = _ControllerEntry(
      controller: controller,
      videoUrl: createResult.videoUrl,
      isFromCache: createResult.isFromCache,
      params: params,
    );
    _controllers[videoId] = entry;

    Log.info(
      '🎬 [POOL] Created controller for $videoId (count: ${_controllers.length}/$maxConcurrentControllers)',
      name: 'VideoControllerPool',
      category: LogCategory.video,
    );

    notifyListeners();

    // Trigger background caching if needed
    if (!createResult.isFromCache && shouldCacheVideo(params)) {
      unawaited(
        _cacheVideoInBackground(params).catchError((error) {
          Log.warning(
            '⚠️ Background video caching failed: $error',
            name: 'VideoControllerPool',
            category: LogCategory.video,
          );
          return null;
        }),
      );
      unawaited(cacheAuthHeaders(params));
    }

    // Start initialization in background (fire-and-forget)
    unawaited(
      _initializeController(entry, params).then((result) {
        if (result.hasError && onError != null) {
          onError(result.errorType, result.errorMessage ?? 'Unknown error');
        }
      }),
    );

    return VideoControllerResult(
      controller: controller,
      videoUrl: createResult.videoUrl,
      isFromCache: createResult.isFromCache,
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
        name: 'VideoControllerPool',
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
        name: 'VideoControllerPool',
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
      name: 'VideoControllerPool',
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
        name: 'VideoControllerPool',
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
          name: 'VideoControllerPool',
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
          name: 'VideoControllerPool',
          category: LogCategory.video,
        );
      }
    } catch (error) {
      Log.debug(
        'Failed to generate auth headers: $error',
        name: 'VideoControllerPool',
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

    // Cleanup and dispose each controller before clearing
    for (final entry in _controllers.values) {
      entry.cleanup();
      try {
        entry.controller.dispose();
      } catch (e) {
        Log.warning(
          'Failed to dispose controller during clear: $e',
          name: 'VideoControllerPool',
          category: LogCategory.video,
        );
      }
    }

    _controllers.clear();
    _currentlyPlayingVideoId = null;

    Log.info(
      '🧹 [POOL] Cleared and disposed $count controllers',
      name: 'VideoControllerPool',
      category: LogCategory.video,
    );

    notifyListeners();
  }

  @override
  void dispose() {
    // Cleanup and dispose all controllers before clearing
    for (final entry in _controllers.values) {
      entry.cleanup();
      try {
        entry.controller.dispose();
      } catch (e) {
        // Ignore disposal errors during pool dispose
      }
    }
    _controllers.clear();
    _authHeadersCache.clear();
    super.dispose();
  }

  @override
  String toString() {
    return 'VideoControllerPool('
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
        name: 'VideoControllerPool',
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
        name: 'VideoControllerPool',
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
        name: 'VideoControllerPool',
        category: LogCategory.video,
      );

      // Cleanup timers and listeners before disposing
      entry.cleanup();

      try {
        entry.controller.dispose();
      } catch (e) {
        Log.warning(
          'Failed to dispose evicted controller: $e',
          name: 'VideoControllerPool',
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
      name: 'VideoControllerPool',
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
        name: 'VideoControllerPool',
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
      name: 'VideoControllerPool',
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
            name: 'VideoControllerPool',
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
        name: 'VideoControllerPool',
        category: LogCategory.video,
      );
      return cachedHeaders;
    }

    return null;
  }

  // ===========================================================================
  // Controller Initialization
  // ===========================================================================

  /// Initialize controller with retry logic, loop enforcement, and state tracking.
  Future<VideoControllerResult> _initializeController(
    _ControllerEntry entry,
    VideoControllerParams params,
  ) async {
    final controller = entry.controller;
    final videoId = params.videoId;

    // Set up state change listener
    _setupStateListener(entry, params);

    // Determine timeout based on video format
    final isHls =
        params.videoUrl.toLowerCase().contains('.m3u8') ||
        params.videoUrl.toLowerCase().contains('hls');
    final timeoutDuration = isHls
        ? const Duration(seconds: 60)
        : const Duration(seconds: 30);
    final formatType = isHls ? 'HLS' : 'MP4';

    // Initialize with retry logic
    const maxAttempts = 3;
    const retryDelay = Duration(milliseconds: 500);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await controller.initialize().timeout(
          timeoutDuration,
          onTimeout: () => throw TimeoutException(
            'Video initialization timed out after ${timeoutDuration.inSeconds} seconds ($formatType format)',
          ),
        );

        // Success! Exit retry loop
        if (attempt > 1) {
          Log.info(
            '✅ Video $videoId initialized successfully on attempt $attempt',
            name: 'VideoControllerPool',
            category: LogCategory.video,
          );
        }

        // Post-initialization setup
        return _completeInitialization(entry, params);
      } catch (error) {
        final errorStr = error.toString().toLowerCase();
        final isRetryable =
            errorStr.contains('byte range') ||
            errorStr.contains('coremediaerrordomain') ||
            errorStr.contains('network') ||
            errorStr.contains('connection');

        if (isRetryable && attempt < maxAttempts) {
          Log.warning(
            '⚠️ Video $videoId initialization attempt $attempt failed (retryable): $error',
            name: 'VideoControllerPool',
            category: LogCategory.video,
          );
          await Future.delayed(retryDelay);
          // Continue to next attempt
        } else {
          // Non-retryable error or max attempts reached
          if (attempt == maxAttempts) {
            Log.error(
              '❌ Video $videoId initialization failed after $maxAttempts attempts',
              name: 'VideoControllerPool',
              category: LogCategory.video,
            );
          }

          return _handleInitializationError(entry, params, error);
        }
      }
    }

    // Should never reach here, but return error result just in case
    return VideoControllerResult(
      controller: controller,
      videoUrl: entry.videoUrl,
      isFromCache: entry.isFromCache,
      wasExisting: false,
      errorType: VideoControllerErrorType.other,
      errorMessage: 'Unexpected initialization failure',
    );
  }

  /// Complete initialization after successful controller.initialize().
  VideoControllerResult _completeInitialization(
    _ControllerEntry entry,
    VideoControllerParams params,
  ) {
    final controller = entry.controller;
    final videoId = params.videoId;

    final initialPosition = controller.value.position;
    final initialSize = controller.value.size;

    Log.info(
      '✅ VideoPlayerController initialized for video $videoId\n'
      '   • Initial position: ${initialPosition.inMilliseconds}ms\n'
      '   • Duration: ${controller.value.duration.inMilliseconds}ms\n'
      '   • Size: ${initialSize.width.toInt()}x${initialSize.height.toInt()}\n'
      '   • Buffered: ${controller.value.buffered.isNotEmpty ? controller.value.buffered.last.end.inMilliseconds : 0}ms',
      name: 'VideoControllerPool',
      category: LogCategory.system,
    );

    // Set looping for Vine-like behavior
    controller.setLooping(true);

    // Mark as initialized
    entry.isInitializing = false;

    // Set up loop enforcement for long videos
    _setupLoopEnforcement(entry, params);

    // Seek to beginning if video started at non-zero position
    if (initialPosition.inMilliseconds > 0) {
      Log.warning(
        '⚠️ VIDEO NOT AT START! Video $videoId initialized at ${initialPosition.inMilliseconds}ms instead of 0ms',
        name: 'VideoControllerPool',
        category: LogCategory.video,
      );
      controller.seekTo(Duration.zero).catchError((e) {
        Log.error(
          '❌ Failed to seek video $videoId to start: $e',
          name: 'VideoControllerPool',
          category: LogCategory.video,
        );
      });
    }

    Log.debug(
      '⏸️ Video $videoId initialized and paused (widget controls playback)',
      name: 'VideoControllerPool',
      category: LogCategory.system,
    );

    return VideoControllerResult(
      controller: controller,
      videoUrl: entry.videoUrl,
      isFromCache: entry.isFromCache,
      wasExisting: false,
    );
  }

  /// Handle initialization errors and categorize them.
  VideoControllerResult _handleInitializationError(
    _ControllerEntry entry,
    VideoControllerParams params,
    dynamic error,
  ) {
    final controller = entry.controller;
    final errorMessage = error.toString();

    // Log detailed error
    _logInitializationError(params, errorMessage);

    // Mark as no longer initializing
    entry.isInitializing = false;

    // Categorize the error
    final errorType = _categorizeError(errorMessage);

    return VideoControllerResult(
      controller: controller,
      videoUrl: entry.videoUrl,
      isFromCache: entry.isFromCache,
      wasExisting: false,
      errorType: errorType,
      errorMessage: errorMessage,
    );
  }

  /// Log detailed initialization error with Nostr event info if available.
  void _logInitializationError(VideoControllerParams params, String errorMessage) {
    final videoId = params.videoId;
    var logMessage = '❌ VideoPlayerController initialization failed for video $videoId: $errorMessage';

    if (params.videoEvent != null) {
      final event = params.videoEvent as dynamic;
      logMessage += '\n📋 Full Nostr Event Details:';
      logMessage += '\n   • Event ID: ${event.id}';
      logMessage += '\n   • Pubkey: ${event.pubkey}';
      logMessage += '\n   • Content: ${event.content}';
      logMessage += '\n   • Video URL: ${event.videoUrl}';
      logMessage += '\n   • Title: ${event.title ?? 'null'}';
      logMessage += '\n   • Duration: ${event.duration ?? 'null'}';
      logMessage += '\n   • Dimensions: ${event.dimensions ?? 'null'}';
      logMessage += '\n   • MIME Type: ${event.mimeType ?? 'null'}';
      logMessage += '\n   • File Size: ${event.fileSize ?? 'null'}';
      logMessage += '\n   • SHA256: ${event.sha256 ?? 'null'}';
      logMessage += '\n   • Thumbnail URL: ${event.thumbnailUrl ?? 'null'}';
      logMessage += '\n   • Hashtags: ${event.hashtags ?? []}';
      logMessage += '\n   • Created At: ${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)}';
      if (event.rawTags != null && event.rawTags.isNotEmpty) {
        logMessage += '\n   • Raw Tags: ${event.rawTags}';
      }
    } else {
      logMessage += '\n⚠️  No Nostr event details available';
    }

    Log.error(
      logMessage,
      name: 'VideoControllerPool',
      category: LogCategory.system,
    );
  }

  /// Categorize an error message into an error type.
  VideoControllerErrorType _categorizeError(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();

    // Check for 401 Unauthorized
    if (lowerError.contains('401') ||
        lowerError.contains('unauthorized') ||
        lowerError.contains('invalid statuscode: 401')) {
      return VideoControllerErrorType.unauthorized;
    }

    // Check for cache corruption
    if (lowerError.contains('osstatus error -12848') ||
        lowerError.contains('media may be damaged') ||
        lowerError.contains('cannot open') ||
        (lowerError.contains('failed to load video') &&
            lowerError.contains('damaged'))) {
      return VideoControllerErrorType.cacheCorrupted;
    }

    // Check for timeout
    if (lowerError.contains('timeout') ||
        lowerError.contains('timed out')) {
      return VideoControllerErrorType.timeout;
    }

    // Check for broken video (404, network errors, etc.)
    if (lowerError.contains('404') ||
        lowerError.contains('not found') ||
        lowerError.contains('invalid statuscode: 404') ||
        lowerError.contains('httpexception') ||
        lowerError.contains('connection refused') ||
        lowerError.contains('network error')) {
      return VideoControllerErrorType.videoBroken;
    }

    return VideoControllerErrorType.other;
  }

  /// Set up loop enforcement timer for videos longer than 6.3 seconds.
  void _setupLoopEnforcement(
    _ControllerEntry entry,
    VideoControllerParams params,
  ) {
    final controller = entry.controller;
    final videoId = params.videoId;
    final videoDuration = controller.value.duration;

    if (videoDuration > maxPlaybackDuration) {
      entry.loopEnforcementTimer = Timer.periodic(loopCheckInterval, (timer) {
        // Skip check if video is paused
        if (!controller.value.isPlaying) return;

        // Enforce loop at 6.3s mark
        if (controller.value.position >= maxPlaybackDuration) {
          Log.debug(
            '🔄 Loop enforcement: $videoId at ${controller.value.position.inMilliseconds}ms → seeking to 0',
            name: 'LoopEnforcement',
            category: LogCategory.video,
          );
          controller.seekTo(Duration.zero).catchError((e) {
            Log.warning(
              'Loop seek failed: $e',
              name: 'LoopEnforcement',
              category: LogCategory.video,
            );
          });
        }
      });
      Log.info(
        '⏱️ Started loop enforcement timer for $videoId (duration: ${videoDuration.inMilliseconds}ms > ${maxPlaybackDuration.inMilliseconds}ms)',
        name: 'LoopEnforcement',
        category: LogCategory.video,
      );
    }
  }

  /// Set up state change listener for logging significant state changes.
  void _setupStateListener(
    _ControllerEntry entry,
    VideoControllerParams params,
  ) {
    final controller = entry.controller;
    final videoId = params.videoId;

    // Track previous state to avoid logging every frame update
    bool? lastIsInitialized;
    bool? lastIsBuffering;
    bool? lastHasError;

    void stateChangeListener() {
      final value = controller.value;
      final isInitialized = value.isInitialized;
      final isBuffering = value.isBuffering;
      final hasError = value.hasError;

      // Log only when significant state changes occur
      if (isInitialized != lastIsInitialized ||
          isBuffering != lastIsBuffering ||
          hasError != lastHasError) {
        final position = value.position;
        final duration = value.duration;
        final buffered = value.buffered.isNotEmpty
            ? value.buffered.last.end
            : Duration.zero;

        Log.debug(
          '🎬 VIDEO STATE CHANGE [$videoId]:\n'
          '   • Position: ${position.inMilliseconds}ms / ${duration.inMilliseconds}ms\n'
          '   • Buffered: ${buffered.inMilliseconds}ms\n'
          '   • Initialized: $isInitialized\n'
          '   • Playing: ${value.isPlaying}\n'
          '   • Buffering: $isBuffering\n'
          '   • Size: ${value.size.width.toInt()}x${value.size.height.toInt()}\n'
          '   • HasError: $hasError',
          name: 'VideoControllerPool',
          category: LogCategory.video,
        );

        lastIsInitialized = isInitialized;
        lastIsBuffering = isBuffering;
        lastHasError = hasError;
      }
    }

    controller.addListener(stateChangeListener);
    entry.stateListener = stateChangeListener;
  }

  /// Cache video in background with authentication if needed.
  Future<void> _cacheVideoInBackground(VideoControllerParams params) async {
    // Get auth headers if needed for NSFW content
    Map<String, String>? authHeaders;

    if (_ageVerificationService.isAdultContentVerified &&
        _blossomAuthService.canCreateHeaders &&
        params.videoEvent != null) {
      final videoEvent = params.videoEvent as dynamic;
      final sha256 = videoEvent.sha256 as String?;

      if (sha256 != null && sha256.isNotEmpty) {
        String? serverUrl;
        try {
          final uri = Uri.parse(params.videoUrl);
          serverUrl = '${uri.scheme}://${uri.host}';
        } catch (e) {
          Log.warning(
            'Failed to parse video URL for server: $e',
            name: 'VideoControllerPool',
            category: LogCategory.video,
          );
        }

        final authHeader = await _blossomAuthService.createGetAuthHeader(
          sha256Hash: sha256,
          serverUrl: serverUrl,
        );

        if (authHeader != null) {
          authHeaders = {'Authorization': authHeader};
          Log.info(
            '✅ Added Blossom auth header for NSFW video cache',
            name: 'VideoControllerPool',
            category: LogCategory.video,
          );
        }
      }
    }

    // Cache video with optional auth headers
    await _cacheManager.cacheVideo(
      params.videoUrl,
      params.videoId,
      authHeaders: authHeaders,
    );
  }
}
