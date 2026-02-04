// ABOUTME: Unit tests for invite code Riverpod providers
// ABOUTME: Tests hasStoredInviteCode and inviteCodeVerification providers
// NOTE: InviteCodeClaim and PendingInviteCode are now tested via InviteCodeBloc tests

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
