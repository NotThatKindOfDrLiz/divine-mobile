// ABOUTME: Widget tests for VideoFeedPage overlay-to-playback integration
// ABOUTME: Verifies that overlay visibility and route changes pause/resume
// the pooled video feed

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoFeedBloc extends MockBloc<VideoFeedEvent, VideoFeedState>
    implements VideoFeedBloc {}

class _MockVideoFeedController extends Mock implements VideoFeedController {}

void main() {
  group(VideoFeedView, () {
    late VideoFeedBloc videoFeedBloc;
    late VideoFeedController videoFeedController;
    late StreamController<RouteContext> routeContextController;

    setUpAll(() {
      registerFallbackValue(const VideoFeedStarted());
      registerFallbackValue(const VideoFeedAutoRefreshRequested());
    });

    setUp(() {
      videoFeedBloc = _MockVideoFeedBloc();
      videoFeedController = _MockVideoFeedController();
      routeContextController = StreamController<RouteContext>.broadcast();

      when(
        () => videoFeedController.setActive(active: any(named: 'active')),
      ).thenReturn(null);
      when(() => videoFeedController.videoCount).thenReturn(0);
      when(() => videoFeedController.videos).thenReturn([]);
      when(() => videoFeedController.addListener(any())).thenReturn(null);
      when(() => videoFeedController.removeListener(any())).thenReturn(null);
      when(() => videoFeedController.dispose()).thenReturn(null);

      routeContextController.add(
        const RouteContext(type: RouteType.home, videoIndex: 0),
      );
    });

    tearDown(() => routeContextController.close());

    Widget buildSubject({VideoFeedState? state}) {
      when(() => videoFeedBloc.state).thenReturn(
        state ?? const VideoFeedState(status: VideoFeedStatus.loading),
      );

      return testMaterialApp(
        additionalOverrides: [
          pageContextProvider.overrideWith(
            (ref) => routeContextController.stream,
          ),
        ],
        home: BlocProvider<VideoFeedBloc>.value(
          value: videoFeedBloc,
          child: VideoFeedView(controller: videoFeedController),
        ),
      );
    }

    testWidgets('calls setActive(active: false) when overlay becomes visible', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      final element = tester.element(find.byType(VideoFeedView));
      final container = ProviderScope.containerOf(element);

      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
      await tester.pump();

      verify(() => videoFeedController.setActive(active: false)).called(1);
    });

    testWidgets('calls setActive(active: false) when modal overlay opens', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      final element = tester.element(find.byType(VideoFeedView));
      final container = ProviderScope.containerOf(element);

      container.read(overlayVisibilityProvider.notifier).setModalOpen(true);
      await tester.pump();

      verify(() => videoFeedController.setActive(active: false)).called(1);
    });

    testWidgets('calls setActive(active: true) when overlay becomes hidden', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      final element = tester.element(find.byType(VideoFeedView));
      final container = ProviderScope.containerOf(element);

      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
      await tester.pump();

      clearInteractions(videoFeedController);

      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(false);
      await tester.pump();

      verify(() => videoFeedController.setActive(active: true)).called(1);
    });

    testWidgets(
      'does NOT resume when overlay closes while on a non-home route',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        final element = tester.element(find.byType(VideoFeedView));
        final container = ProviderScope.containerOf(element);

        // Emit home AFTER the widget is built so it receives it and sets
        // mountedRouteType = home.
        routeContextController.add(
          const RouteContext(type: RouteType.home, videoIndex: 0),
        );
        await tester.pump();

        clearInteractions(videoFeedController);

        // Drawer opens while still on home
        container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
        await tester.pump();

        // Settings is pushed — route changes away from home
        routeContextController.add(
          const RouteContext(type: RouteType.settings),
        );
        await tester.pump();

        clearInteractions(videoFeedController);

        // Drawer closes — must NOT resume because we're now on settings
        container.read(overlayVisibilityProvider.notifier).setDrawerOpen(false);
        await tester.pump();

        verifyNever(
          () => videoFeedController.setActive(active: any(named: 'active')),
        );
      },
    );

    testWidgets(
      'calls setActive(active: false) when navigating away from home',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        // Establish home as the starting route
        routeContextController.add(
          const RouteContext(type: RouteType.home, videoIndex: 0),
        );
        await tester.pump();

        clearInteractions(videoFeedController);

        // Navigate to Settings (e.g. via drawer tap)
        routeContextController.add(
          const RouteContext(type: RouteType.settings),
        );
        await tester.pump();

        verify(() => videoFeedController.setActive(active: false)).called(1);
      },
    );

    testWidgets('calls setActive(active: true) when returning to home', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      routeContextController.add(
        const RouteContext(type: RouteType.home, videoIndex: 0),
      );
      await tester.pump();

      routeContextController.add(const RouteContext(type: RouteType.settings));
      await tester.pump();

      clearInteractions(videoFeedController);

      // Pop Settings — return to home
      routeContextController.add(
        const RouteContext(type: RouteType.home, videoIndex: 0),
      );
      await tester.pump();

      verify(() => videoFeedController.setActive(active: true)).called(1);
    });

    testWidgets(
      'calls setActive(active: false) when navigating to camera from home',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        routeContextController.add(
          const RouteContext(type: RouteType.home, videoIndex: 0),
        );
        await tester.pump();

        clearInteractions(videoFeedController);

        routeContextController.add(
          const RouteContext(type: RouteType.videoRecorder),
        );
        await tester.pump();

        verify(() => videoFeedController.setActive(active: false)).called(1);
      },
    );

    testWidgets('does not call setActive when route type does not change', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      routeContextController.add(
        const RouteContext(type: RouteType.home, videoIndex: 0),
      );
      await tester.pump();

      clearInteractions(videoFeedController);

      // Same type, different index — swipe within feed, not a navigation
      routeContextController.add(
        const RouteContext(type: RouteType.home, videoIndex: 1),
      );
      await tester.pump();

      verifyNever(
        () => videoFeedController.setActive(active: any(named: 'active')),
      );
    });
  });
}
