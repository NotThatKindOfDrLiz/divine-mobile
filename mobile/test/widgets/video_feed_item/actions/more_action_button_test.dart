// ABOUTME: Tests for MoreActionButton widget
// ABOUTME: Verifies the button renders correctly with proper semantics
// ABOUTME: and opens the unified share sheet with expected actions.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profiles/profiles_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/widgets/video_feed_item/actions/more_action_button.dart';
import 'package:profile_repository/profile_repository.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockProfilesBloc extends MockBloc<ProfilesEvent, ProfilesState>
    implements ProfilesBloc {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late VideoEvent testVideo;
  late _MockProfilesBloc mockProfilesBloc;

  setUp(() {
    mockProfilesBloc = _MockProfilesBloc();
    when(() => mockProfilesBloc.state).thenReturn(const ProfilesState());

    testVideo = VideoEvent(
      id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'Test video content',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/video.mp4',
      title: 'Test Video',
    );
  });

  group(MoreActionButton, () {
    testWidgets('renders three-dots icon button', (tester) async {
      await tester.pumpWidget(
        testProviderScope(
          child: BlocProvider<ProfilesBloc>.value(
            value: mockProfilesBloc,
            child: MaterialApp(
              home: Scaffold(body: MoreActionButton(video: testVideo)),
            ),
          ),
        ),
      );

      expect(find.byType(MoreActionButton), findsOneWidget);

      final divineIcons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .toList();
      expect(
        divineIcons.any((icon) => icon.icon == DivineIconName.dotsThree),
        isTrue,
        reason: 'Should render dotsThree DivineIcon',
      );
    });

    testWidgets('has correct accessibility semantics', (tester) async {
      await tester.pumpWidget(
        testProviderScope(
          child: BlocProvider<ProfilesBloc>.value(
            value: mockProfilesBloc,
            child: MaterialApp(
              home: Scaffold(body: MoreActionButton(video: testVideo)),
            ),
          ),
        ),
      );

      final semanticsFinder = find.bySemanticsLabel('More options');
      expect(semanticsFinder, findsOneWidget);
    });
  });

  group('VideoMoreMenu', () {
    late _MockFollowRepository mockFollowRepository;
    late _MockProfileRepository mockProfileRepository;
    late MockAuthService mockAuthService;

    setUp(() {
      mockFollowRepository = _MockFollowRepository();
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);

      mockProfileRepository = _MockProfileRepository();
      when(
        () => mockProfileRepository.getCachedProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      mockAuthService = createMockAuthService();
    });

    Widget buildMenuWidget({bool debugToolsEnabled = false}) {
      return testMaterialApp(
        mockAuthService: mockAuthService,
        mockProfileRepository: mockProfileRepository,
        additionalOverrides: [
          followRepositoryProvider.overrideWithValue(mockFollowRepository),
          isFeatureEnabledProvider(
            FeatureFlag.debugTools,
          ).overrideWithValue(debugToolsEnabled),
        ],
        home: Scaffold(body: MoreActionButton(video: testVideo)),
      );
    }

    testWidgets('renders share sheet actions', (tester) async {
      await tester.pumpWidget(buildMenuWidget());

      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      // The unified share sheet shows "More actions" with
      // action circles: Report, Copy, Share via, Save, etc.
      expect(find.text('More actions'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Share via'), findsOneWidget);
    });

    testWidgets('hides debug tools when feature flag is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(buildMenuWidget());
      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Event JSON'), findsNothing);
      expect(find.text('Event ID'), findsNothing);
    });

    testWidgets('shows debug tools when feature flag is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(buildMenuWidget(debugToolsEnabled: true));
      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Event JSON'), findsOneWidget);
      expect(find.text('Event ID'), findsOneWidget);
    });

    testWidgets('shows Save action', (tester) async {
      await tester.pumpWidget(buildMenuWidget());
      await tester.tap(find.byType(MoreActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
    });
  });
}
