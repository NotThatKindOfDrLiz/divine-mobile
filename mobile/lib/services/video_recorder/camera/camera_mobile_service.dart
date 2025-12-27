import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'camera_base_service.dart';

class CameraMobileService extends CameraBaseService {
  late CameraController _controller;

  late final List<CameraDescription> _cameras;
  int _currentCameraIndex = 0;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    _cameras = await availableCameras();

    // Find the preferred back camera.
    _currentCameraIndex = _findPreferredCamera(.back);

    await _initializeCameraController(_cameras[_currentCameraIndex]);
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _controller.dispose();
  }

  int _findPreferredCamera(CameraLensDirection direction) {
    // Get first camera with correct direction
    final index = _cameras.indexWhere(
      (camera) => camera.lensDirection == direction,
    );

    return index != -1 ? index : 0;
  }

  Future<void> _initializeCameraController(
    CameraDescription description,
  ) async {
    _controller = CameraController(description, .max);

    await _controller.initialize();
  }

  @override
  Future<void> setFlashMode(FlashMode mode) async {
    if (!isInitialized) return;

    await _controller.setFlashMode(mode);
  }

  @override
  Future<void> setFocusPoint(Offset offset) async {
    await _controller.setFocusPoint(offset);
  }

  @override
  Future<void> setZoomLevel(double value) async {
    await _controller.setZoomLevel(value);
  }

  @override
  Future<void> switchCamera() async {
    if (_cameras.length <= 1) return;

    await _controller.dispose();

    // Switch between front and back camera
    final currentDirection = _cameras[_currentCameraIndex].lensDirection;

    final CameraLensDirection targetDirection = currentDirection == .back
        ? .front
        : .back;

    final targetCameraIndex = _findPreferredCamera(targetDirection);

    if (targetCameraIndex == _currentCameraIndex) {
      // No alternative camera found, reinitialize current
      _controller = CameraController(_cameras[_currentCameraIndex], .max);
      await _controller.initialize();
      return;
    }

    _currentCameraIndex = targetCameraIndex;

    await _initializeCameraController(_cameras[_currentCameraIndex]);

    await _controller.initialize();
  }

  @override
  Future<void> startRecording() async {
    await _controller.startVideoRecording();
  }

  @override
  Future<void> stopRecording() async {
    final result = await _controller.stopVideoRecording();

    // TODO: Return Result as File or uint8list for the web
  }

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    // App state changed before we got the chance to initialize.
    if (!isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      await _initializeCameraController(_controller.description);
    }
  }

  @override
  Widget get previewWidget {
    return CameraPreview(_controller);
  }

  @override
  double get cameraAspectRatio => _controller.value.aspectRatio;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get canRecord => isInitialized && !_controller.value.isRecordingVideo;

  @override
  bool get canSwitchCamera {
    final hasFront = _cameras.any((c) => c.lensDirection == .front);
    final hasBack = _cameras.any((c) => c.lensDirection == .back);
    return hasFront && hasBack;
  }
}
