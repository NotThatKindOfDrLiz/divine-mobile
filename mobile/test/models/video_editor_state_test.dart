// ABOUTME: Unit tests for EditorState model validating state management and export tracking
// ABOUTME: Tests immutability, copyWith, computed properties, and state transitions

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/selected_audio_track.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';

void main() {
  group('EditorState', () {
    test('creates instance with default values', () {
      final state = VideoEditorProviderState();

      expect(state.currentClipIndex, 0);
      expect(state.currentPosition, Duration.zero);
      expect(state.isEditing, false);
      expect(state.isReordering, false);
      expect(state.isOverDeleteZone, false);
      expect(state.isPlaying, false);
      expect(state.isMuted, false);
      expect(state.isProcessing, false);
      expect(state.originalAudioVolume, 0.2);
      expect(state.selectedAudioTrack, isNull);
    });

    test('copyWith updates specified fields only', () {
      final initial = VideoEditorProviderState(
        currentClipIndex: 1,
        isPlaying: true,
      );

      final updated = initial.copyWith(isEditing: true, isMuted: true);

      expect(updated.currentClipIndex, 1);
      expect(updated.isPlaying, true);
      expect(updated.isEditing, true);
      expect(updated.isMuted, true);
      expect(updated.isReordering, false);
    });

    test('copyWith preserves all fields when none specified', () {
      final state = VideoEditorProviderState(
        currentClipIndex: 2,
        currentPosition: const Duration(seconds: 5),
        isEditing: true,
        isReordering: true,
        isOverDeleteZone: true,
        isPlaying: true,
        isMuted: true,
        isProcessing: true,
      );

      final copied = state.copyWith();

      expect(copied.currentClipIndex, state.currentClipIndex);
      expect(copied.currentPosition, state.currentPosition);
      expect(copied.isEditing, state.isEditing);
      expect(copied.isReordering, state.isReordering);
      expect(copied.isOverDeleteZone, state.isOverDeleteZone);
      expect(copied.isPlaying, state.isPlaying);
      expect(copied.isMuted, state.isMuted);
      expect(copied.isProcessing, state.isProcessing);
    });

    test('copyWith supports local uploaded audio state', () {
      const track = SelectedAudioTrack(
        id: 'track-1',
        localFilePath: '/documents/audio.m4a',
        displayTitle: 'audio.m4a',
        duration: Duration(seconds: 3),
      );

      final state = VideoEditorProviderState().copyWith(
        selectedAudioTrack: track,
        originalAudioVolume: 0.4,
      );

      expect(state.selectedAudioTrack, equals(track));
      expect(state.originalAudioVolume, 0.4);

      final cleared = state.copyWith(clearSelectedAudioTrack: true);
      expect(cleared.selectedAudioTrack, isNull);
      expect(cleared.originalAudioVolume, 0.4);
    });
  });
}
