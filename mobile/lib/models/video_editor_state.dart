// ABOUTME: Immutable state model for video editor managing text overlays, sound, and export progress
// ABOUTME: Tracks editing state with export stages and computed properties for UI state

import 'package:pro_video_editor/pro_video_editor.dart';

class EditorState {
  const EditorState({
    this.editedVideo,
    this.editedVideoMeta,
    this.currentClipIndex = 0,
    this.currentTime = '0.00',
    this.isEditing = false,
    this.isReordering = false,
    this.isOverDeleteZone = false,
    this.isPlaying = false,
    this.isMuted = false,
    this.isProcessing = false,
  });

  final EditorVideo? editedVideo;
  final VideoMetadata? editedVideoMeta;
  final int currentClipIndex;
  final String currentTime;

  final bool isEditing;
  final bool isReordering;
  final bool isOverDeleteZone;
  final bool isPlaying;
  final bool isMuted;
  final bool isProcessing;

  EditorState copyWith({
    EditorVideo? editedVideo,
    VideoMetadata? editedVideoMeta,
    bool? isEditing,
    bool? isReordering,
    bool? isOverDeleteZone,
    int? currentClipIndex,
    String? currentTime,
    bool? isPlaying,
    bool? isMuted,
    bool? isProcessing,
  }) {
    return EditorState(
      editedVideo: editedVideo ?? this.editedVideo,
      editedVideoMeta: editedVideoMeta ?? this.editedVideoMeta,
      isEditing: isEditing ?? this.isEditing,
      isReordering: isReordering ?? this.isReordering,
      isOverDeleteZone: isOverDeleteZone ?? this.isOverDeleteZone,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      currentTime: currentTime ?? this.currentTime,
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}
