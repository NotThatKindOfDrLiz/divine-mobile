// ABOUTME: Unit tests for VineRecordingUIState behavior
// ABOUTME: Tests state getters and properties without requiring camera

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/providers/video_recording_provider.dart';
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  group('VineRecordingUIState Tests', () {
    test('isRecording getter should match recording state', () {
      const recordingState = VideoRecordingUIState(
        recordingState: VideoRecordingState.recording,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      const idleState = VideoRecordingUIState(
        recordingState: VideoRecordingState.idle,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(recordingState.isRecording, isTrue);
      expect(idleState.isRecording, isFalse);
    });

    test('isInitialized should require camera initialization', () {
      const initializedState = VideoRecordingUIState(
        recordingState: VideoRecordingState.idle,
        isCameraInitialized: true,
        canRecord: true,
        aspectRatio: AspectRatio.square,
      );

      const uninitializedState = VideoRecordingUIState(
        recordingState: VideoRecordingState.idle,
        isCameraInitialized: false,
        canRecord: false,
        aspectRatio: AspectRatio.square,
      );

      expect(initializedState.isInitialized, isTrue);
      expect(uninitializedState.isInitialized, isFalse);
    });

    test('isInitialized should be false during error state', () {
      const errorState = VideoRecordingUIState(
        recordingState: VideoRecordingState.error,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(errorState.isInitialized, isFalse);
    });

    test('isInitialized should be false during processing state', () {
      const processingState = VideoRecordingUIState(
        recordingState: VideoRecordingState.processing,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(processingState.isInitialized, isFalse);
    });

    test('isError getter should detect error state', () {
      const errorState = VideoRecordingUIState(
        recordingState: VideoRecordingState.error,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      const idleState = VideoRecordingUIState(
        recordingState: VideoRecordingState.idle,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(errorState.isError, isTrue);
      expect(idleState.isError, isFalse);
    });

    test('errorMessage should be non-null only in error state', () {
      const errorState = VideoRecordingUIState(
        recordingState: VideoRecordingState.error,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      const idleState = VideoRecordingUIState(
        recordingState: VideoRecordingState.idle,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(errorState.errorMessage, isNotNull);
      expect(idleState.errorMessage, isNull);
    });

    test('canRecord should reflect ability to start recording', () {
      const canRecordState = VideoRecordingUIState(
        recordingState: VideoRecordingState.idle,
        canRecord: true,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      const cannotRecordState = VideoRecordingUIState(
        recordingState: VideoRecordingState.recording,
        canRecord: false,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(canRecordState.canRecord, isTrue);
      expect(cannotRecordState.canRecord, isFalse);
    });

    test('zoomLevel should be customizable', () {
      const defaultZoom = VideoRecordingUIState(
        aspectRatio: AspectRatio.square,
      );

      const customZoom = VideoRecordingUIState(
        zoomLevel: 2.5,
        aspectRatio: AspectRatio.square,
      );

      expect(defaultZoom.zoomLevel, equals(1.0));
      expect(customZoom.zoomLevel, equals(2.5));
    });

    test('focusPoint should be settable', () {
      const defaultFocus = VideoRecordingUIState(
        aspectRatio: AspectRatio.square,
      );

      const customFocus = VideoRecordingUIState(
        focusPoint: Offset(0.5, 0.5),
        aspectRatio: AspectRatio.square,
      );

      expect(defaultFocus.focusPoint, equals(Offset.zero));
      expect(customFocus.focusPoint, equals(const Offset(0.5, 0.5)));
    });

    test('aspectRatio should be customizable', () {
      const squareState = VideoRecordingUIState(
        aspectRatio: AspectRatio.square,
      );

      const verticalState = VideoRecordingUIState(
        aspectRatio: AspectRatio.vertical,
      );

      expect(squareState.aspectRatio, equals(AspectRatio.square));
      expect(verticalState.aspectRatio, equals(AspectRatio.vertical));
    });

    test('flashMode should be customizable', () {
      const autoFlash = VideoRecordingUIState(
        flashMode: FlashMode.auto,
        aspectRatio: AspectRatio.square,
      );

      const torchFlash = VideoRecordingUIState(
        flashMode: FlashMode.torch,
        aspectRatio: AspectRatio.square,
      );

      const offFlash = VideoRecordingUIState(
        flashMode: FlashMode.off,
        aspectRatio: AspectRatio.square,
      );

      expect(autoFlash.flashMode, equals(FlashMode.auto));
      expect(torchFlash.flashMode, equals(FlashMode.torch));
      expect(offFlash.flashMode, equals(FlashMode.off));
    });

    test('timerDuration should be customizable', () {
      const offTimer = VideoRecordingUIState(
        timerDuration: TimerDuration.off,
        aspectRatio: AspectRatio.square,
      );

      const threeSecTimer = VideoRecordingUIState(
        timerDuration: TimerDuration.three,
        aspectRatio: AspectRatio.square,
      );

      const tenSecTimer = VideoRecordingUIState(
        timerDuration: TimerDuration.ten,
        aspectRatio: AspectRatio.square,
      );

      expect(offTimer.timerDuration, equals(TimerDuration.off));
      expect(threeSecTimer.timerDuration, equals(TimerDuration.three));
      expect(tenSecTimer.timerDuration, equals(TimerDuration.ten));
    });

    test('countdownValue should be settable', () {
      const noCountdown = VideoRecordingUIState(
        countdownValue: 0,
        aspectRatio: AspectRatio.square,
      );

      const countingDown = VideoRecordingUIState(
        countdownValue: 3,
        aspectRatio: AspectRatio.square,
      );

      expect(noCountdown.countdownValue, equals(0));
      expect(countingDown.countdownValue, equals(3));
    });

    test('copyWith should update specific fields', () {
      const initialState = VideoRecordingUIState(
        recordingState: VideoRecordingState.idle,
        zoomLevel: 1.0,
        canRecord: true,
        aspectRatio: AspectRatio.square,
      );

      final updatedState = initialState.copyWith(
        recordingState: VideoRecordingState.recording,
        zoomLevel: 2.0,
      );

      expect(updatedState.recordingState, VideoRecordingState.recording);
      expect(updatedState.zoomLevel, 2.0);
      expect(updatedState.canRecord, true); // Preserved
      expect(updatedState.aspectRatio, AspectRatio.square); // Preserved
    });

    test('cameraSwitchCount should increment on camera switch', () {
      const initialState = VideoRecordingUIState(
        cameraSwitchCount: 0,
        aspectRatio: AspectRatio.square,
      );

      const switchedState = VideoRecordingUIState(
        cameraSwitchCount: 1,
        aspectRatio: AspectRatio.square,
      );

      expect(initialState.cameraSwitchCount, equals(0));
      expect(switchedState.cameraSwitchCount, equals(1));
    });

    test('canSwitchCamera should be configurable', () {
      const canSwitch = VideoRecordingUIState(
        canSwitchCamera: true,
        aspectRatio: AspectRatio.square,
      );

      const cannotSwitch = VideoRecordingUIState(
        canSwitchCamera: false,
        aspectRatio: AspectRatio.square,
      );

      expect(canSwitch.canSwitchCamera, isTrue);
      expect(cannotSwitch.canSwitchCamera, isFalse);
    });

    test('default state should have sensible values', () {
      const state = VideoRecordingUIState();

      expect(state.recordingState, VideoRecordingState.idle);
      expect(state.zoomLevel, 1.0);
      expect(state.cameraSensorAspectRatio, 1.0);
      expect(state.focusPoint, Offset.zero);
      expect(state.canRecord, false);
      expect(state.isCameraInitialized, false);
      expect(state.canSwitchCamera, false);
      expect(state.cameraSwitchCount, 0);
      expect(state.countdownValue, 0);
      expect(state.aspectRatio, AspectRatio.vertical);
      expect(state.flashMode, FlashMode.auto);
      expect(state.timerDuration, TimerDuration.off);
    });
  });
}
