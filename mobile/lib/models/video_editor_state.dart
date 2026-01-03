// ABOUTME: Immutable state model for video editor managing text overlays, sound, and export progress
// ABOUTME: Tracks editing state with export stages and computed properties for UI state

class EditorState {
  const EditorState({
    this.currentClipIndex = 0,
    this.currentTime = '0.00',
    this.isEditing = false,
    this.isPlaying = false,
    this.isMuted = false,
    this.isProcessing = false,
  });

  final int currentClipIndex;
  final String currentTime;

  final bool isEditing;
  final bool isPlaying;
  final bool isMuted;
  final bool isProcessing;

  EditorState copyWith({
    bool? isEditing,
    int? currentClipIndex,
    String? currentTime,
    bool? isPlaying,
    bool? isMuted,
    bool? isProcessing,
  }) {
    return EditorState(
      isEditing: isEditing ?? this.isEditing,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      currentTime: currentTime ?? this.currentTime,
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}
