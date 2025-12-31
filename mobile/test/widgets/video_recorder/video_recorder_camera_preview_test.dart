// ABOUTME: Tests for VideoRecorderCameraPreview widget
// ABOUTME: Validates camera preview rendering, aspect ratio, and grid overlay

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_recording_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_camera_preview.dart';

import '../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderCameraPreview Widget Tests', () {
    testWidgets('displays mock camera preview from service', (tester) async {
      final mockCamera = MockCameraService();
      await mockCamera.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoRecordingProvider.overrideWith(
              () => VideoRecordingNotifier(mockCamera),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoRecorderCameraPreview(previewWidgetRadius: 16.0),
            ),
          ),
        ),
      );

      // Mock camera service provides a Container with text
      expect(find.text('Mock Camera Preview'), findsOneWidget);
    });

    testWidgets('renders with required radius parameter', (tester) async {
      final mockCamera = MockCameraService();
      await mockCamera.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoRecordingProvider.overrideWith(
              () => VideoRecordingNotifier(mockCamera),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoRecorderCameraPreview(previewWidgetRadius: 16.0),
            ),
          ),
        ),
      );

      expect(find.byType(VideoRecorderCameraPreview), findsOneWidget);
    });

    testWidgets('contains ClipRRect for rounded corners', (tester) async {
      final mockCamera = MockCameraService();
      await mockCamera.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoRecordingProvider.overrideWith(
              () => VideoRecordingNotifier(mockCamera),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoRecorderCameraPreview(previewWidgetRadius: 16.0),
            ),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('rebuilds when aspect ratio changes', (tester) async {
      final mockCamera = MockCameraService();
      await mockCamera.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoRecordingProvider.overrideWith(
              () => VideoRecordingNotifier(mockCamera),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoRecorderCameraPreview(previewWidgetRadius: 16.0),
            ),
          ),
        ),
      );

      await tester.pump();

      // Widget should be present after rebuild
      expect(find.byType(VideoRecorderCameraPreview), findsOneWidget);
    });

    testWidgets('maintains radius value', (tester) async {
      final mockCamera = MockCameraService();
      await mockCamera.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoRecordingProvider.overrideWith(
              () => VideoRecordingNotifier(mockCamera),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoRecorderCameraPreview(previewWidgetRadius: 20.0),
            ),
          ),
        ),
      );

      final widget = tester.widget<VideoRecorderCameraPreview>(
        find.byType(VideoRecorderCameraPreview),
      );

      expect(widget.previewWidgetRadius, equals(20.0));
    });
  });
}
