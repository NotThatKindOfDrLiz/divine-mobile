// ABOUTME: Tests for VideoRecorderFocusPoint widget
// ABOUTME: Validates focus point indicator, animations, and position calculations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_focus_point.dart';

import '../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderFocusPoint Widget Tests', () {
    late MockCameraService mockCamera;

    setUp(() async {
      mockCamera = MockCameraService();
      await mockCamera.initialize();
    });

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          vineRecordingProvider.overrideWith(
            (ref) => VineRecordingNotifier(ref, mockCamera),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: VideoRecorderFocusPoint())),
      );
    }

    testWidgets('renders focus point widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(VideoRecorderFocusPoint), findsOneWidget);
    });

    testWidgets('uses LayoutBuilder for responsive sizing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(LayoutBuilder), findsOneWidget);
    });

    testWidgets('contains IgnorePointer to prevent touch interference', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      expect(
        find.descendant(
          of: find.byType(VideoRecorderFocusPoint),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is initially invisible when focusPoint is zero', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );

      expect(animatedOpacity.opacity, equals(0.0));
    });

    testWidgets('renders focus point at correct position', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vineRecordingProvider.overrideWith((ref) {
              final notifier = VineRecordingNotifier(ref, mockCamera);
              // Set initial state with a focus point
              Future.microtask(() {
                notifier.state = notifier.state.copyWith(
                  focusPoint: Offset(0.5, 0.5),
                );
              });
              return notifier;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: VideoRecorderFocusPoint(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the Positioned widget within VideoRecorderFocusPoint
      final positioned = tester.widget<Positioned>(
        find.descendant(
          of: find.byType(VideoRecorderFocusPoint),
          matching: find.byType(Positioned),
        ),
      );

      // With a 400x600 container and focus point at (0.5, 0.5):
      // x = 0.5 * 400 = 200
      // y = 0.5 * 600 = 300
      // indicatorSize = 400 * 0.08 = 32
      // left = 200 - 32/2 = 184
      // top = 300 - 32/2 = 284

      expect(positioned.left, equals(184.0));
      expect(positioned.top, equals(284.0));
    });
  });
}
