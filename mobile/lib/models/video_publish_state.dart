// ABOUTME: Immutable state model for video publish screen
// ABOUTME: Tracks playback state and video metadata

import 'package:pro_video_editor/pro_video_editor.dart';

/// Immutable state for video publish screen.
class VideoPublishState {
  /// Creates a video publish state.
  const VideoPublishState({
    this.video,
    this.videoMetadata,
    this.isPlaying = true,
    this.isMuted = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
  });

  /// The edited video to publish.
  final EditorVideo? video;

  /// Video metadata including resolution and format.
  final VideoMetadata? videoMetadata;

  /// Whether video is currently playing.
  final bool isPlaying;

  /// Whether video audio is muted.
  final bool isMuted;

  /// Current playback position.
  final Duration currentPosition;

  /// Total video duration.
  final Duration totalDuration;

  /// Creates a copy with updated fields.
  VideoPublishState copyWith({
    EditorVideo? video,
    VideoMetadata? videoMetadata,
    bool? isPlaying,
    bool? isMuted,
    Duration? currentPosition,
    Duration? totalDuration,
  }) {
    return VideoPublishState(
      video: video ?? this.video,
      videoMetadata: videoMetadata ?? this.videoMetadata,
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }
}
