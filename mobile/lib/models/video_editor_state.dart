// ABOUTME: Immutable state model for video editor managing text overlays, sound, and export progress
// ABOUTME: Tracks editing state with export stages and computed properties for UI state

import 'package:flutter/material.dart';

class EditorState {
  const EditorState({
    this.videoPath = '',
    this.currentClipIndex = 1,
    this.currentTime = '0.00',
    this.isPlaying = false,
    this.isMuted = false,
    this.clips = const [],
    this.progressSegments = const [],
  });

  final String videoPath;
  final int currentClipIndex;
  final String currentTime;
  final bool isPlaying;
  final bool isMuted;
  final List<VideoClip> clips;
  final List<ProgressSegment> progressSegments;

  EditorState copyWith({
    String? videoPath,
    int? currentClipIndex,
    String? currentTime,
    bool? isPlaying,
    bool? isMuted,
    List<VideoClip>? clips,
    List<ProgressSegment>? progressSegments,
  }) {
    return EditorState(
      videoPath: videoPath ?? this.videoPath,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      currentTime: currentTime ?? this.currentTime,
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      clips: clips ?? this.clips,
      progressSegments: progressSegments ?? this.progressSegments,
    );
  }
}

class VideoClip {
  const VideoClip({
    required this.path,
    required this.duration,
    this.isCenter = false,
  });

  final String path;
  final Duration duration;
  final bool isCenter;
}

class ProgressSegment {
  const ProgressSegment({required this.duration, required this.color});

  final int duration;
  final Color color;
}
