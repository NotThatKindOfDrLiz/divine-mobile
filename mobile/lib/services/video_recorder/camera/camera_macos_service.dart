import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/widgets.dart';

import 'camera_base_service.dart';

class CameraMacOSService extends CameraBaseService {
  late final List<CameraMacOSDevice> _videoDevices;
  late final List<CameraMacOSDevice> _audioDevices;
  int _currentCameraIndex = 0;
  bool _isRecording = false;
  bool _isInitialized = false;

  @override
  Future<void> dispose() async {
    await CameraMacOS.instance.destroy();
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    _videoDevices = await CameraMacOS.instance.listDevices(
      deviceType: CameraMacOSDeviceType.video,
    );
    _audioDevices = await CameraMacOS.instance.listDevices(
      deviceType: CameraMacOSDeviceType.audio,
    );

    await _initializeCameraController();
  }

  Future<void> _initializeCameraController() async {
    await CameraMacOS.instance.initialize(
      cameraMacOSMode: CameraMacOSMode.video,
      deviceId: _videoDevices[_currentCameraIndex].deviceId,
      audioDeviceId: _audioDevices.first.deviceId,
    );
  }

  @override
  Future<void> setFlashMode(FlashMode mode) async {
    await CameraMacOS.instance.toggleTorch(_getTorchMode(mode));
  }

  @override
  Future<void> setFocusPoint(Offset offset) async {
    await CameraMacOS.instance.setFocusPoint(offset);
  }

  @override
  Future<void> setZoomLevel(double value) async {
    await CameraMacOS.instance.setZoomLevel(value);
  }

  @override
  Future<void> switchCamera() async {
    if (_videoDevices.length <= 1) return;

    await CameraMacOS.instance.destroy();

    _currentCameraIndex = (_currentCameraIndex + 1) % _videoDevices.length;

    await CameraMacOS.instance.initialize(
      cameraMacOSMode: CameraMacOSMode.video,
      deviceId: _videoDevices[_currentCameraIndex].deviceId,
      audioDeviceId: _audioDevices.first.deviceId,
    );
  }

  Torch _getTorchMode(FlashMode mode) {
    return switch (mode) {
      .always => .on,
      .torch => .on,
      .auto => .auto,
      .off => .off,
    };
  }

  @override
  Future<void> startRecording() async {
    await CameraMacOS.instance.startVideoRecording();
    _isRecording = true;
  }

  @override
  Future<void> stopRecording() async {
    final result = await CameraMacOS.instance.stopVideoRecording();
    _isRecording = false;

    if (result == null) {
      return;
    }

    // TODO: Handle Result
  }

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.inactive) {
      CameraMacOS.instance.destroy();
    } else if (state == AppLifecycleState.resumed) {
      await _initializeCameraController();
    }
  }

  @override
  Widget get previewWidget {
    return CameraMacOSView(
      cameraMode: CameraMacOSMode.video,
      onCameraInizialized: (CameraMacOSController controller) {
        _isInitialized = true;
      },
    );
  }

  /// TODO(@hm21): Maybe extend with native code?
  @override
  double get cameraAspectRatio => 4.0 / 3.0;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get canRecord => _isInitialized && !_isRecording;

  @override
  bool get canSwitchCamera => _videoDevices.length > 1;
}
