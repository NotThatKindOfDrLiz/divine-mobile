// ABOUTME: Native macOS camera interface using platform channels
// ABOUTME: Communicates with Swift AVFoundation implementation for real camera access

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:openvine/utils/unified_logger.dart';

/// TODO(@hm21): Required? Why not use the already implmented package camera_macos?
/// Native macOS camera interface using platform channels
class NativeMacOSCamera {
  static const MethodChannel _channel = MethodChannel('openvine/native_camera');

  static StreamController<Uint8List>? _frameStreamController;
  static Stream<Uint8List>? _frameStream;

  /// Initialize the native camera
  static Future<bool> initialize() async {
    try {
      Log.debug(
        '📱 [NativeMacOSCamera] Calling native initialize method',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      final result = await _channel.invokeMethod<bool>('initialize');
      Log.debug(
        '📱 [NativeMacOSCamera] Initialize result: $result',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return result ?? false;
    } catch (e) {
      Log.error(
        '[NativeMacOSCamera] Failed to initialize native camera: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Start camera preview
  static Future<bool> startPreview() async {
    try {
      Log.debug(
        '📱 [NativeMacOSCamera] Calling startPreview method',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      final result = await _channel.invokeMethod<bool>('startPreview');
      Log.debug(
        '📱 [NativeMacOSCamera] StartPreview result: $result',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return result ?? false;
    } catch (e) {
      Log.error(
        '[NativeMacOSCamera] Failed to start native camera preview: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Stop camera preview
  static Future<bool> stopPreview() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopPreview');
      Log.info(
        '📱 Native macOS camera preview stopped: $result',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return result ?? false;
    } catch (e) {
      Log.error(
        'Failed to stop native camera preview: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Start video recording
  static Future<bool> startRecording() async {
    try {
      Log.debug(
        '📱 [NativeMacOSCamera] Calling startRecording method',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      final result = await _channel.invokeMethod<bool>('startRecording');
      Log.debug(
        '📱 [NativeMacOSCamera] StartRecording result: $result',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return result ?? false;
    } catch (e) {
      Log.error(
        '[NativeMacOSCamera] Failed to start native camera recording: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Stop video recording and return file path
  static Future<String?> stopRecording() async {
    try {
      Log.debug(
        '📱 [NativeMacOSCamera] Calling stopRecording method with timeout',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );

      // Add timeout to prevent hanging forever
      final result = await _channel
          .invokeMethod<String>('stopRecording')
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              Log.debug(
                '⏰ [NativeMacOSCamera] stopRecording timed out after 3 seconds',
                name: 'NativeMacosCamera',
                category: LogCategory.video,
              );
              return null;
            },
          );

      Log.debug(
        '📱 [NativeMacOSCamera] StopRecording result: $result',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      if (result != null) {
        Log.debug(
          '📱 [NativeMacOSCamera] Video saved to: $result',
          name: 'NativeMacosCamera',
          category: LogCategory.video,
        );
      } else {
        Log.warning(
          '[NativeMacOSCamera] No video path returned',
          name: 'NativeMacosCamera',
          category: LogCategory.video,
        );
      }
      return result;
    } catch (e) {
      Log.error(
        '[NativeMacOSCamera] Failed to stop native camera recording: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Get frame stream for real-time capture
  static Stream<Uint8List> get frameStream {
    if (_frameStream == null) {
      _frameStreamController = StreamController<Uint8List>.broadcast();
      _frameStream = _frameStreamController!.stream;

      // Set up method call handler for frames
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onFrameAvailable') {
          final frameData = call.arguments as Uint8List;
          // Uncomment for very verbose frame logging (will spam logs)
          // Log.verbose('[NativeMacOSCamera] Frame received: ${frameData.length} bytes', name: 'NativeMacosCamera', category: LogCategory.video);
          _frameStreamController?.add(frameData);
        }
      });
    }
    return _frameStream!;
  }

  /// Request permission to access camera
  static Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      Log.debug(
        '📱 Camera permission result: $result',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return result ?? false;
    } catch (e) {
      Log.error(
        'Failed to request camera permission: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Check if camera permission is granted
  static Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } catch (e) {
      Log.error(
        'Failed to check camera permission: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Get available cameras
  static Future<List<Map<String, dynamic>>> getAvailableCameras() async {
    try {
      final result = await _channel.invokeMethod<List>('getAvailableCameras');
      if (result == null) return [];

      // Safely convert each item to Map<String, dynamic>
      return result.map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      }).toList();
    } catch (e) {
      Log.error(
        'Failed to get available cameras: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Switch to camera by index
  static Future<bool> switchCamera(int cameraIndex) async {
    try {
      final result = await _channel.invokeMethod<bool>('switchCamera', {
        'cameraIndex': cameraIndex,
      });
      Log.debug(
        'Switched to camera $cameraIndex: $result',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return result ?? false;
    } catch (e) {
      Log.error(
        'Failed to switch camera: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Dispose native camera resources
  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
      _frameStreamController?.close();
      _frameStreamController = null;
      _frameStream = null;
      Log.debug(
        '🧹 Native macOS camera disposed',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        'Error disposing native camera: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
    }
  }
}
