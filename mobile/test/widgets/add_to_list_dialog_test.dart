// ABOUTME: Tests for SelectListDialog and CreateListDialog widgets
// ABOUTME: Verifies list selection and list creation form rendering

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';

import '../helpers/test_provider_overrides.dart';

/// Test data for the fake notifier - set before each test
List<CuratedList> _fakeLists = [];

/// Fake notifier that provides test data for curatedListsStateProvider
class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => null;

  @override
  Future<List<CuratedList>> build() async => _fakeLists;
}

void main() {
  group(SelectListDialog, () {
    late VideoEvent testVideo;

    setUp(() {
      testVideo = VideoEvent(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        pubkey:
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Test Video',
      );
      _fakeLists = [];
    });

    testWidgets('renders Add to List title', (tester) async {
      _fakeLists = [
        CuratedList(
          id: 'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey:
              'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'My Test List',
          description: 'A test list',
          isPublic: true,
          videoEventIds: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
          ],
          child: MaterialApp(
            home: Scaffold(body: SelectListDialog(video: testVideo)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Add to List'), findsOneWidget);
      expect(find.text('My Test List'), findsOneWidget);
      expect(find.text('0 videos'), findsOneWidget);
    });

    testWidgets('shows check icon for video already in list', (tester) async {
      _fakeLists = [
        CuratedList(
          id: 'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey:
              'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'Contains Video',
          description: null,
          isPublic: true,
          videoEventIds: [
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
          ],
          child: MaterialApp(
            home: Scaffold(body: SelectListDialog(video: testVideo)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group(CreateListDialog, () {
    late VideoEvent testVideo;

    setUp(() {
      testVideo = VideoEvent(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        pubkey:
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Test Video',
      );
    });

    testWidgets('renders Create New List form', (tester) async {
      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CreateListDialog(video: testVideo)),
          ),
        ),
      );

      expect(find.text('Create New List'), findsOneWidget);
      expect(find.text('List Name'), findsOneWidget);
      expect(find.text('Description (optional)'), findsOneWidget);
      expect(find.text('Public List'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('public list switch toggles', (tester) async {
      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CreateListDialog(video: testVideo)),
          ),
        ),
      );

      // Public switch should be on by default
      final switchWidget = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchWidget.value, isTrue);

      // Tap to toggle off
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      final updatedSwitch = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(updatedSwitch.value, isFalse);
    });
  });
}
