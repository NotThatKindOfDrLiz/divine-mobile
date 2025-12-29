// ABOUTME: Mobile platform implementation of camera service using the camera package
// ABOUTME: Handles camera initialization, switching, recording, and lifecycle management on mobile devices

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import 'camera_base_service.dart';

/// Mobile implementation of [CameraService] using the camera package.
///
/// Manages camera initialization, recording, and switching between front/back cameras.
class CameraMobileService extends CameraService {
  CameraController? _controller;

  List<CameraDescription>? _cameras;

  int _currentCameraIndex = 0;

  double _minZoomLevel = 1;
  double _maxZoomLevel = 1;

  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    Log.info(
      '📷 Initializing mobile camera',
      name: 'CameraMobileService',
      category: .video,
    );

    _cameras ??= await availableCameras();

    // Find the preferred back camera.
    _currentCameraIndex = _findPreferredCamera(.back);

    await _initializeCameraController(_cameras![_currentCameraIndex]);
    _isInitialized = true;

    Log.info(
      '📷 Mobile camera initialized (${_cameras!.length} cameras available)',
      name: 'CameraMobileService',
      category: .video,
    );
  }

  @override
  Future<void> dispose() async {
    Log.info(
      '📷 Disposing mobile camera',
      name: 'CameraMobileService',
      category: .video,
    );

    _isInitialized = false;
    // Only dispose if controller was initialized
    await _controller?.dispose();
  }

  /// Finds the first camera matching the specified [direction].
  ///
  /// Returns the camera index or 0 if no matching camera is found.
  int _findPreferredCamera(CameraLensDirection direction) {
    // Get first camera with correct direction
    final index = _cameras!.indexWhere(
      (camera) => camera.lensDirection == direction,
    );

    return index != -1 ? index : 0;
  }

  /// Initializes the camera controller with the given [description].
  ///
  /// Sets up the controller with maximum resolution and retrieves zoom limits.
  Future<void> _initializeCameraController(
    CameraDescription description,
  ) async {
    _controller = CameraController(description, .max);

    await _controller!.initialize();

    _minZoomLevel = await _controller!.getMinZoomLevel();
    _maxZoomLevel = await _controller!.getMaxZoomLevel();
  }

  @override
  Future<bool> setFlashMode(FlashMode mode) async {
    if (!isInitialized) return false;
    try {
      Log.info(
        '📷 Setting flash mode to ${mode.name}',
        name: 'CameraMobileService',
        category: .video,
      );
      await _controller!.setFlashMode(mode);
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set flash mode: $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> setFocusPoint(Offset offset) async {
    if (!isInitialized) return false;
    try {
      Log.info(
        '📷 Setting focus point to (${offset.dx}, ${offset.dy})',
        name: 'CameraMobileService',
        category: .video,
      );
      await _controller!.setFocusPoint(offset);
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set focus point: $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> setExposurePoint(Offset offset) async {
    if (!isInitialized) return false;
    try {
      Log.info(
        '📷 Setting exposure point to (${offset.dx}, ${offset.dy})',
        name: 'CameraMobileService',
        category: .video,
      );
      await _controller!.setExposurePoint(offset);
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set exposure point: $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> setZoomLevel(double value) async {
    if (!isInitialized) return false;
    try {
      Log.info(
        '📷 Setting zoom level to $value',
        name: 'CameraMobileService',
        category: .video,
      );
      await _controller!.setZoomLevel(value);
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set zoom level: $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> switchCamera() async {
    if (_cameras == null || _cameras!.length <= 1) return false;

    try {
      Log.info(
        '📷 Switching camera',
        name: 'CameraMobileService',
        category: .video,
      );

      await _controller!.dispose();

      // Switch between front and back camera
      final currentDirection = _cameras![_currentCameraIndex].lensDirection;

      final CameraLensDirection targetDirection = currentDirection == .back
          ? .front
          : .back;

      final targetCameraIndex = _findPreferredCamera(targetDirection);

      if (targetCameraIndex == _currentCameraIndex) {
        // No alternative camera found, reinitialize current
        _controller = CameraController(_cameras![_currentCameraIndex], .max);
        await _controller!.initialize();

        Log.warning(
          '📷 No alternative camera found',
          name: 'CameraMobileService',
          category: .video,
        );
        return false;
      }

      _currentCameraIndex = targetCameraIndex;

      await _initializeCameraController(_cameras![_currentCameraIndex]);

      await _controller!.initialize();

      Log.info(
        '📷 Camera switched to ${targetDirection.name}',
        name: 'CameraMobileService',
        category: .video,
      );
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to switch camera: $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<void> startRecording() async {
    try {
      Log.info(
        '📷 Starting video recording',
        name: 'CameraMobileService',
        category: .video,
      );

      await _controller!.startVideoRecording();
    } catch (e) {
      Log.error(
        '📷 Failed to start recording: $e',
        name: 'CameraMobileService',
        category: .video,
      );
    }
  }

  @override
  Future<EditorVideo?> stopRecording() async {
    try {
      Log.info(
        '📷 Stopping video recording',
        name: 'CameraMobileService',
        category: .video,
      );

      final result = await _controller!.stopVideoRecording();

      Log.info(
        '📷 Video recording stopped',
        name: 'CameraMobileService',
        category: .video,
      );
      return EditorVideo.autoSource(
        file: result.path,
        byteArray: kIsWeb ? await result.readAsBytes() : null,
      );
    } catch (e) {
      Log.error(
        '📷 Failed to stop recording: $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return null;
    }
  }

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    Log.info(
      '📷 App lifecycle state changed to ${state.name}',
      name: 'CameraMobileService',
      category: .video,
    );

    switch (state) {
      case .inactive:
        if (isInitialized) await dispose();
        break;
      case .resumed:
        await _initializeCameraController(_controller!.description);
        _isInitialized = true;

        Log.info(
          '📷 Camera reinitialized after resume',
          name: 'CameraMobileService',
          category: .video,
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget buildPreviewWidget({
    required Function(ScaleStartDetails details) onScaleStart,
    required Function(ScaleUpdateDetails details) onScaleUpdate,
    required Function(TapDownDetails details, BoxConstraints constraints)
    onTapDown,
  }) {
    return CameraPreview(
      _controller!,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onScaleStart: onScaleStart,
            onScaleUpdate: onScaleUpdate,
            onTapDown: (details) => onTapDown(details, constraints),
          );
        },
      ),
    );
  }

  @override
  double get cameraAspectRatio =>
      _controller != null ? _controller!.value.aspectRatio : 1;

  @override
  double get minZoomLevel => _minZoomLevel;
  @override
  double get maxZoomLevel => _maxZoomLevel;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isFocusPointSupported =>
      _controller != null && _controller!.value.focusPointSupported;

  @override
  bool get canRecord => isInitialized && !_controller!.value.isRecordingVideo;

  @override
  bool get canSwitchCamera {
    if (_cameras == null) return false;

    final hasFront = _cameras!.any((c) => c.lensDirection == .front);
    final hasBack = _cameras!.any((c) => c.lensDirection == .back);
    return hasFront && hasBack;
  }
}
