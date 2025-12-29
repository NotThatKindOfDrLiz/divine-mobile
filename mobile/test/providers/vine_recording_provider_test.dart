// ABOUTME: TDD test for VineRecordingUIState convenience getters used by universal_camera_screen_pure.dart
// ABOUTME: Tests isRecording, isInitialized, isError, and errorMessage getters

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/services/vine_recording_controller.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('VineRecordingUIState Convenience Getters (TDD)', () {
    group('GREEN Phase: Tests for working getters', () {
      test('VineRecordingUIState isRecording should work correctly', () {
        const recordingState = VineRecordingUIState(
          recordingState: VineRecordingState.recording,
          isCameraInitialized: true,
          aspectRatio: AspectRatio.square,
        );

        const idleState = VineRecordingUIState(
          recordingState: VineRecordingState.idle,
          isCameraInitialized: true,
          aspectRatio: AspectRatio.square,
        );

        expect(recordingState.isRecording, true);
        expect(idleState.isRecording, false);
      });

      test('VineRecordingUIState isInitialized should work correctly', () {
        const idleState = VineRecordingUIState(
          recordingState: VineRecordingState.idle,
          isCameraInitialized: true,
          canRecord: true,
          aspectRatio: AspectRatio.square,
        );

        const errorState = VineRecordingUIState(
          recordingState: VineRecordingState.error,
          isCameraInitialized: true,
          canRecord: false,
          aspectRatio: AspectRatio.square,
        );

        const processingState = VineRecordingUIState(
          recordingState: VineRecordingState.processing,
          isCameraInitialized: true,
          canRecord: false,
          aspectRatio: AspectRatio.square,
        );

        const notInitializedState = VineRecordingUIState(
          recordingState: VineRecordingState.idle,
          isCameraInitialized: false,
          canRecord: false,
          aspectRatio: AspectRatio.square,
        );

        expect(idleState.isInitialized, true);
        expect(errorState.isInitialized, false);
        expect(processingState.isInitialized, false);
        expect(notInitializedState.isInitialized, false);
      });

      test('VineRecordingUIState isError should work correctly', () {
        const errorState = VineRecordingUIState(
          recordingState: VineRecordingState.error,
          isCameraInitialized: true,
          canRecord: false,
          aspectRatio: AspectRatio.square,
        );

        const idleState = VineRecordingUIState(
          recordingState: VineRecordingState.idle,
          isCameraInitialized: true,
          canRecord: true,
          aspectRatio: AspectRatio.square,
        );

        expect(errorState.isError, true);
        expect(idleState.isError, false);
      });

      test('VineRecordingUIState errorMessage should work correctly', () {
        const errorState = VineRecordingUIState(
          recordingState: VineRecordingState.error,
          isCameraInitialized: true,
          canRecord: false,
          aspectRatio: AspectRatio.square,
        );

        const idleState = VineRecordingUIState(
          recordingState: VineRecordingState.idle,
          isCameraInitialized: true,
          canRecord: true,
          aspectRatio: AspectRatio.square,
        );

        expect(errorState.errorMessage, isA<String>());
        expect(errorState.errorMessage, isNotNull);
        expect(idleState.errorMessage, null);
      });

      test('VineRecordingUIState copyWith preserves values correctly', () {
        const initialState = VineRecordingUIState(
          recordingState: VineRecordingState.idle,
          zoomLevel: 1.5,
          isCameraInitialized: true,
          aspectRatio: AspectRatio.square,
        );

        final updatedState = initialState.copyWith(
          recordingState: VineRecordingState.recording,
        );

        expect(updatedState.recordingState, VineRecordingState.recording);
        expect(updatedState.zoomLevel, 1.5); // Preserved
        expect(updatedState.isCameraInitialized, true); // Preserved
        expect(updatedState.aspectRatio, AspectRatio.square); // Preserved
      });

      test('VineRecordingUIState default values are correct', () {
        const state = VineRecordingUIState();

        expect(state.recordingState, VineRecordingState.idle);
        expect(state.zoomLevel, 1.0);
        expect(state.cameraSensorAspectRatio, 1.0);
        expect(state.canRecord, false);
        expect(state.isCameraInitialized, false);
        expect(state.canSwitchCamera, false);
        expect(state.cameraSwitchCount, 0);
        expect(state.countdownValue, 0);
        expect(state.aspectRatio, AspectRatio.vertical);
      });
    });
  });

  group('RecordingResult return type (TDD)', () {
    test('RecordingResult should have correct fields', () {
      final result = RecordingResult(
        video: EditorVideo.file('/path/to/video.mp4'),
        aspectRatio: AspectRatio.square,
        duration: const Duration(seconds: 5),
        draftId: 'test_draft_123',
        nativeProof: null,
      );

      expect(result.video, isNotNull);
      expect(result.aspectRatio, AspectRatio.square);
      expect(result.duration, const Duration(seconds: 5));
      expect(result.draftId, 'test_draft_123');
      expect(result.nativeProof, isNull);
    });
  });
}
