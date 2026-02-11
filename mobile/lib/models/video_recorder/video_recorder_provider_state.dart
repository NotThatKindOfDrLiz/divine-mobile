// ABOUTME: UI state model for video recorder capturing camera and recording state
// ABOUTME: Manages zoom, focus, flash, timer, aspect ratio, and recording status

import 'dart:ui';

import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:models/models.dart' as model show AspectRatio;

/// State class capturing all UI state for video recording.
class VideoRecorderProviderState {
  /// Creates a video recorder UI state.
  const VideoRecorderProviderState({
    this.recordingState = .idle,
    this.zoomLevel = 1.0,
    this.cameraSensorAspectRatio = 1.0,
    this.focusPoint = .zero,
    this.canRecord = false,
    this.isCameraInitialized = false,
    this.canSwitchCamera = true,
    this.hasFlash = true,
    this.isAudioEnabled = true,
    this.isGhostEnabled = false,
    this.countdownValue = 0,
    this.cameraRebuildCount = 0,
    this.aspectRatio = .vertical,
    this.flashMode = .auto,
    this.timerDuration = .off,
    this.ghostFramePath,
    this.initializationErrorMessage,
  });

  /// Camera focus point in normalized coordinates (0.0-1.0).
  final Offset focusPoint;

  // Booleans
  /// Whether recording is allowed.
  final bool canRecord;

  /// Whether the camera is initialized.
  final bool isCameraInitialized;

  /// Whether camera switching is available.
  final bool canSwitchCamera;

  /// Whether the camera has flash capability.
  final bool hasFlash;

  /// Whether audio recording is enabled.
  final bool isAudioEnabled;

  /// Whether ghost mode (onion-skin overlay) is enabled.
  final bool isGhostEnabled;

  // Double values
  /// Current zoom level.
  final double zoomLevel;

  /// Aspect ratio of the camera sensor.
  final double cameraSensorAspectRatio;

  // Integers
  /// Current countdown value before recording starts.
  final int countdownValue;

  /// Count of camera rebuilds for forcing UI updates.
  final int cameraRebuildCount;

  // Custom types
  /// Current recording aspect ratio.
  final model.AspectRatio aspectRatio;

  /// Current flash mode.
  final DivineFlashMode flashMode;

  /// Timer duration before recording starts.
  final TimerDuration timerDuration;

  /// Current recording state.
  final VideoRecorderState recordingState;

  /// Path to the last frame image of the most recent clip, used for ghost overlay.
  final String? ghostFramePath;

  /// Custom error message when camera initialization fails.
  final String? initializationErrorMessage;

  // Convenience getters used by UI
  /// Whether currently recording.
  bool get isRecording => recordingState == .recording;

  /// Whether camera is initialized and not in error state.
  bool get isInitialized => isCameraInitialized && recordingState != .error;

  /// Whether in error state.
  bool get isError => recordingState == .error;

  /// Whether the ghost overlay should be displayed.
  bool get hasGhostFrame => isGhostEnabled && ghostFramePath != null;

  /// Error message if in error state or initialization failed.
  String? get errorMessage =>
      initializationErrorMessage ??
      (isError ? 'Recording error occurred' : null);

  /// Creates a copy of this state with updated values.
  VideoRecorderProviderState copyWith({
    VideoRecorderState? recordingState,
    double? zoomLevel,
    double? cameraSensorAspectRatio,
    Offset? focusPoint,
    bool? canRecord,
    bool? hasSegments,
    bool? isCameraInitialized,
    bool? canSwitchCamera,
    bool? hasFlash,
    bool? isAudioEnabled,
    bool? isGhostEnabled,
    int? countdownValue,
    int? cameraRebuildCount,
    model.AspectRatio? aspectRatio,
    DivineFlashMode? flashMode,
    TimerDuration? timerDuration,
    String? ghostFramePath,
    String? initializationErrorMessage,
    bool clearGhostFrame = false,
  }) {
    return VideoRecorderProviderState(
      recordingState: recordingState ?? this.recordingState,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      cameraSensorAspectRatio:
          cameraSensorAspectRatio ?? this.cameraSensorAspectRatio,
      focusPoint: focusPoint ?? this.focusPoint,
      canRecord: canRecord ?? this.canRecord,
      isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
      canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera,
      hasFlash: hasFlash ?? this.hasFlash,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isGhostEnabled: isGhostEnabled ?? this.isGhostEnabled,
      countdownValue: countdownValue ?? this.countdownValue,
      cameraRebuildCount: cameraRebuildCount ?? this.cameraRebuildCount,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      flashMode: flashMode ?? this.flashMode,
      timerDuration: timerDuration ?? this.timerDuration,
      ghostFramePath: clearGhostFrame
          ? null
          : (ghostFramePath ?? this.ghostFramePath),
      initializationErrorMessage:
          initializationErrorMessage ?? this.initializationErrorMessage,
    );
  }
}
