// ABOUTME: Riverpod provider for managing video editor state with text overlays and export tracking
// ABOUTME: Exposes EditorNotifier for state mutations and reactive EditorState updates

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_editor_state.dart';

final videoEditorProvider = NotifierProvider<VideoEditorNotifier, EditorState>(
  VideoEditorNotifier.new,
);

class VideoEditorNotifier extends Notifier<EditorState> {
  @override
  EditorState build() {
    return const EditorState(
      progressSegments: [
        ProgressSegment(
          duration: 170,
          color: Color(0x8027C58B), // Primary green with 50% opacity
        ),
        ProgressSegment(
          duration: 52,
          color: Color(0xFF27C58B), // Primary green
        ),
        ProgressSegment(
          duration: 24,
          color: Color(0x40FFFFFF), // White with 25% opacity
        ),
        ProgressSegment(duration: 67, color: Color(0x40FFFFFF)),
        ProgressSegment(duration: 48, color: Color(0x40FFFFFF)),
      ],
    );
  }

  void initializeWithVideo(String videoPath) {
    state = state.copyWith(
      videoPath: videoPath,
      currentTime: '1.39',
      totalTime: '6.00',
      totalClips: 4,
      currentClipIndex: 2,
    );
  }

  void togglePlayPause() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void toggleMute() {
    state = state.copyWith(isMuted: !state.isMuted);
  }

  void showMoreOptions() {
    // TODO: Implement more options
  }

  void previousClip() {
    if (state.currentClipIndex > 1) {
      state = state.copyWith(currentClipIndex: state.currentClipIndex - 1);
    }
  }

  void nextClip() {
    if (state.currentClipIndex < state.totalClips) {
      state = state.copyWith(currentClipIndex: state.currentClipIndex + 1);
    }
  }

  void updateCurrentTime(String time) {
    state = state.copyWith(currentTime: time);
  }

  void close() {
    // Reset state or perform cleanup if needed
  }

  void done() {
    // TODO: Export or save video
  }
}
