// ABOUTME: Riverpod provider for managing video editor state with text overlays and export tracking
// ABOUTME: Exposes EditorNotifier for state mutations and reactive EditorState updates

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_editor_state.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/widgets/video_editor/video_editor_meta_sheet.dart';

final videoEditorProvider = NotifierProvider<VideoEditorNotifier, EditorState>(
  VideoEditorNotifier.new,
);

class VideoEditorNotifier extends Notifier<EditorState> {
  @override
  EditorState build() {
    return const EditorState();
  }

  void selectClip(int index) {
    state = state.copyWith(currentClipIndex: index);
  }

  void startClipEditing() {
    state = state.copyWith(isEditing: true);
  }

  void stopClipEditing() {
    state = state.copyWith(isEditing: false);
  }

  void togglePlayPause() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void toggleMute() {
    state = state.copyWith(isMuted: !state.isMuted);
  }

  void initializeWithVideo(String videoPath) {
    state = state.copyWith(
      currentTime: '1.39',
      currentClipIndex: 2,
    );
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
    /* if (state.currentClipIndex < state.totalClips) {
      state = state.copyWith(currentClipIndex: state.currentClipIndex + 1);
    } */
  }

  void updateCurrentTime(String time) {
    state = state.copyWith(currentTime: time);
  }

  void close() {
    // Reset state or perform cleanup if needed
  }

  void done(BuildContext context) async {
    state = state.copyWith(isProcessing: true);

    /// TODO: Process with the video-editor
    // DUMMY CODE FOR TESTING
    Future.delayed(Duration(seconds: 5), () {
      state = state.copyWith(isProcessing: false);
    });

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101111),
      showDragHandle: true,
      builder: (context) => const VideoEditorMetaSheet(),
    );

    if (!context.mounted) return;

    await context.pushVideoPublish();
  }
}
