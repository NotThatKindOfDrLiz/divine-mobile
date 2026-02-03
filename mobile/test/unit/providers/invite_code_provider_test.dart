// ABOUTME: Unit tests for invite code Riverpod providers
// ABOUTME: Tests hasStoredInviteCode, InviteCodeClaim, and PendingInviteCode providers

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/models/invite_code_result.dart';
import 'package:openvine/providers/invite_code_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/invite_code_repository.dart';
import 'package:openvine/services/invite_code_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Invite Code Providers', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer createContainer({
      http.Client? client,
      Map<String, Object>? initialPrefsValues,
    }) {
      if (initialPrefsValues != null) {
        SharedPreferences.setMockInitialValues(initialPrefsValues);
      }

      final mockClient =
          client ??
          MockClient((request) async {
            return http.Response('{}', 200);
          });

      final repository = InviteCodeRepository(prefs);
      final service = InviteCodeService(
        client: mockClient,
        repository: repository,
        prefs: prefs,
      );

      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          inviteCodeRepositoryProvider.overrideWithValue(repository),
          inviteCodeServiceProvider.overrideWithValue(service),
        ],
      );
    }

    group('hasStoredInviteCodeProvider', () {
      test('returns false when no code is stored', () async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        final container = createContainer();
        final hasCode = container.read(hasStoredInviteCodeProvider);

        expect(hasCode, isFalse);
        container.dispose();
      });

      test('returns true when code is stored', () async {
        SharedPreferences.setMockInitialValues({
          InviteCodeRepository.inviteCodeKey: 'ABCD1234',
        });
        prefs = await SharedPreferences.getInstance();

        final container = createContainer();
        final hasCode = container.read(hasStoredInviteCodeProvider);

        expect(hasCode, isTrue);
        container.dispose();
      });
    });

    group('InviteCodeClaim', () {
      test('initial state is AsyncData(null)', () async {
        final container = createContainer();
        final state = container.read(inviteCodeClaimProvider);

        expect(state, isA<AsyncData<InviteCodeResult?>>());
        expect(state.value, isNull);
        container.dispose();
      });

      test('claimCode sets loading state then data on success', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'valid': true, 'code': 'TEST1234'}),
            200,
          );
        });

        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        final container = createContainer(client: mockClient);
        final notifier = container.read(inviteCodeClaimProvider.notifier);

        // Start claiming
        final future = notifier.claimCode('TEST1234');

        // Check loading state
        expect(
          container.read(inviteCodeClaimProvider),
          isA<AsyncLoading<InviteCodeResult?>>(),
        );

        // Wait for completion
        final result = await future;

        expect(result.valid, isTrue);
        expect(result.code, equals('TEST1234'));

        // Check final state
        final state = container.read(inviteCodeClaimProvider);
        expect(state, isA<AsyncData<InviteCodeResult?>>());
        expect(state.value?.valid, isTrue);

        container.dispose();
      });

      test('claimCode invalidates hasStoredInviteCode on success', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'valid': true, 'code': 'TEST1234'}),
            200,
          );
        });

        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        final container = createContainer(client: mockClient);

        // Initially no code stored
        expect(container.read(hasStoredInviteCodeProvider), isFalse);

        // Claim a code
        await container
            .read(inviteCodeClaimProvider.notifier)
            .claimCode('TEST1234');

        // hasStoredInviteCode should now be true
        expect(container.read(hasStoredInviteCodeProvider), isTrue);

        container.dispose();
      });

      test('claimCode sets error state on failure', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        final container = createContainer(client: mockClient);
        final notifier = container.read(inviteCodeClaimProvider.notifier);

        // Claim should throw
        await expectLater(
          () => notifier.claimCode('TEST1234'),
          throwsA(isA<InviteCodeException>()),
        );

        // Check error state
        final state = container.read(inviteCodeClaimProvider);
        expect(state, isA<AsyncError<InviteCodeResult?>>());

        container.dispose();
      });

      test('reset() clears state to AsyncData(null)', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'valid': true, 'code': 'TEST1234'}),
            200,
          );
        });

        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        final container = createContainer(client: mockClient);
        final notifier = container.read(inviteCodeClaimProvider.notifier);

        // Claim a code first
        await notifier.claimCode('TEST1234');

        // State should have the result
        expect(container.read(inviteCodeClaimProvider).value?.valid, isTrue);

        // Reset
        notifier.reset();

        // State should be null
        expect(container.read(inviteCodeClaimProvider).value, isNull);

        container.dispose();
      });
    });

    group('PendingInviteCode', () {
      test('initial state is null', () async {
        final container = createContainer();
        final pendingCode = container.read(pendingInviteCodeProvider);

        expect(pendingCode, isNull);
        container.dispose();
      });

      test('setCode stores normalized code', () async {
        final container = createContainer();
        final notifier = container.read(pendingInviteCodeProvider.notifier);

        notifier.setCode('  abcd1234  ');

        final pendingCode = container.read(pendingInviteCodeProvider);
        expect(pendingCode, equals('ABCD1234'));

        container.dispose();
      });

      test('clear() removes pending code', () async {
        final container = createContainer();
        final notifier = container.read(pendingInviteCodeProvider.notifier);

        notifier.setCode('ABCD1234');
        expect(container.read(pendingInviteCodeProvider), equals('ABCD1234'));

        notifier.clear();
        expect(container.read(pendingInviteCodeProvider), isNull);

        container.dispose();
      });
    });

    group('inviteCodeVerificationProvider', () {
      test('returns invalid when no code stored', () async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        final container = createContainer();
        final result = await container.read(
          inviteCodeVerificationProvider.future,
        );

        expect(result.valid, isFalse);
        expect(result.message, equals('No invite code stored'));

        container.dispose();
      });

      test('verifies stored code with server', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, contains('/v1/validate-invite'));
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['code'], equals('STORED12'));

          return http.Response(
            jsonEncode({'valid': true, 'code': 'STORED12'}),
            200,
          );
        });

        SharedPreferences.setMockInitialValues({
          InviteCodeRepository.inviteCodeKey: 'STORED12',
        });
        prefs = await SharedPreferences.getInstance();

        final container = createContainer(client: mockClient);
        final result = await container.read(
          inviteCodeVerificationProvider.future,
        );

        expect(result.valid, isTrue);
        expect(result.code, equals('STORED12'));

        container.dispose();
      });

      test('clears stored code when verification fails', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'valid': false, 'message': 'Code revoked'}),
            200,
          );
        });

        SharedPreferences.setMockInitialValues({
          InviteCodeRepository.inviteCodeKey: 'REVOKED1',
        });
        prefs = await SharedPreferences.getInstance();

        final container = createContainer(client: mockClient);

        // Initially code is stored
        expect(container.read(hasStoredInviteCodeProvider), isTrue);

        // Verify (which should fail and clear)
        final result = await container.read(
          inviteCodeVerificationProvider.future,
        );

        expect(result.valid, isFalse);

        // Invalidate the cached provider to get fresh state
        // (In real app, router refresh would do this)
        container.invalidate(hasStoredInviteCodeProvider);

        // Code should be cleared
        expect(container.read(hasStoredInviteCodeProvider), isFalse);

        container.dispose();
      });
    });
  });
}
