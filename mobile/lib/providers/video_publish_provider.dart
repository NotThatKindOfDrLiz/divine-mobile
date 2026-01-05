// ABOUTME: Riverpod provider for managing video publish screen state
// ABOUTME: Controls playback, mute state, and position tracking

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_publish_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Provider for video publish screen state management.
final videoPublishProvider =
    NotifierProvider<VideoPublishNotifier, VideoPublishState>(
      VideoPublishNotifier.new,
    );

/// Manages video publish screen state including playback and position.
class VideoPublishNotifier extends Notifier<VideoPublishState> {
  @override
  VideoPublishState build() {
    return const VideoPublishState();
  }

  /// Toggles between play and pause states.
  void togglePlayPause() {
    final newState = !state.isPlaying;
    state = state.copyWith(isPlaying: newState);

    Log.info(
      '${newState ? '▶️' : '⏸️'} Video ${newState ? 'playing' : 'paused'}',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Sets the playing state.
  void setPlaying(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);

    Log.info(
      '${isPlaying ? '▶️' : '⏸️'} Video playback set to '
      '${isPlaying ? 'playing' : 'paused'}',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Toggles mute state.
  void toggleMute() {
    final newState = !state.isMuted;
    state = state.copyWith(isMuted: newState);

    Log.info(
      '${newState ? '🔇' : '🔊'} Video ${newState ? 'muted' : 'unmuted'}',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Sets the muted state.
  void setMuted(bool isMuted) {
    state = state.copyWith(isMuted: isMuted);

    Log.info(
      '${isMuted ? '🔇' : '🔊'} Video audio set to '
      '${isMuted ? 'muted' : 'unmuted'}',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Updates current playback position.
  void updatePosition(Duration position) {
    state = state.copyWith(currentPosition: position);
  }

  /// Sets total video duration.
  void setDuration(Duration duration) {
    state = state.copyWith(totalDuration: duration);

    Log.info(
      '⏱️ Video duration set: ${duration.inSeconds}s',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Sets video data and metadata for publishing.
  void setVideoData({
    required EditorVideo video,
    required VideoMetadata metadata,
  }) {
    state = state.copyWith(
      video: video,
      videoMetadata: metadata,
    );

    Log.info(
      '📹 Video data loaded: ${metadata.resolution.width}x'
      '${metadata.resolution.height}',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Resets state to initial values.
  void reset() {
    state = const VideoPublishState();

    Log.info(
      '🔄 Video publish state reset',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }
}
