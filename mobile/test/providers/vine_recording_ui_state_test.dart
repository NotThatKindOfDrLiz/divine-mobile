// ABOUTME: Unit tests for VineRecordingUIState behavior
// ABOUTME: Tests state getters and properties without requiring camera

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  group('VineRecordingUIState Tests', () {
    test('isRecording getter should match recording state', () {
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

      expect(recordingState.isRecording, isTrue);
      expect(idleState.isRecording, isFalse);
    });

    test('isInitialized should require camera initialization', () {
      const initializedState = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        isCameraInitialized: true,
        canRecord: true,
        aspectRatio: AspectRatio.square,
      );

      const uninitializedState = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        isCameraInitialized: false,
        canRecord: false,
        aspectRatio: AspectRatio.square,
      );

      expect(initializedState.isInitialized, isTrue);
      expect(uninitializedState.isInitialized, isFalse);
    });

    test('isInitialized should be false during error state', () {
      const errorState = VineRecordingUIState(
        recordingState: VineRecordingState.error,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(errorState.isInitialized, isFalse);
    });

    test('isInitialized should be false during processing state', () {
      const processingState = VineRecordingUIState(
        recordingState: VineRecordingState.processing,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(processingState.isInitialized, isFalse);
    });

    test('isError getter should detect error state', () {
      const errorState = VineRecordingUIState(
        recordingState: VineRecordingState.error,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      const idleState = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(errorState.isError, isTrue);
      expect(idleState.isError, isFalse);
    });

    test('errorMessage should be non-null only in error state', () {
      const errorState = VineRecordingUIState(
        recordingState: VineRecordingState.error,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      const idleState = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(errorState.errorMessage, isNotNull);
      expect(idleState.errorMessage, isNull);
    });

    test('canRecord should reflect ability to start recording', () {
      const canRecordState = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        canRecord: true,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      const cannotRecordState = VineRecordingUIState(
        recordingState: VineRecordingState.recording,
        canRecord: false,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(canRecordState.canRecord, isTrue);
      expect(cannotRecordState.canRecord, isFalse);
    });

    test('zoomLevel should be customizable', () {
      const defaultZoom = VineRecordingUIState(aspectRatio: AspectRatio.square);

      const customZoom = VineRecordingUIState(
        zoomLevel: 2.5,
        aspectRatio: AspectRatio.square,
      );

      expect(defaultZoom.zoomLevel, equals(1.0));
      expect(customZoom.zoomLevel, equals(2.5));
    });

    test('focusPoint should be settable', () {
      const defaultFocus = VineRecordingUIState(
        aspectRatio: AspectRatio.square,
      );

      const customFocus = VineRecordingUIState(
        focusPoint: Offset(0.5, 0.5),
        aspectRatio: AspectRatio.square,
      );

      expect(defaultFocus.focusPoint, equals(Offset.zero));
      expect(customFocus.focusPoint, equals(const Offset(0.5, 0.5)));
    });

    test('aspectRatio should be customizable', () {
      const squareState = VineRecordingUIState(aspectRatio: AspectRatio.square);

      const verticalState = VineRecordingUIState(
        aspectRatio: AspectRatio.vertical,
      );

      expect(squareState.aspectRatio, equals(AspectRatio.square));
      expect(verticalState.aspectRatio, equals(AspectRatio.vertical));
    });

    test('flashMode should be customizable', () {
      const autoFlash = VineRecordingUIState(
        flashMode: FlashMode.auto,
        aspectRatio: AspectRatio.square,
      );

      const torchFlash = VineRecordingUIState(
        flashMode: FlashMode.torch,
        aspectRatio: AspectRatio.square,
      );

      const offFlash = VineRecordingUIState(
        flashMode: FlashMode.off,
        aspectRatio: AspectRatio.square,
      );

      expect(autoFlash.flashMode, equals(FlashMode.auto));
      expect(torchFlash.flashMode, equals(FlashMode.torch));
      expect(offFlash.flashMode, equals(FlashMode.off));
    });

    test('timerDuration should be customizable', () {
      const offTimer = VineRecordingUIState(
        timerDuration: TimerDuration.off,
        aspectRatio: AspectRatio.square,
      );

      const threeSecTimer = VineRecordingUIState(
        timerDuration: TimerDuration.three,
        aspectRatio: AspectRatio.square,
      );

      const tenSecTimer = VineRecordingUIState(
        timerDuration: TimerDuration.ten,
        aspectRatio: AspectRatio.square,
      );

      expect(offTimer.timerDuration, equals(TimerDuration.off));
      expect(threeSecTimer.timerDuration, equals(TimerDuration.three));
      expect(tenSecTimer.timerDuration, equals(TimerDuration.ten));
    });

    test('countdownValue should be settable', () {
      const noCountdown = VineRecordingUIState(
        countdownValue: 0,
        aspectRatio: AspectRatio.square,
      );

      const countingDown = VineRecordingUIState(
        countdownValue: 3,
        aspectRatio: AspectRatio.square,
      );

      expect(noCountdown.countdownValue, equals(0));
      expect(countingDown.countdownValue, equals(3));
    });

    test('copyWith should update specific fields', () {
      const initialState = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        zoomLevel: 1.0,
        canRecord: true,
        aspectRatio: AspectRatio.square,
      );

      final updatedState = initialState.copyWith(
        recordingState: VineRecordingState.recording,
        zoomLevel: 2.0,
      );

      expect(updatedState.recordingState, VineRecordingState.recording);
      expect(updatedState.zoomLevel, 2.0);
      expect(updatedState.canRecord, true); // Preserved
      expect(updatedState.aspectRatio, AspectRatio.square); // Preserved
    });

    test('cameraSwitchCount should increment on camera switch', () {
      const initialState = VineRecordingUIState(
        cameraSwitchCount: 0,
        aspectRatio: AspectRatio.square,
      );

      const switchedState = VineRecordingUIState(
        cameraSwitchCount: 1,
        aspectRatio: AspectRatio.square,
      );

      expect(initialState.cameraSwitchCount, equals(0));
      expect(switchedState.cameraSwitchCount, equals(1));
    });

    test('canSwitchCamera should be configurable', () {
      const canSwitch = VineRecordingUIState(
        canSwitchCamera: true,
        aspectRatio: AspectRatio.square,
      );

      const cannotSwitch = VineRecordingUIState(
        canSwitchCamera: false,
        aspectRatio: AspectRatio.square,
      );

      expect(canSwitch.canSwitchCamera, isTrue);
      expect(cannotSwitch.canSwitchCamera, isFalse);
    });

    test('default state should have sensible values', () {
      const state = VineRecordingUIState();

      expect(state.recordingState, VineRecordingState.idle);
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
