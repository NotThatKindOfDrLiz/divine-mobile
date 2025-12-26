import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'camera_base_service.dart';

class CameraMobileService extends CameraBaseService {
  late CameraController _controller;

  late final List<CameraDescription> _cameras;
  int _currentCameraIndex = 0;

  @override
  Future<void> initialize() async {
    _cameras = await availableCameras();

    // Find the preferred back camera.
    _currentCameraIndex = _findPreferredCamera(.back);

    _controller = CameraController(
      _cameras[_currentCameraIndex],
      ResolutionPreset.max,
    );

    await _controller.initialize();
  }

  @override
  Future<void> dispose() async {
    _controller.dispose();
  }

  int _findPreferredCamera(CameraLensDirection direction) {
    // First pass: try to find a wide angle lens with standard orientation
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == direction) {
        if (_cameras[i].sensorOrientation == 90 ||
            _cameras[i].sensorOrientation == 270) {
          return i;
        }
      }
    }

    // Second pass: just get first with correct direction
    final index = _cameras.indexWhere(
      (camera) => camera.lensDirection == direction,
    );

    return index != -1 ? index : 0;
  }

  Future<void> _initializeCameraController(
    CameraDescription description,
  ) async {
    _controller = CameraController(description, ResolutionPreset.max);

    await _controller.initialize();
  }

  @override
  Future<void> setFlashMode(FlashMode mode) async {
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
    if (!_controller.value.isInitialized) {
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
}
