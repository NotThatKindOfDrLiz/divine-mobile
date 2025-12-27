import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

abstract class CameraBaseService {
  Future<void> initialize();
  Future<void> dispose();

  Future<bool> setFlashMode(FlashMode mode);
  Future<bool> setFocusPoint(Offset offset);
  Future<bool> setZoomLevel(double value);

  Future<bool> switchCamera();

  Future<void> startRecording();
  Future<void> stopRecording();

  Future<void> handleAppLifecycleState(AppLifecycleState state);

  double get cameraAspectRatio;
  double get minZoomLevel;
  double get maxZoomLevel;

  bool get isInitialized;
  bool get isFocusPointSupported;
  bool get canRecord;
  bool get canSwitchCamera;

  Widget buildPreviewWidget({
    required Function(ScaleStartDetails details) onScaleStart,
    required Function(ScaleUpdateDetails details) onScaleUpdate,
    required Function(TapDownDetails details) onTapDown,
  });
}
