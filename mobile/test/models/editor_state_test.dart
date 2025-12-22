// ABOUTME: Unit tests for EditorState model validating state management and export tracking
// ABOUTME: Tests immutability, copyWith, computed properties, and state transitions

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/editor_state.dart';

void main() {
  group('EditorState', () {
    test('should create with default values', () {
      final state = EditorState();

      expect(state.selectedTextId, isNull);
      expect(state.selectedSoundId, isNull);
      expect(state.isProcessing, isFalse);
      expect(state.exportStage, isNull);
      expect(state.exportProgress, 0.0);
      expect(state.errorMessage, isNull);
    });

    group('copyWith', () {
      test('should copy with new selected text id', () {
        final state = EditorState();
        final newState = state.copyWith(selectedTextId: 'text1');

        expect(newState.selectedTextId, 'text1');
        expect(state.selectedTextId, isNull);
      });

      test('should copy with null selected text id', () {
        final state = EditorState(selectedTextId: 'text1');
        final newState = state.copyWith(selectedTextId: null);

        expect(newState.selectedTextId, isNull);
      });

      test('should copy with new sound id', () {
        final state = EditorState();
        final newState = state.copyWith(selectedSoundId: 'sound1');

        expect(newState.selectedSoundId, 'sound1');
        expect(state.selectedSoundId, isNull);
      });

      test('should copy with processing state', () {
        final state = EditorState();
        final newState = state.copyWith(isProcessing: true);

        expect(newState.isProcessing, isTrue);
        expect(state.isProcessing, isFalse);
      });

      test('should copy with export stage', () {
        final state = EditorState();
        final newState = state.copyWith(exportStage: ExportStage.mixingAudio);

        expect(newState.exportStage, ExportStage.mixingAudio);
        expect(state.exportStage, isNull);
      });

      test('should copy with export progress', () {
        final state = EditorState();
        final newState = state.copyWith(exportProgress: 0.75);

        expect(newState.exportProgress, 0.75);
        expect(state.exportProgress, 0.0);
      });

      test('should copy with error message', () {
        final state = EditorState();
        final newState = state.copyWith(errorMessage: 'Error occurred');

        expect(newState.errorMessage, 'Error occurred');
        expect(state.errorMessage, isNull);
      });
    });

    group('computed properties', () {
      test('hasSound should return false when no sound selected', () {
        final state = EditorState();
        expect(state.hasSound, isFalse);
      });

      test('hasSound should return true when sound selected', () {
        final state = EditorState(selectedSoundId: 'sound1');
        expect(state.hasSound, isTrue);
      });

      test('canExport should return true when not processing', () {
        final state = EditorState();
        expect(state.canExport, isTrue);
      });

      test('canExport should return false when processing', () {
        final state = EditorState(isProcessing: true);
        expect(state.canExport, isFalse);
      });

      test('canExport should return false during export', () {
        final state = EditorState(
          isProcessing: true,
          exportStage: ExportStage.concatenating,
        );
        expect(state.canExport, isFalse);
      });
    });

    group('ExportStage enum', () {
      test('should have all required stages', () {
        expect(ExportStage.values, contains(ExportStage.concatenating));
        expect(ExportStage.values, contains(ExportStage.applyingTextOverlay));
        expect(ExportStage.values, contains(ExportStage.mixingAudio));
        expect(ExportStage.values, contains(ExportStage.generatingThumbnail));
        expect(ExportStage.values, contains(ExportStage.complete));
        expect(ExportStage.values, contains(ExportStage.error));
      });

      test('should have exactly 6 stages', () {
        expect(ExportStage.values, hasLength(6));
      });
    });
  });
}
