// ABOUTME: Unit tests for EditorProvider (Riverpod) validating state mutations and provider behavior
// ABOUTME: Tests all EditorNotifier methods and state transitions using ProviderContainer

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/editor_state.dart';
import 'package:openvine/providers/editor_provider.dart';

void main() {
  group('EditorProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should provide initial state', () {
      final state = container.read(editorProvider);

      expect(state.selectedTextId, isNull);
      expect(state.selectedSoundId, isNull);
      expect(state.isProcessing, isFalse);
      expect(state.exportStage, isNull);
      expect(state.exportProgress, 0.0);
      expect(state.errorMessage, isNull);
    });

    group('setSound', () {
      test('should set sound id', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setSound('sound1');

        final state = container.read(editorProvider);
        expect(state.selectedSoundId, 'sound1');
      });

      test('should clear sound when null provided', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setSound('sound1');
        notifier.setSound(null);

        final state = container.read(editorProvider);
        expect(state.selectedSoundId, isNull);
      });

      test('should change sound selection', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setSound('sound1');
        notifier.setSound('sound2');

        final state = container.read(editorProvider);
        expect(state.selectedSoundId, 'sound2');
      });
    });

    group('setExportStage', () {
      test('should set export stage and progress', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setExportStage(ExportStage.concatenating, 0.25);

        final state = container.read(editorProvider);
        expect(state.exportStage, ExportStage.concatenating);
        expect(state.exportProgress, 0.25);
        expect(state.isProcessing, isTrue);
      });

      test('should update stage and progress', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setExportStage(ExportStage.concatenating, 0.25);
        notifier.setExportStage(ExportStage.mixingAudio, 0.75);

        final state = container.read(editorProvider);
        expect(state.exportStage, ExportStage.mixingAudio);
        expect(state.exportProgress, 0.75);
        expect(state.isProcessing, isTrue);
      });

      test('should set isProcessing true during export', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setExportStage(ExportStage.applyingTextOverlay, 0.5);

        final state = container.read(editorProvider);
        expect(state.isProcessing, isTrue);
      });

      test('should clear error when setting export stage', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setError('Previous error');
        notifier.setExportStage(ExportStage.concatenating, 0.0);

        final state = container.read(editorProvider);
        expect(state.errorMessage, isNull);
      });

      test('should complete export when stage is complete', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setExportStage(ExportStage.complete, 1.0);

        final state = container.read(editorProvider);
        expect(state.exportStage, ExportStage.complete);
        expect(state.exportProgress, 1.0);
        expect(state.isProcessing, isFalse);
      });

      test('should stop processing when stage is error', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setExportStage(ExportStage.error, 0.5);

        final state = container.read(editorProvider);
        expect(state.exportStage, ExportStage.error);
        expect(state.isProcessing, isFalse);
      });
    });

    group('setError', () {
      test('should set error message', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setError('Export failed');

        final state = container.read(editorProvider);
        expect(state.errorMessage, 'Export failed');
        expect(state.exportStage, ExportStage.error);
        expect(state.isProcessing, isFalse);
      });

      test('should clear error when null provided', () {
        final notifier = container.read(editorProvider.notifier);

        notifier.setError('Error');
        notifier.setError(null);

        final state = container.read(editorProvider);
        expect(state.errorMessage, isNull);
      });
    });
  });
}
