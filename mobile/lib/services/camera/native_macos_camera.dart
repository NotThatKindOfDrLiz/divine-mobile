// ABOUTME: Native macOS camera interface using platform channels
// ABOUTME: Communicates with Swift AVFoundation implementation for real camera access

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:openvine/utils/unified_logger.dart';

/// TODO(@hm21): delete this file and the native implementation except the permission part
/// Camera information including resolution, aspect ratio, and capabilities
class CameraInfo {
  final int width;
  final int height;
  final double aspectRatio;
  final bool hasFlash;
  final bool success;

  const CameraInfo({
    required this.width,
    required this.height,
    required this.aspectRatio,
    required this.hasFlash,
    this.success = true,
  });

  factory CameraInfo.fromMap(Map<String, dynamic> map) {
    return CameraInfo(
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
      aspectRatio: map['aspectRatio'] as double? ?? 16.0 / 9.0,
      hasFlash: map['hasFlash'] as bool? ?? false,
      success: map['success'] as bool? ?? true,
    );
  }

  @override
  String toString() =>
      'CameraInfo(${width}x$height, ratio: $aspectRatio, flash: $hasFlash)';
}

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
  ///
  /// Returns true if permission is granted, false otherwise.
  /// If [openSettingsOnDenied] is true and permission was previously denied,
  /// will automatically open System Settings for the user to grant permission.
  ///
  /// Throws [PlatformException] with code 'PERMISSION_DENIED' if permission
  /// was previously denied and [openSettingsOnDenied] is false.
  static Future<bool> requestPermission({
    bool openSettingsOnDenied = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      Log.debug(
        '📱 Camera permission result: $result',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return result ?? false;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        Log.warning(
          'Camera permission denied: ${e.message}',
          name: 'NativeMacosCamera',
          category: LogCategory.video,
        );

        if (openSettingsOnDenied) {
          Log.debug(
            '⚙️ Opening System Settings for camera permission',
            name: 'NativeMacosCamera',
            category: LogCategory.video,
          );
          await openSystemSettings();
        }

        // Re-throw so caller can handle appropriately
        rethrow;
      }

      Log.error(
        'Failed to request camera permission: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    } catch (e) {
      Log.error(
        'Failed to request camera permission: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Open macOS System Settings to the Camera privacy page
  ///
  /// Allows the user to manually enable camera access if it was previously denied.
  static Future<void> openSystemSettings() async {
    try {
      await _channel.invokeMethod('openSystemSettings');
      Log.debug(
        '⚙️ Opened System Settings for camera permission',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        'Failed to open System Settings: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
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

  /// Check if multiple cameras are available
  ///
  /// Returns true if two or more cameras are available for switching.
  /// Useful to determine whether to show camera switch UI elements.
  static Future<bool> hasMultipleCameras() async {
    try {
      final cameras = await getAvailableCameras();
      final hasMultiple = cameras.length > 1;
      Log.debug(
        '📷 Multiple cameras available: $hasMultiple (${cameras.length} total)',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return hasMultiple;
    } catch (e) {
      Log.error(
        'Failed to check multiple cameras: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Switch to camera by index
  ///
  /// Returns [CameraInfo] with camera information if successful, null otherwise.
  static Future<CameraInfo?> switchCamera(int cameraIndex) async {
    try {
      final result = await _channel.invokeMethod<Map>('switchCamera', {
        'cameraIndex': cameraIndex,
      });

      if (result == null) return null;

      final cameraInfo = CameraInfo.fromMap(Map<String, dynamic>.from(result));

      if (cameraInfo.success) {
        Log.debug(
          '📷 Switched to camera $cameraIndex - $cameraInfo',
          name: 'NativeMacosCamera',
          category: LogCategory.video,
        );
      } else {
        Log.warning(
          'Failed to switch to camera $cameraIndex',
          name: 'NativeMacosCamera',
          category: LogCategory.video,
        );
      }
      return cameraInfo;
    } catch (e) {
      Log.error(
        'Failed to switch camera: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Check if the current camera has flash/torch support
  ///
  /// If [deviceId] is provided, checks flash support for that specific device.
  /// Otherwise, checks the currently active camera.
  ///
  /// Returns true if flash is available, false otherwise.
  /// Returns false if no camera is initialized or device not found.
  static Future<bool> hasFlash({String? deviceId}) async {
    try {
      final Map<String, dynamic>? arguments = deviceId != null
          ? {'deviceId': deviceId}
          : null;

      final result = await _channel.invokeMethod<bool>('hasFlash', arguments);
      final hasFlash = result ?? false;
      Log.debug(
        '💡 Camera flash support: $hasFlash',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return hasFlash;
    } catch (e) {
      Log.error(
        'Failed to check flash support: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Get camera aspect ratio and resolution
  ///
  /// If [deviceId] is provided, gets info for that specific device.
  /// Otherwise, gets info for the currently active camera.
  ///
  /// Returns aspect ratio as double, or null if unavailable.
  static Future<double?> getAspectRatio({String? deviceId}) async {
    try {
      final Map<String, dynamic>? arguments = deviceId != null
          ? {'deviceId': deviceId}
          : null;

      final result = await _channel.invokeMethod<Map>(
        'getAspectRatio',
        arguments,
      );
      if (result == null) return null;

      final cameraInfo = CameraInfo.fromMap(Map<String, dynamic>.from(result));
      Log.debug(
        '📐 Camera info: $cameraInfo',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return cameraInfo.aspectRatio;
    } catch (e) {
      Log.error(
        'Failed to get camera aspect ratio: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return null;
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
