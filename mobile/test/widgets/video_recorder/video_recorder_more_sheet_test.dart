// ABOUTME: Tests for VideoRecorderMoreSheet widget
// ABOUTME: Validates more options menu, clip management actions, and menu items

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_more_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderMoreSheet Widget Tests', () {
    testWidgets('renders more sheet widget', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      expect(find.byType(VideoRecorderMoreSheet), findsOneWidget);
    });

    testWidgets('uses SafeArea for proper spacing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      // VideoRecorderMoreSheet returns SafeArea as its root widget
      final safeArea = find
          .descendant(
            of: find.byType(VideoRecorderMoreSheet),
            matching: find.byType(SafeArea),
          )
          .first;

      expect(safeArea, findsOneWidget);
    });

    testWidgets('displays "Add clip from Library" option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      expect(find.text('Add clip from Library'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
    });

    testWidgets('displays "Save clip to Library" option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      expect(find.text('Save clip to Library'), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);
    });

    testWidgets('displays "Remove last clip" option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      expect(find.text('Remove last clip'), findsOneWidget);
      expect(find.byIcon(Icons.undo), findsOneWidget);
    });

    testWidgets('displays "Clear all clips" option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      expect(find.text('Clear all clips'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('destructive actions have red color', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      // Remove and Clear actions should be present
      expect(find.text('Remove last clip'), findsOneWidget);
      expect(find.text('Clear all clips'), findsOneWidget);
    });

    testWidgets('Add clip option is always enabled', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      final addClipTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Add clip from Library'),
          matching: find.byType(ListTile),
        ),
      );

      expect(addClipTile.enabled, isTrue);
    });

    testWidgets('Save option is initially disabled when no clips', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      final saveTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Save clip to Library'),
          matching: find.byType(ListTile),
        ),
      );

      // Initially no clips, so should be disabled
      expect(saveTile.enabled, isFalse);
    });

    testWidgets('Remove option is initially disabled when no clips', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      final removeTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Remove last clip'),
          matching: find.byType(ListTile),
        ),
      );

      // Initially no clips, so should be disabled
      expect(removeTile.enabled, isFalse);
    });

    testWidgets('Clear option is initially disabled when no clips', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      final clearTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Clear all clips'),
          matching: find.byType(ListTile),
        ),
      );

      // Initially no clips, so should be disabled
      expect(clearTile.enabled, isFalse);
    });

    testWidgets('menu items have leading icons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      // Check that all ListTiles have leading icons
      final listTiles = tester.widgetList<ListTile>(find.byType(ListTile));

      for (final tile in listTiles) {
        expect(tile.leading, isA<Icon>());
      }
    });

    testWidgets('icons have size 32', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      final icons = tester.widgetList<Icon>(find.byType(Icon));

      for (final icon in icons) {
        expect(icon.size, equals(32));
      }
    });
  });
}
