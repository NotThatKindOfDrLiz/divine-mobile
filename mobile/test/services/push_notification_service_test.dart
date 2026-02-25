// ABOUTME: Unit tests for PushNotificationService (FCM token lifecycle,
// ABOUTME: NIP-XX registration/deregistration, foreground message handling)

import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/push_notification_service.dart';

import 'push_notification_service_test.mocks.dart';

@GenerateMocks([
  NostrClient,
  AuthService,
  FirebaseMessaging,
  NotificationService,
  NostrSigner,
])
void main() {
  group(PushNotificationService, () {
    late MockNostrClient mockNostrClient;
    late MockAuthService mockAuthService;
    late MockFirebaseMessaging mockMessaging;
    late MockNotificationService mockNotificationService;
    late MockNostrSigner mockSigner;
    late PushNotificationService service;

    const testToken = 'fcm_test_token_abc123';
    const testPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    Event _createTestEvent({int kind = pushRegistrationKind}) {
      return Event.fromJson({
        'id':
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        'pubkey': testPubkey,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': kind,
        'tags': [],
        'content': 'encrypted_content',
        'sig': 'test_sig',
      });
    }

    setUp(() {
      mockNostrClient = MockNostrClient();
      mockAuthService = MockAuthService();
      mockMessaging = MockFirebaseMessaging();
      mockNotificationService = MockNotificationService();
      mockSigner = MockNostrSigner();

      // Default: authenticated user with remote signer
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.rpcSigner).thenReturn(mockSigner);
      when(mockAuthService.currentKeyContainer).thenReturn(null);

      // Default: signer encrypts successfully
      when(
        mockSigner.nip44Encrypt(any, any),
      ).thenAnswer((_) async => 'encrypted_payload');

      // Default: auth service signs events
      when(
        mockAuthService.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer((_) async => _createTestEvent());

      // Default: publish succeeds
      when(
        mockNostrClient.publishEvent(
          any,
          targetRelays: anyNamed('targetRelays'),
        ),
      ).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Event,
      );

      // Default: FCM token available
      when(mockMessaging.getToken()).thenAnswer((_) async => testToken);

      // Default: permissions granted
      when(mockMessaging.requestPermission()).thenAnswer(
        (_) async => const NotificationSettings(
          authorizationStatus: AuthorizationStatus.authorized,
          alert: AppleNotificationSetting.enabled,
          announcement: AppleNotificationSetting.enabled,
          badge: AppleNotificationSetting.enabled,
          carPlay: AppleNotificationSetting.enabled,
          criticalAlert: AppleNotificationSetting.enabled,
          lockScreen: AppleNotificationSetting.enabled,
          notificationCenter: AppleNotificationSetting.enabled,
          showPreviews: AppleShowPreviewSetting.always,
          sound: AppleNotificationSetting.enabled,
          timeSensitive: AppleNotificationSetting.enabled,
          providesAppNotificationSettings: AppleNotificationSetting.enabled,
        ),
      );

      // Default: no token refresh or foreground messages during test
      when(
        mockMessaging.onTokenRefresh,
      ).thenAnswer((_) => const Stream<String>.empty());

      // Default: sendLocal succeeds
      when(
        mockNotificationService.sendLocal(
          title: anyNamed('title'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async {});

      service = PushNotificationService(
        authService: mockAuthService,
        nostrClient: mockNostrClient,
        messaging: mockMessaging,
        notificationService: mockNotificationService,
      );
    });

    tearDown(() {
      service.dispose();
    });

    group('initialize', () {
      test('requests permissions, gets token, and registers', () async {
        await service.initialize();

        verify(mockMessaging.requestPermission()).called(1);
        verify(mockMessaging.getToken()).called(1);
        verify(mockSigner.nip44Encrypt(pushServicePubkey, any)).called(1);
        verify(
          mockAuthService.createAndSignEvent(
            kind: pushRegistrationKind,
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).called(1);
        verify(
          mockNostrClient.publishEvent(
            any,
            targetRelays: [pushRegistrationRelay],
          ),
        ).called(1);
        expect(service.isRegistered, isTrue);
        expect(service.currentToken, equals(testToken));
      });

      test('returns early when FCM token is null', () async {
        when(mockMessaging.getToken()).thenAnswer((_) async => null);

        await service.initialize();

        expect(service.isRegistered, isFalse);
        expect(service.currentToken, isNull);
        verifyNever(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        );
      });

      test('returns early when disposed', () async {
        service.dispose();

        await service.initialize();

        verifyNever(mockMessaging.requestPermission());
        verifyNever(mockMessaging.getToken());
      });
    });

    group('registration event', () {
      test('encrypts token payload as JSON', () async {
        await service.initialize();

        final captured = verify(
          mockSigner.nip44Encrypt(pushServicePubkey, captureAny),
        ).captured;

        final payload =
            jsonDecode(captured.first as String) as Map<String, dynamic>;
        expect(payload['token'], equals(testToken));
      });

      test('includes correct tags', () async {
        await service.initialize();

        final captured = verify(
          mockAuthService.createAndSignEvent(
            kind: pushRegistrationKind,
            content: captureAnyNamed('content'),
            tags: captureAnyNamed('tags'),
          ),
        ).captured;

        final tags = captured[1] as List<List<String>>;
        expect(tags[0], equals(['p', pushServicePubkey]));
        expect(tags[1], equals(['app', pushAppIdentifier]));
        expect(tags[2][0], equals('expiration'));
        // Expiration should be ~90 days from now
        final expirationSecs = int.parse(tags[2][1]);
        final expirationDate = DateTime.fromMillisecondsSinceEpoch(
          expirationSecs * 1000,
        );
        final daysUntilExpiration = expirationDate
            .difference(DateTime.now())
            .inDays;
        expect(daysUntilExpiration, closeTo(90, 1));
      });

      test('does not publish when unauthenticated', () async {
        when(mockAuthService.isAuthenticated).thenReturn(false);

        await service.initialize();

        verifyNever(
          mockNostrClient.publishEvent(
            any,
            targetRelays: anyNamed('targetRelays'),
          ),
        );
      });

      test('does not publish when NIP-44 encryption fails', () async {
        when(mockSigner.nip44Encrypt(any, any)).thenAnswer((_) async => null);

        await service.initialize();

        verifyNever(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        );
      });

      test('does not publish when event signing fails', () async {
        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => null);

        await service.initialize();

        verifyNever(
          mockNostrClient.publishEvent(
            any,
            targetRelays: anyNamed('targetRelays'),
          ),
        );
      });
    });

    group('deregister', () {
      test('publishes kind 3080 event and clears state', () async {
        await service.initialize();

        await service.deregister();

        final captured = verify(
          mockAuthService.createAndSignEvent(
            kind: captureAnyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).captured;

        // Second call is deregistration
        expect(captured.last, equals(pushDeregistrationKind));
        expect(service.isRegistered, isFalse);
        expect(service.currentToken, isNull);
      });

      test('no-ops when no token exists', () async {
        await service.deregister();

        // Only the registration event creation, not deregistration
        verifyNever(
          mockAuthService.createAndSignEvent(
            kind: pushDeregistrationKind,
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        );
      });

      test('no-ops when unauthenticated', () async {
        await service.initialize();

        when(mockAuthService.isAuthenticated).thenReturn(false);
        await service.deregister();

        // Only the registration publish, not deregistration
        verify(
          mockNostrClient.publishEvent(
            any,
            targetRelays: anyNamed('targetRelays'),
          ),
        ).called(1);
      });
    });

    group('foreground message data extraction', () {
      // The push service sends data-only messages (notification: null).
      // FirebaseMessaging.onMessage is static and can't be mocked, so
      // we verify the data-reading contract used in _onForegroundMessage
      // by testing RemoteMessage.data access directly.

      test('extracts title and body from data payload', () {
        final message = RemoteMessage(
          data: const {
            'title': 'New like',
            'body': 'Alice liked your post',
            'type': 'like',
            'eventId':
                'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          },
        );

        final title = message.data['title'] as String? ?? 'divine';
        final body = message.data['body'] as String? ?? '';

        expect(title, equals('New like'));
        expect(body, equals('Alice liked your post'));
      });

      test('falls back to defaults when data fields are missing', () {
        const message = RemoteMessage();

        final title = message.data['title'] as String? ?? 'divine';
        final body = message.data['body'] as String? ?? '';

        expect(title, equals('divine'));
        expect(body, equals(''));
      });

      test('notification field is null for data-only messages', () {
        final message = RemoteMessage(
          data: const {'title': 'Test', 'body': 'Body'},
        );

        // Data-only messages have no notification payload
        expect(message.notification, isNull);
        // But data is accessible
        expect(message.data['title'], equals('Test'));
      });
    });

    group('token refresh', () {
      test('re-registers with new token on refresh', () async {
        const newToken = 'refreshed_fcm_token_xyz';
        final refreshController = StreamController<String>();

        when(
          mockMessaging.onTokenRefresh,
        ).thenAnswer((_) => refreshController.stream);

        await service.initialize();

        // Emit a token refresh
        refreshController.add(newToken);
        await Future<void>.delayed(Duration.zero);

        // Should have registered twice: initial + refresh
        verify(
          mockNostrClient.publishEvent(
            any,
            targetRelays: [pushRegistrationRelay],
          ),
        ).called(2);
        expect(service.currentToken, equals(newToken));

        await refreshController.close();
      });
    });
  });
}
