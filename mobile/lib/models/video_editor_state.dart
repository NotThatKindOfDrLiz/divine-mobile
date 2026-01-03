// ABOUTME: Immutable state model for video editor managing text overlays, sound, and export progress
// ABOUTME: Tracks editing state with export stages and computed properties for UI state

class EditorState {
  const EditorState({
    this.currentClipIndex = 0,
    this.currentTime = '0.00',
    this.isEditing = false,
    this.isPlaying = false,
    this.isMuted = false,
  });

  final int currentClipIndex;
  final bool isEditing;

  final String currentTime;
  final bool isPlaying;
  final bool isMuted;

  EditorState copyWith({
    bool? isEditing,
    int? currentClipIndex,
    String? currentTime,
    bool? isPlaying,
    bool? isMuted,
  }) {
    return EditorState(
      isEditing: isEditing ?? this.isEditing,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      currentTime: currentTime ?? this.currentTime,
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}
