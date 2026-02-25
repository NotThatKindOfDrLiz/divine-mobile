// ABOUTME: Tests for NpubVerificationRepository
// ABOUTME: Verifies per-npub verification status storage in SharedPreferences

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/repositories/npub_verification_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(NpubVerificationRepository, () {
    late SharedPreferences prefs;
    late NpubVerificationRepository repository;

    const testNpub = 'npub1testpubkey1234567890abcdef';
    const otherNpub = 'npub1otherpubkey0987654321fedcba';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = NpubVerificationRepository(prefs);
    });

    group('isVerified', () {
      test('returns false for unknown npub', () {
        expect(repository.isVerified(testNpub), isFalse);
      });

      test('returns true after setVerified', () async {
        await repository.setVerified(testNpub);

        expect(repository.isVerified(testNpub), isTrue);
      });

      test(
        'returns false for different npub when only one is verified',
        () async {
          await repository.setVerified(testNpub);

          expect(repository.isVerified(otherNpub), isFalse);
        },
      );

      test('returns true for each individually verified npub', () async {
        await repository.setVerified(testNpub);
        await repository.setVerified(otherNpub);

        expect(repository.isVerified(testNpub), isTrue);
        expect(repository.isVerified(otherNpub), isTrue);
      });
    });

    group('setVerified', () {
      test('persists verification to SharedPreferences', () async {
        final result = await repository.setVerified(testNpub);

        expect(result, isTrue);
        expect(prefs.getBool('npub_verified_$testNpub'), isTrue);
      });
    });

    group('clearVerification', () {
      test('removes verification for the given npub', () async {
        await repository.setVerified(testNpub);
        final result = await repository.clearVerification(testNpub);

        expect(result, isTrue);
        expect(repository.isVerified(testNpub), isFalse);
      });

      test('does not affect other npub verifications', () async {
        await repository.setVerified(testNpub);
        await repository.setVerified(otherNpub);

        await repository.clearVerification(testNpub);

        expect(repository.isVerified(testNpub), isFalse);
        expect(repository.isVerified(otherNpub), isTrue);
      });

      test('returns true even when npub was not verified', () async {
        final result = await repository.clearVerification(testNpub);

        expect(result, isTrue);
      });
    });
  });
}
