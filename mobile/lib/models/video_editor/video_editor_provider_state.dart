// ABOUTME: Immutable state model for video editor managing text overlays, sound, and export progress
// ABOUTME: Tracks editing state with export stages and computed properties for UI state

import 'package:flutter/widgets.dart';

/// Immutable state model for the video editor.
///
/// Manages the complete editing state including:
/// - Playback position and clip navigation
/// - UI interaction states (editing, reordering, playing)
/// - Audio settings
/// - Processing status
class VideoEditorProviderState {
  VideoEditorProviderState({
    this.currentClipIndex = 0,
    this.currentPosition = .zero,
    this.splitPosition = .zero,
    this.isEditing = false,
    this.isReordering = false,
    this.isOverDeleteZone = false,
    this.isPlaying = false,
    this.isMuted = false,
    this.isProcessing = false,
    GlobalKey? deleteButtonKey,
  }) : deleteButtonKey = deleteButtonKey ?? GlobalKey();

  /// Index of the currently active/selected clip (0-based).
  final int currentClipIndex;

  /// Current playback position within the video timeline.
  final Duration currentPosition;

  /// Position where a clip split operation will occur.
  final Duration splitPosition;

  /// Whether the editor is in editing mode (e.g., trimming, adjusting).
  final bool isEditing;

  /// Whether clips are being reordered by drag-and-drop.
  final bool isReordering;

  /// Whether a dragged clip is over the delete zone during reordering.
  final bool isOverDeleteZone;

  /// Whether video playback is currently active.
  final bool isPlaying;

  /// Whether audio is muted during playback.
  final bool isMuted;

  /// Whether a long-running operation (e.g., export, processing) is in progress.
  final bool isProcessing;

  /// GlobalKey for the delete button to enable hit testing.
  final GlobalKey deleteButtonKey;

  /// Creates a copy of this state with updated fields.
  ///
  /// All parameters are optional. Only provided fields will be updated,
  /// others retain their current values.
  VideoEditorProviderState copyWith({
    bool? isEditing,
    bool? isReordering,
    bool? isOverDeleteZone,
    int? currentClipIndex,
    Duration? currentPosition,
    Duration? splitPosition,
    bool? isPlaying,
    bool? isMuted,
    bool? isProcessing,
  }) {
    return VideoEditorProviderState(
      isEditing: isEditing ?? this.isEditing,
      isReordering: isReordering ?? this.isReordering,
      isOverDeleteZone: isOverDeleteZone ?? this.isOverDeleteZone,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      currentPosition: currentPosition ?? this.currentPosition,
      splitPosition: splitPosition ?? this.splitPosition,
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      isProcessing: isProcessing ?? this.isProcessing,
      deleteButtonKey: deleteButtonKey,
    );
  }
}
