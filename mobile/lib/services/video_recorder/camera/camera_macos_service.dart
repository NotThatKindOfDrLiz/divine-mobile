// ABOUTME: macOS platform implementation of camera service using the camera_macos package
// ABOUTME: Handles camera and audio device management, recording, and torch control on macOS

import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import 'camera_base_service.dart';

/// macOS implementation of [CameraService] using the camera_macos package.
///
/// Manages video and audio devices, recording, and camera switching on macOS.
class CameraMacOSService extends CameraService {
  List<CameraMacOSDevice>? _videoDevices;
  List<CameraMacOSDevice>? _audioDevices;

  int _currentCameraIndex = 0;

  /// TODO(@hm21): read from native?
  double _minZoomLevel = 1;
  double _maxZoomLevel = 10;

  bool _isRecording = false;
  bool _isInitialized = false;

  @override
  Future<void> dispose() async {
    Log.info(
      '📷 Disposing macOS camera',
      name: 'CameraMacOSService',
      category: .video,
    );

    await CameraMacOS.instance.destroy();
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    Log.info(
      '📷 Initializing macOS camera',
      name: 'CameraMacOSService',
      category: .video,
    );

    _videoDevices = await CameraMacOS.instance.listDevices(
      deviceType: CameraMacOSDeviceType.video,
    );
    _audioDevices = await CameraMacOS.instance.listDevices(
      deviceType: CameraMacOSDeviceType.audio,
    );

    await _initializeCameraController();
    _isInitialized = true;

    Log.info(
      '📷 macOS camera initialized (${_videoDevices!.length} video, ${_audioDevices!.length} audio devices)',
      name: 'CameraMacOSService',
      category: .video,
    );
  }

  /// Initializes the camera with the current video and audio device.
  ///
  /// Sets up the camera in video mode with the selected devices.
  Future<void> _initializeCameraController() async {
    await CameraMacOS.instance.initialize(
      cameraMacOSMode: CameraMacOSMode.video,
      deviceId: _videoDevices?[_currentCameraIndex].deviceId,
      audioDeviceId: _audioDevices?.first.deviceId,
    );
  }

  @override
  Future<bool> setFlashMode(FlashMode mode) async {
    if (!isInitialized) return false;
    try {
      Log.info(
        '📷 Setting torch mode to ${mode.name}',
        name: 'CameraMacOSService',
        category: .video,
      );
      await CameraMacOS.instance.toggleTorch(_getTorchMode(mode));
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set torch mode: $e',
        name: 'CameraMacOSService',
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
        name: 'CameraMacOSService',
        category: .video,
      );
      await CameraMacOS.instance.setFocusPoint(offset);
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set focus point: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> setExposurePoint(Offset offset) async {
    /// Currently not supported on macos.
    Log.info(
      '📷 Exposure point not supported on macOS',
      name: 'CameraMacOSService',
      category: .video,
    );
    return true;
  }

  @override
  Future<bool> setZoomLevel(double value) async {
    if (!isInitialized) return false;
    try {
      Log.info(
        '📷 Setting zoom level to $value',
        name: 'CameraMacOSService',
        category: .video,
      );
      await CameraMacOS.instance.setZoomLevel(value);
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set zoom level: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> switchCamera() async {
    if (_videoDevices != null && _videoDevices!.length <= 1) return false;

    try {
      Log.info(
        '📷 Switching macOS camera',
        name: 'CameraMacOSService',
        category: .video,
      );

      await CameraMacOS.instance.destroy();

      _currentCameraIndex = (_currentCameraIndex + 1) % _videoDevices!.length;

      await CameraMacOS.instance.initialize(
        cameraMacOSMode: CameraMacOSMode.video,
        deviceId: _videoDevices![_currentCameraIndex].deviceId,
        audioDeviceId: _audioDevices?.first.deviceId,
      );

      Log.info(
        '📷 macOS camera switched to device ${_currentCameraIndex}',
        name: 'CameraMacOSService',
        category: .video,
      );
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to switch macOS camera: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
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
    Log.info(
      '📷 Starting macOS video recording',
      name: 'CameraMacOSService',
      category: .video,
    );

    await CameraMacOS.instance.startVideoRecording();
    _isRecording = true;
  }

  @override
  Future<EditorVideo?> stopRecording() async {
    Log.info(
      '📷 Stopping macOS video recording',
      name: 'CameraMacOSService',
      category: .video,
    );

    final result = await CameraMacOS.instance.stopVideoRecording();
    _isRecording = false;

    if (result?.bytes == null) {
      Log.warning(
        '📷 macOS video recording stopped with null result',
        name: 'CameraMacOSService',
        category: .video,
      );
      return null;
    }

    Log.info(
      '📷 macOS video recording stopped',
      name: 'CameraMacOSService',
      category: .video,
    );

    return EditorVideo.memory(result!.bytes!);
  }

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    Log.info(
      '📷 macOS app lifecycle state changed to ${state.name}',
      name: 'CameraMacOSService',
      category: .video,
    );

    if (state == AppLifecycleState.inactive) {
      CameraMacOS.instance.destroy();
    } else if (state == AppLifecycleState.resumed) {
      await _initializeCameraController();

      Log.info(
        '📷 macOS camera reinitialized after resume',
        name: 'CameraMacOSService',
        category: .video,
      );
    }
  }

  @override
  Widget buildPreviewWidget({
    required Function(ScaleStartDetails details) onScaleStart,
    required Function(ScaleUpdateDetails details) onScaleUpdate,
    required Function(TapDownDetails details, BoxConstraints constraints)
    onTapDown,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return GestureDetector(
          behavior: .opaque,
          onScaleStart: onScaleStart,
          onScaleUpdate: onScaleUpdate,
          onTapDown: (details) => onTapDown(details, constraints),
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
  bool get canSwitchCamera =>
      _videoDevices != null && _videoDevices!.length > 1;
}
