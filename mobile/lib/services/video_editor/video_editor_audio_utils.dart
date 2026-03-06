// ABOUTME: Shared helpers for local video-editor audio preview and mix logic.
// ABOUTME: Keeps timing/volume decisions testable outside widget code.

import 'dart:math' as math;

import 'package:openvine/models/video_editor/selected_audio_track.dart';

/// Resolves the editor preview volume for the video player's native audio.
double resolveEditorPreviewVideoVolume({
  required bool isMuted,
  required SelectedAudioTrack? selectedAudioTrack,
  required double originalAudioVolume,
}) {
  if (isMuted) return 0;
  if (selectedAudioTrack == null) return 1;
  return originalAudioVolume.clamp(0.0, 1.0);
}

/// Returns the audible end of the selected preview segment.
Duration calculateSelectedAudioPreviewEnd({
  required SelectedAudioTrack track,
  required Duration videoDuration,
}) {
  final previewLength = track.duration <= videoDuration
      ? track.duration
      : videoDuration;
  final previewEnd = track.sourceStartOffset + previewLength;
  return Duration(
    milliseconds: math.min(
      previewEnd.inMilliseconds,
      track.duration.inMilliseconds,
    ),
  );
}
