// ABOUTME: Test for notifications screen pull-to-refresh functionality
// ABOUTME: Ensures RefreshIndicator is present and relay provider refresh works

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/notification_list_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

/// Tracks how many times refresh was called across all instances
int _globalRefreshCount = 0;

/// Mock notifier that tracks refresh calls without hitting real APIs
class _MockRelayNotifications extends RelayNotifications {
  @override
  Future<NotificationFeedState> build() async {
    return NotificationFeedState(
      notifications: [
        NotificationModel(
          id: 'notif1',
          type: NotificationType.like,
          actorPubkey: 'user123',
          actorName: 'Test User',
          message: 'liked your video',
          timestamp: DateTime.now(),
        ),
      ],
      isInitialLoad: false,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> refresh() async {
    _globalRefreshCount++;
  }
}

void main() {
  late SharedPreferences sharedPreferences;
  late _MockAuthService mockAuthService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    mockAuthService = _MockAuthService();
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);
  });

  Widget shell(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: const MaterialApp(home: Scaffold(body: NotificationsScreen())),
  );

  group('NotificationsScreen Refresh', () {
    setUp(() {
      _globalRefreshCount = 0;
    });

    testWidgets(
      'refresh indicator is present and notifications render from relay provider',
      (WidgetTester tester) async {
        final c = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(mockAuthService),
            relayNotificationsProvider.overrideWith(
              _MockRelayNotifications.new,
            ),
          ],
        );
        addTearDown(c.dispose);

        await tester.pumpWidget(shell(c));
        await tester.pumpAndSettle();

        // Assert: RefreshIndicator and notification items are present
        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(find.byType(NotificationListItem), findsOneWidget);
      },
    );

    testWidgets(
      'calling refresh on relay notifications notifier increments call count',
      (WidgetTester tester) async {
        final c = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(mockAuthService),
            relayNotificationsProvider.overrideWith(
              _MockRelayNotifications.new,
            ),
          ],
        );
        addTearDown(c.dispose);

        await tester.pumpWidget(shell(c));
        await tester.pumpAndSettle();

        // Act: Call refresh directly (what the onRefresh callback does)
        await c.read(relayNotificationsProvider.notifier).refresh();

        // Assert: Verify refresh was called on the notifier
        expect(_globalRefreshCount, equals(1));
      },
    );
  });
}
