// ABOUTME: Error overlay widget for video playback failures
// ABOUTME: Handles 401 age-restricted content and general playback errors with retry functionality

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Error overlay shown when video playback fails
///
/// Displays different UI for 401 errors (age-restricted) vs other errors:
/// - 401: Lock icon + "Age-restricted content" + "Verify Age" button
/// - Other: Error icon + error message + "Retry" button
class VideoErrorOverlay extends ConsumerWidget {
  const VideoErrorOverlay({
    super.key,
    required this.video,
    required this.controllerParams,
    required this.errorDescription,
    required this.isActive,
  });

  final VideoEvent video;
  final VideoControllerParams controllerParams;
  final String errorDescription;
  final bool isActive;

  /// Check for 401 Unauthorized - likely NSFW content
  bool get _is401Error {
    final lowerError = errorDescription.toLowerCase();
    return lowerError.contains('401') || lowerError.contains('unauthorized');
  }

  /// Translate error messages to user-friendly text
  String get _errorMessage {
    final lowerError = errorDescription.toLowerCase();

    if (lowerError.contains('404') || lowerError.contains('not found')) {
      return 'Video not found';
    }
    if (lowerError.contains('network') || lowerError.contains('connection')) {
      return 'Network error';
    }
    if (lowerError.contains('timeout')) {
      return 'Loading timeout';
    }
    if (lowerError.contains('byte range') ||
        lowerError.contains('coremediaerrordomain')) {
      return 'Video format error\n(Try again or use different browser)';
    }
    if (lowerError.contains('format') || lowerError.contains('codec')) {
      return 'Unsupported video format';
    }

    return 'Video playback error';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Show thumbnail as background
        VideoThumbnailWidget(
          video: video,
          fit: BoxFit.cover,
          showPlayIcon: false,
        ),
        // Error overlay (only show on active video)
        if (isActive)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _is401Error ? Icons.lock_outline : Icons.error_outline,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _is401Error ? 'Age-restricted content' : _errorMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_is401Error) {
                        Log.info(
                          '🔐 [AGE-GATE] User tapped Verify Age button for video ${video.id}',
                          name: 'VideoErrorOverlay',
                          category: LogCategory.video,
                        );

                        // Show age verification dialog
                        final ageVerificationService = ref.read(
                          ageVerificationServiceProvider,
                        );
                        final verified = await ageVerificationService
                            .verifyAdultContentAccess(context);

                        Log.info(
                          '🔐 [AGE-GATE] Dialog result: verified=$verified',
                          name: 'VideoErrorOverlay',
                          category: LogCategory.video,
                        );

                        if (verified && context.mounted) {
                          // Only retry if this video is still active
                          final activeVideoId = ref.read(activeVideoIdProvider);
                          final isThisVideoActive =
                              activeVideoId == video.stableId ||
                              activeVideoId == video.id;

                          if (isThisVideoActive && context.mounted) {
                            Log.info(
                              '🔐 [AGE-GATE] Evicting and retrying video ${video.id}',
                              name: 'VideoErrorOverlay',
                              category: LogCategory.video,
                            );
                            // Evict failed controller from pool, then invalidate provider
                            // Pool will create fresh controller with auth headers
                            final pool = ref.read(videoControllerPoolProvider);
                            pool.evict(controllerParams.videoId);
                            ref.invalidate(
                              individualVideoControllerProvider(
                                controllerParams,
                              ),
                            );
                          } else {
                            Log.debug(
                              'Age verification completed but video no longer active',
                              name: 'VideoErrorOverlay',
                              category: LogCategory.video,
                            );
                          }
                        }
                      } else {
                        // Regular retry - evict failed controller first
                        final pool = ref.read(videoControllerPoolProvider);
                        pool.evict(controllerParams.videoId);
                        ref.invalidate(
                          individualVideoControllerProvider(controllerParams),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: Text(_is401Error ? 'Verify Age' : 'Retry'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
