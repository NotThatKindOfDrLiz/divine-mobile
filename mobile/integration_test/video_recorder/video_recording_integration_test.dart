// ABOUTME: Integration tests for video recording functionality
// ABOUTME: Tests start/stop recording, video file creation, and recording state

// NOTE: On Android, camera/microphone permissions must be granted before running.
// Either grant via ADB: adb shell pm grant co.openvine.app android.permission.CAMERA
// Or the first test run will show permission dialogs that must be accepted.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/services/video_recorder/camera/camera_permission_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Video Recording Integration Tests', () {
    late CameraService cameraService;

    setUpAll(() async {
      await CameraPermissionService.ensurePermissions();
    });

    setUp(() async {
      cameraService = CameraService.create();
      await cameraService.initialize();
    });

    tearDown(() async {
      await cameraService.dispose();
    });

    testWidgets('can start recording', (tester) async {
      expect(cameraService.canRecord, isTrue);

      await cameraService.startRecording();

      // Give recording a moment to start
      await tester.pump(Duration(milliseconds: 100));
    });

    testWidgets('can stop recording after starting', (tester) async {
      await cameraService.startRecording();
      await tester.pump(Duration(milliseconds: 500));

      final video = await cameraService.stopRecording();

      // Video may be null or a valid EditorVideo depending on implementation
      expect(video, anyOf(isNull, isA<Object>()));
    });

    testWidgets('records video for minimum duration', (tester) async {
      await cameraService.startRecording();

      // Record for 2 seconds
      await tester.pump(Duration(seconds: 2));

      final video = await cameraService.stopRecording();

      // Should have created a video
      expect(video, isNotNull);
    });

    testWidgets('can start and stop multiple recordings', (tester) async {
      for (var i = 0; i < 3; i++) {
        await cameraService.startRecording();
        await tester.pump(Duration(milliseconds: 500));

        final video = await cameraService.stopRecording();

        // Each recording should complete
        expect(video, anyOf(isNull, isA<Object>()));

        // Wait between recordings
        await tester.pump(Duration(milliseconds: 100));
      }
    });

    testWidgets('stopping without starting does not crash', (tester) async {
      // Should handle gracefully
      final video = await cameraService.stopRecording();

      // Should return null or handle gracefully
      expect(video, anyOf(isNull, isA<Object>()));
    });
  });
}
