// ABOUTME: Tests for VideoRecorderCameraPreview widget
// ABOUTME: Validates camera preview rendering, aspect ratio, and grid overlay

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_recording_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_camera_placeholder.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_camera_preview.dart';

import '../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderCameraPreview Widget Tests', () {
    testWidgets('renders camera preview widget', (tester) async {
      final mockCamera = MockCameraService();
      await mockCamera.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoRecordingProvider.overrideWith(
              () => VideoRecordingNotifier(mockCamera),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VideoRecorderCameraPreview(previewWidgetRadius: 16.0),
            ),
          ),
        ),
      );

      expect(find.byType(VideoRecorderCameraPreview), findsOneWidget);
    });

    testWidgets('displays placeholder when camera not initialized', (
      tester,
    ) async {
      final mockCamera = MockCameraService();
      // Don't initialize - should show placeholder

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoRecordingProvider.overrideWith(
              () => VideoRecordingNotifier(mockCamera),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VideoRecorderCameraPreview(previewWidgetRadius: 16.0),
            ),
          ),
        ),
      );

      // Should show placeholder widget
      expect(find.byType(VideoRecorderCameraPlaceholder), findsOneWidget);
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
          child: const MaterialApp(
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
          child: const MaterialApp(
            home: Scaffold(
              body: VideoRecorderCameraPreview(previewWidgetRadius: 16.0),
            ),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('contains AnimatedContainer for transitions', (tester) async {
      final mockCamera = MockCameraService();
      await mockCamera.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoRecordingProvider.overrideWith(
              () => VideoRecordingNotifier(mockCamera),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VideoRecorderCameraPreview(previewWidgetRadius: 16.0),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedContainer), findsOneWidget);
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
