import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

abstract class CameraBaseService {
  Future<void> initialize();
  Future<void> dispose();

  Future<void> setFlashMode(FlashMode mode);
  Future<void> setFocusPoint(Offset offset);
  Future<void> setZoomLevel(double value);

  Future<void> switchCamera();

  Future<void> startRecording();
  Future<void> stopRecording();

  Future<void> handleAppLifecycleState(AppLifecycleState state);

  double get cameraAspectRatio;

  bool get isInitialized;
  bool get canRecord;
  bool get canSwitchCamera;

  Widget get previewWidget;
}
