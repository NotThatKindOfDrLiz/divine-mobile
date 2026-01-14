// ABOUTME: Helper utilities for video controller lifecycle management
// ABOUTME: Provides functions to clear video controllers when entering camera or other screens

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Tracks the last clear time to prevent duplicate clears.
/// We debounce by skipping repeated calls within the frame time window
/// (16ms at 60fps).
///
/// Thread-safety: This global state is safe because Flutter UI code runs on
/// a single isolate. All calls to disposeAllVideoControllers happen on the
/// main UI thread.
DateTime? _lastClearTime;

/// Minimum time between clears (one frame at 60fps)
const _debounceThreshold = Duration(milliseconds: 16);

/// Dispose all video controllers by clearing the controller pool.
///
/// This clears all controllers from the pool and disposes them, freeing
/// platform video player resources. Use this when entering camera screen
/// or other contexts that need to fully release video resources.
///
/// **How it works with the pool model:**
/// 1. Invalidates all provider instances (triggers checkin for each)
/// 2. Calls pool.clear() to dispose all controllers in the pool
///
/// Includes a debounce guard to prevent multiple clears in the same frame.
///
/// Works with both WidgetRef and ProviderContainer.
void disposeAllVideoControllers(Object ref) {
  final now = DateTime.now();

  // Skip if we cleared too recently (within same frame)
  if (_lastClearTime != null) {
    final elapsed = now.difference(_lastClearTime!);
    // Handle clock adjustments: negative duration means clock went backwards,
    // so allow the clear (treat as if enough time has passed)
    if (elapsed >= Duration.zero && elapsed < _debounceThreshold) {
      Log.debug(
        '🛡️ Skipping duplicate pool clear (${elapsed.inMilliseconds}ms since last)',
        name: 'VideoControllerCleanup',
        category: LogCategory.video,
      );
      return;
    }
  }
  _lastClearTime = now;

  Log.info(
    '🧹 Clearing all video controllers from pool',
    name: 'VideoControllerCleanup',
    category: LogCategory.video,
  );

  if (ref is WidgetRef) {
    // Invalidate providers first (triggers checkin)
    ref.invalidate(individualVideoControllerProvider);
    // Then clear pool to dispose all controllers
    ref.read(videoControllerRepositoryProvider).clear();
  } else if (ref is ProviderContainer) {
    // Invalidate providers first (triggers checkin)
    ref.invalidate(individualVideoControllerProvider);
    // Then clear pool to dispose all controllers
    ref.read(videoControllerRepositoryProvider).clear();
  } else {
    throw ArgumentError(
      'Expected WidgetRef or ProviderContainer, got ${ref.runtimeType}',
    );
  }
}
