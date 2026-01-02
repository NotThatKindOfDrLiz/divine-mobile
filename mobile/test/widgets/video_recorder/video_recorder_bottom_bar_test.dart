// ABOUTME: Tests for VideoRecorderBottomBar widget
// ABOUTME: Validates bottom bar UI, record button, and control buttons

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';

import '../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderBottomBar Widget Tests', () {
    late MockCameraService mockCamera;

    setUp(() async {
      mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
      );
      await mockCamera.initialize();
    });

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          videoRecorderProvider.overrideWith(
            () => VideoRecorderNotifier(mockCamera),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [VideoRecorderBottomBar(previewWidgetRadius: 16.0)],
            ),
          ),
        ),
      );
    }

    testWidgets('displays record button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.byKey(ValueKey('divine-camera-record-button')),
        findsOneWidget,
      );
    });

    testWidgets('displays flash toggle button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Flash icon should be visible (default is auto, shows as flash_auto)
      expect(find.byIcon(Icons.flash_auto), findsOneWidget);
    });

    testWidgets('displays timer toggle button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Timer icon should be visible (default is off, shows as timer)
      expect(find.byIcon(Icons.timer), findsOneWidget);
    });

    testWidgets('displays aspect ratio toggle button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Aspect ratio icon should be visible (default is vertical, shows as crop_portrait)
      expect(find.byIcon(Icons.crop_portrait), findsOneWidget);
    });

    testWidgets('displays camera flip button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Camera flip icon should be visible
      expect(find.byIcon(Icons.cached_rounded), findsOneWidget);
    });

    testWidgets('displays more options button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // More options icon should be visible
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('has 5 control buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Flash, Timer, Aspect Ratio, Flip Camera, More Options
      expect(find.byType(IconButton), findsNWidgets(5));
    });

    testWidgets('record button has correct styling', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final container = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byKey(ValueKey('divine-camera-record-button')),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );

      expect(container.constraints?.maxWidth, equals(96));
      expect(container.constraints?.maxHeight, equals(96));
    });

    testWidgets('uses SafeArea for bottom positioning', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('is positioned at bottom of screen', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // VideoRecorderBottomBar itself returns a Positioned widget
      final positioned = tester.widget<Positioned>(
        find.byType(Positioned).first,
      );
      expect(positioned.bottom, equals(0));
      expect(positioned.left, equals(0));
      expect(positioned.right, equals(0));
    });
  });
}
