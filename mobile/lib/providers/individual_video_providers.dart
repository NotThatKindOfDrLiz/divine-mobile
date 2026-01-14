// ABOUTME: Individual video controller providers using Riverpod Family pattern
// ABOUTME: Thin wrapper around VideoControllerPool - pool handles all initialization
// ABOUTME: Provider only handles ref-specific error reactions and lifecycle

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:openvine/models/video_event.dart';
import 'package:video_player/video_player.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/repositories/video_controller_pool.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/services/video_cache_manager.dart';
import 'package:openvine/providers/app_providers.dart';

export 'package:openvine/repositories/video_controller_pool.dart'
    show maxPlaybackDuration, loopCheckInterval, VideoControllerErrorType;

part 'individual_video_providers.g.dart';

/// Parameters for video controller creation
class VideoControllerParams {
  const VideoControllerParams({
    required this.videoId,
    required this.videoUrl,
    this.videoEvent,
  });

  final String videoId;
  final String videoUrl;
  final VideoEvent? videoEvent; // VideoEvent for enhanced error reporting

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoControllerParams &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          videoUrl == other.videoUrl;

  @override
  int get hashCode => videoId.hashCode ^ videoUrl.hashCode;

  @override
  String toString() =>
      'VideoControllerParams(videoId: $videoId, videoUrl: $videoUrl, hasEvent: ${videoEvent != null})';
}

/// Loading state for individual videos
class VideoLoadingState {
  const VideoLoadingState({
    required this.videoId,
    required this.isLoading,
    required this.isInitialized,
    required this.hasError,
    this.errorMessage,
  });

  final String videoId;
  final bool isLoading;
  final bool isInitialized;
  final bool hasError;
  final String? errorMessage;

  VideoLoadingState copyWith({
    String? videoId,
    bool? isLoading,
    bool? isInitialized,
    bool? hasError,
    String? errorMessage,
  }) {
    return VideoLoadingState(
      videoId: videoId ?? this.videoId,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoLoadingState &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          isLoading == other.isLoading &&
          isInitialized == other.isInitialized &&
          hasError == other.hasError &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      Object.hash(videoId, isLoading, isInitialized, hasError, errorMessage);

  @override
  String toString() =>
      'VideoLoadingState(videoId: $videoId, isLoading: $isLoading, isInitialized: $isInitialized, hasError: $hasError, errorMessage: $errorMessage)';
}

/// Safe wrapper for async controller operations that may fail after disposal.
/// Returns true if operation succeeded, false if controller was disposed or errored.
Future<bool> safeControllerOperation(
  VideoPlayerController controller,
  String videoId,
  Future<void> Function() operation, {
  String? operationName,
}) async {
  try {
    // Quick sanity check - if not initialized, likely disposed or errored
    if (!controller.value.isInitialized) {
      Log.debug(
        '⏭️ Skipping ${operationName ?? 'operation'} for $videoId - controller not initialized',
        name: 'SafeController',
        category: LogCategory.video,
      );
      return false;
    }
    await operation();
    return true;
  } catch (e) {
    // Catch "No active player with ID" and similar disposal-related errors
    if (_isDisposalError(e)) {
      Log.debug(
        '⏭️ Controller already disposed for $videoId during ${operationName ?? 'operation'}: $e',
        name: 'SafeController',
        category: LogCategory.video,
      );
      return false;
    }
    // Rethrow unexpected errors
    rethrow;
  }
}

/// Safe wrapper for play operation.
Future<bool> safePlay(VideoPlayerController controller, String videoId) {
  return safeControllerOperation(
    controller,
    videoId,
    () => controller.play(),
    operationName: 'play',
  );
}

/// Safe wrapper for pause operation.
Future<bool> safePause(VideoPlayerController controller, String videoId) {
  return safeControllerOperation(
    controller,
    videoId,
    () => controller.pause(),
    operationName: 'pause',
  );
}

/// Safe wrapper for seekTo operation.
Future<bool> safeSeekTo(
  VideoPlayerController controller,
  String videoId,
  Duration position,
) {
  return safeControllerOperation(
    controller,
    videoId,
    () => controller.seekTo(position),
    operationName: 'seekTo',
  );
}

/// Check if an error indicates the controller/player has been disposed.
bool _isDisposalError(dynamic e) {
  final errorStr = e.toString().toLowerCase();
  return errorStr.contains('no active player') ||
      errorStr.contains('bad state') ||
      errorStr.contains('disposed') ||
      errorStr.contains('player with id');
}

/// Provider for individual video controllers with autoDispose.
///
/// This is a thin wrapper around VideoControllerPool. The pool handles:
/// - Controller creation (platform-specific, cache-aware)
/// - Initialization with retry logic (in background)
/// - Loop enforcement for long videos
/// - State change tracking
/// - LRU eviction when at capacity
///
/// This provider only handles:
/// - Ref-specific error reactions (cache corruption retry, broken video tracking)
/// - Lifecycle management (checkin on dispose)
///
/// **Important:** The controller is returned immediately but may not be
/// initialized yet. Callers should check `controller.value.isInitialized`.
@riverpod
VideoPlayerController individualVideoController(
  Ref ref,
  VideoControllerParams params,
) {
  final pool = ref.read(videoControllerPoolProvider);

  // Checkout controller from pool (handles creation, init in background)
  final result = pool.checkout(
    params,
    onError: (errorType, errorMessage) {
      // Handle errors that need ref-specific reactions
      _handleControllerError(ref, errorType, errorMessage, params);
    },
  );

  // Set up disposal - return controller to pool
  ref.onDispose(() {
    Log.info(
      '📥 Checking in VideoPlayerController for video ${params.videoId}',
      name: 'IndividualVideoController',
      category: LogCategory.system,
    );
    pool.checkin(params.videoId);
  });

  return result.controller;
}

/// Handle controller errors that need ref-specific reactions.
void _handleControllerError(
  Ref ref,
  VideoControllerErrorType errorType,
  String errorMessage,
  VideoControllerParams params,
) {
  switch (errorType) {
    case VideoControllerErrorType.unauthorized:
      // Log for diagnostics - UI layer handles showing verification dialog
      Log.warning(
        '🔐 Detected 401 Unauthorized for video ${params.videoId} - age verification may be required',
        name: 'IndividualVideoController',
        category: LogCategory.video,
      );

    case VideoControllerErrorType.cacheCorrupted:
      // Remove corrupted cache and retry
      if (!kIsWeb) {
        Log.warning(
          '🗑️ Detected corrupted cache for video ${params.videoId} - removing and will retry',
          name: 'IndividualVideoController',
          category: LogCategory.video,
        );

        openVineVideoCache
            .removeCorruptedVideo(params.videoId)
            .then((_) {
              if (ref.mounted) {
                Log.info(
                  '🔄 Invalidating provider to retry download for video ${params.videoId}',
                  name: 'IndividualVideoController',
                  category: LogCategory.video,
                );
                ref.invalidateSelf();
              }
            })
            .catchError((removeError) {
              Log.error(
                '❌ Failed to remove corrupted cache: $removeError',
                name: 'IndividualVideoController',
                category: LogCategory.video,
              );
            });
      }

    case VideoControllerErrorType.videoBroken:
    case VideoControllerErrorType.timeout:
      // Mark video as broken for filtering
      if (ref.mounted) {
        ref
            .read(brokenVideoTrackerProvider.future)
            .then((tracker) {
              if (ref.mounted) {
                tracker.markVideoBroken(
                  params.videoId,
                  'Playback initialization failed: $errorMessage',
                );
              }
            })
            .catchError((trackerError) {
              Log.warning(
                'Failed to mark video as broken: $trackerError',
                name: 'IndividualVideoController',
                category: LogCategory.system,
              );
            });
      }

    case VideoControllerErrorType.none:
    case VideoControllerErrorType.other:
      // No specific handling needed
      break;
  }
}

/// Provider for video loading state
@riverpod
VideoLoadingState videoLoadingState(Ref ref, VideoControllerParams params) {
  final controller = ref.watch(individualVideoControllerProvider(params));

  if (controller.value.hasError) {
    return VideoLoadingState(
      videoId: params.videoId,
      isLoading: false,
      isInitialized: false,
      hasError: true,
      errorMessage: controller.value.errorDescription,
    );
  }

  if (controller.value.isInitialized) {
    return VideoLoadingState(
      videoId: params.videoId,
      isLoading: false,
      isInitialized: true,
      hasError: false,
    );
  }

  return VideoLoadingState(
    videoId: params.videoId,
    isLoading: true,
    isInitialized: false,
    hasError: false,
  );
}
