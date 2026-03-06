// ABOUTME: Tests for InviteCodeRepository
// ABOUTME: Verifies SharedPreferences-backed invite code persistence

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/repositories/invite_code_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(InviteCodeRepository, () {
    late InviteCodeRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repository = InviteCodeRepository(prefs: prefs);
    });

    group('hasClaimedCode', () {
      test('returns false when no code has been claimed', () {
        expect(repository.hasClaimedCode, isFalse);
      });

      test('returns true after a code has been claimed', () async {
        await repository.setClaimedCode('DIVINE-2024');

        expect(repository.hasClaimedCode, isTrue);
      });

      test('returns false after clear is called', () async {
        await repository.setClaimedCode('DIVINE-2024');
        await repository.clear();

        expect(repository.hasClaimedCode, isFalse);
      });
    });

    group('setClaimedCode', () {
      test('persists the claimed code flag', () async {
        await repository.setClaimedCode('TEST-CODE-123');

        expect(repository.hasClaimedCode, isTrue);
      });

      test('persists the code value in SharedPreferences', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = InviteCodeRepository(prefs: prefs);

        await repo.setClaimedCode('MY-CODE');

        expect(prefs.getString('invite_code_value'), equals('MY-CODE'));
        expect(prefs.getBool('invite_code_claimed'), isTrue);
      });

      test('overwrites previously claimed code', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = InviteCodeRepository(prefs: prefs);

        await repo.setClaimedCode('FIRST-CODE');
        await repo.setClaimedCode('SECOND-CODE');

        expect(prefs.getString('invite_code_value'), equals('SECOND-CODE'));
        expect(repo.hasClaimedCode, isTrue);
      });
    });

    group('clear', () {
      test('removes claimed code flag', () async {
        await repository.setClaimedCode('CODE');
        await repository.clear();

        expect(repository.hasClaimedCode, isFalse);
      });

      test('removes code value from SharedPreferences', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = InviteCodeRepository(prefs: prefs);

        await repo.setClaimedCode('CODE');
        await repo.clear();

        expect(prefs.getString('invite_code_value'), isNull);
        expect(prefs.getBool('invite_code_claimed'), isNull);
      });

      test('is safe to call when no code has been claimed', () async {
        await repository.clear();

        expect(repository.hasClaimedCode, isFalse);
      });
    });
  });
}
