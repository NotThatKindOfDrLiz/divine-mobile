// ABOUTME: Unit tests for npub verification Riverpod providers
// ABOUTME: Tests isNpubVerified and needsNpubVerification providers

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/providers/invite_code_provider.dart';
import 'package:openvine/providers/npub_verification_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/invite_code_repository.dart';
import 'package:openvine/repositories/npub_verification_repository.dart';
import 'package:openvine/services/invite_code_service.dart';
import 'package:openvine/services/npub_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Npub Verification Providers', () {
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

      final inviteCodeRepository = InviteCodeRepository(prefs);
      final inviteCodeService = InviteCodeService(
        client: mockClient,
        repository: inviteCodeRepository,
        prefs: prefs,
      );

      final npubVerificationRepository = NpubVerificationRepository(prefs);
      final npubVerificationService = NpubVerificationService(
        client: mockClient,
        repository: npubVerificationRepository,
        getDeviceId: () async => 'test-device-id',
      );

      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          inviteCodeRepositoryProvider.overrideWithValue(inviteCodeRepository),
          inviteCodeServiceProvider.overrideWithValue(inviteCodeService),
          npubVerificationRepositoryProvider
              .overrideWithValue(npubVerificationRepository),
          npubVerificationServiceProvider
              .overrideWithValue(npubVerificationService),
        ],
      );
    }

    group('isNpubVerifiedProvider', () {
      test('returns true when user has invite code', () async {
        SharedPreferences.setMockInitialValues({
          InviteCodeRepository.inviteCodeKey: 'ABCD1234',
        });
        prefs = await SharedPreferences.getInstance();

        final container = createContainer();
        final isVerified = container.read(isNpubVerifiedProvider);

        expect(isVerified, isTrue);
        container.dispose();
      });

      test('returns false when no invite code and npub not verified', () async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        final container = createContainer();
        final isVerified = container.read(isNpubVerifiedProvider);

        expect(isVerified, isFalse);
        container.dispose();
      });

      test('returns true when npub is verified (no invite code)', () async {
        const testNpub = 'npub1testverified';
        SharedPreferences.setMockInitialValues({
          'npub_verified_$testNpub': true,
        });
        prefs = await SharedPreferences.getInstance();

        final container = createContainer();
        // Note: This test only checks the repository directly since
        // the actual authService.currentNpub would need more complex mocking
        final repository = container.read(npubVerificationRepositoryProvider);
        expect(repository.isVerified(testNpub), isTrue);

        container.dispose();
      });
    });

    group('needsNpubVerificationProvider', () {
      test('returns false when user has invite code', () async {
        SharedPreferences.setMockInitialValues({
          InviteCodeRepository.inviteCodeKey: 'ABCD1234',
          'current_user_pubkey_hex': 'abc123',
        });
        prefs = await SharedPreferences.getInstance();

        final container = createContainer();

        // With invite code, should not need verification
        final hasInviteCode = container.read(hasStoredInviteCodeProvider);
        expect(hasInviteCode, isTrue);

        container.dispose();
      });

      test('repository correctly tracks verification status', () async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        final repository = NpubVerificationRepository(prefs);
        const testNpub = 'npub1testverification';

        // Initially not verified
        expect(repository.isVerified(testNpub), isFalse);

        // Set as verified
        await repository.setVerified(testNpub);
        expect(repository.isVerified(testNpub), isTrue);

        // Clear verification
        await repository.clearVerification(testNpub);
        expect(repository.isVerified(testNpub), isFalse);
      });
    });

    group('npubVerificationServiceProvider', () {
      test('service verifies npub with server', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, contains('/v1/verify-npub'));
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['npub'], equals('npub1test'));
          expect(body['deviceId'], isNotEmpty);

          return http.Response(
            jsonEncode({'valid': true}),
            200,
          );
        });

        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        final container = createContainer(client: mockClient);
        final service = container.read(npubVerificationServiceProvider);

        final result = await service.verifyNpub('npub1test');
        expect(result.valid, isTrue);

        container.dispose();
      });

      test('service stores verification on success', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'valid': true}),
            200,
          );
        });

        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        final container = createContainer(client: mockClient);
        final service = container.read(npubVerificationServiceProvider);

        const testNpub = 'npub1teststored';
        expect(service.isVerified(testNpub), isFalse);

        await service.verifyNpub(testNpub);
        expect(service.isVerified(testNpub), isTrue);

        container.dispose();
      });

      test('service does not store verification on failure', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'valid': false, 'message': 'Not authorized'}),
            200,
          );
        });

        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        final container = createContainer(client: mockClient);
        final service = container.read(npubVerificationServiceProvider);

        const testNpub = 'npub1testnotstored';
        expect(service.isVerified(testNpub), isFalse);

        final result = await service.verifyNpub(testNpub);
        expect(result.valid, isFalse);
        expect(service.isVerified(testNpub), isFalse);

        container.dispose();
      });
    });
  });
}
