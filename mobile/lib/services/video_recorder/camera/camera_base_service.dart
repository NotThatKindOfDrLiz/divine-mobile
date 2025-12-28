// ABOUTME: Base service for camera operations across different platforms
// ABOUTME: Provides unified API for camera control, recording, and preview

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Base service for camera operations across different platforms.
/// Provides a unified API for camera control, recording, and preview.
abstract class CameraBaseService {
  /// Initializes the camera and prepares it for use.
  Future<void> initialize();

  /// Releases camera resources and cleans up.
  Future<void> dispose();

  /// Sets the flash mode. Returns true if successful.
  Future<bool> setFlashMode(FlashMode mode);

  /// Sets the focus point in normalized coordinates (0.0-1.0).
  Future<bool> setFocusPoint(Offset offset);

  /// Sets the exposure point in normalized coordinates (0.0-1.0).
  Future<bool> setExposurePoint(Offset offset);

  /// Sets the zoom level. Returns true if successful.
  Future<bool> setZoomLevel(double value);

  /// Switches between front and back camera. Returns true if successful.
  Future<bool> switchCamera();

  /// Starts video recording.
  Future<void> startRecording();

  /// Stops video recording.
  Future<EditorVideo?> stopRecording();

  /// Handles app lifecycle changes (pause, resume, etc.).
  Future<void> handleAppLifecycleState(AppLifecycleState state);

  /// The aspect ratio of the camera sensor.
  double get cameraAspectRatio;

  /// Minimum zoom level supported by the camera.
  double get minZoomLevel;

  /// Maximum zoom level supported by the camera.
  double get maxZoomLevel;

  /// Whether the camera is initialized and ready to use.
  bool get isInitialized;

  /// Whether the camera supports manual focus point selection.
  bool get isFocusPointSupported;

  /// Whether the camera is ready to record (initialized and not recording).
  bool get canRecord;

  /// Whether the device has multiple cameras to switch between.
  bool get canSwitchCamera;

  /// Builds the camera preview widget with gesture handlers.
  Widget buildPreviewWidget({
    required Function(ScaleStartDetails details) onScaleStart,
    required Function(ScaleUpdateDetails details) onScaleUpdate,
    required Function(TapDownDetails details, BoxConstraints constraints)
    onTapDown,
  });
}
