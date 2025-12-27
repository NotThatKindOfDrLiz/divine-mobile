// ABOUTME: macOS platform implementation of camera service using the camera_macos package
// ABOUTME: Handles camera and audio device management, recording, and torch control on macOS

import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/widgets.dart';

import 'camera_base_service.dart';

/// macOS implementation of [CameraBaseService] using the camera_macos package.
///
/// Manages video and audio devices, recording, and camera switching on macOS.
class CameraMacOSService extends CameraBaseService {
  late final List<CameraMacOSDevice> _videoDevices;
  late final List<CameraMacOSDevice> _audioDevices;

  int _currentCameraIndex = 0;

  /// TODO(@hm21): read from native?
  double _minZoomLevel = 1;
  double _maxZoomLevel = 10;

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

  /// Initializes the camera with the current video and audio device.
  ///
  /// Sets up the camera in video mode with the selected devices.
  Future<void> _initializeCameraController() async {
    await CameraMacOS.instance.initialize(
      cameraMacOSMode: CameraMacOSMode.video,
      deviceId: _videoDevices[_currentCameraIndex].deviceId,
      audioDeviceId: _audioDevices.first.deviceId,
    );
  }

  @override
  Future<bool> setFlashMode(FlashMode mode) async {
    if (!isInitialized) return false;
    try {
      await CameraMacOS.instance.toggleTorch(_getTorchMode(mode));
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> setFocusPoint(Offset offset) async {
    if (!isInitialized) return false;
    try {
      await CameraMacOS.instance.setFocusPoint(offset);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> setZoomLevel(double value) async {
    if (!isInitialized) return false;
    try {
      await CameraMacOS.instance.setZoomLevel(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> switchCamera() async {
    if (_videoDevices.length <= 1) return false;

    try {
      await CameraMacOS.instance.destroy();

      _currentCameraIndex = (_currentCameraIndex + 1) % _videoDevices.length;

      await CameraMacOS.instance.initialize(
        cameraMacOSMode: CameraMacOSMode.video,
        deviceId: _videoDevices[_currentCameraIndex].deviceId,
        audioDeviceId: _audioDevices.first.deviceId,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Converts [FlashMode] to macOS [Torch] mode.
  ///
  /// Maps camera package flash modes to camera_macos torch settings.
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
  Widget buildPreviewWidget({
    required Function(ScaleStartDetails details) onScaleStart,
    required Function(ScaleUpdateDetails details) onScaleUpdate,
    required Function(TapDownDetails details) onTapDown,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return GestureDetector(
          behavior: .opaque,
          onScaleStart: onScaleStart,
          onScaleUpdate: onScaleUpdate,
          onTapDown: onTapDown,
          child: CameraMacOSView(
            cameraMode: .video,
            onCameraInizialized: (CameraMacOSController controller) {
              _isInitialized = true;
            },
          ),
        );
      },
    );
  }

  /// TODO(@hm21): Maybe extend with native code?
  @override
  double get cameraAspectRatio => 16.0 / 9.0;

  @override
  double get minZoomLevel => _minZoomLevel;
  @override
  double get maxZoomLevel => _maxZoomLevel;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isFocusPointSupported => true;

  @override
  bool get canRecord => _isInitialized && !_isRecording;

  @override
  bool get canSwitchCamera => _videoDevices.length > 1;
}
