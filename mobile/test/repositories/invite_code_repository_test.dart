// ABOUTME: Tests for InviteCodeRepository
// ABOUTME: Verifies SharedPreferences-backed invite code storage operations

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/repositories/invite_code_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(InviteCodeRepository, () {
    late SharedPreferences prefs;
    late InviteCodeRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = InviteCodeRepository(prefs);
    });

    group('storedCode', () {
      test('returns null when no code is stored', () {
        expect(repository.storedCode, isNull);
      });

      test('returns stored code after saveCode', () async {
        await repository.saveCode('ABCD1234');

        expect(repository.storedCode, equals('ABCD1234'));
      });
    });

    group('hasStoredCode', () {
      test('returns false when no code is stored', () {
        expect(repository.hasStoredCode, isFalse);
      });

      test('returns true after saveCode', () async {
        await repository.saveCode('ABCD1234');

        expect(repository.hasStoredCode, isTrue);
      });

      test('returns false after clearCode', () async {
        await repository.saveCode('ABCD1234');
        await repository.clearCode();

        expect(repository.hasStoredCode, isFalse);
      });
    });

    group('saveCode', () {
      test('persists the code to SharedPreferences', () async {
        final saved = await repository.saveCode('WXYZ5678');

        expect(saved, isTrue);
        expect(
          prefs.getString(InviteCodeRepository.inviteCodeKey),
          equals('WXYZ5678'),
        );
      });

      test('overwrites previously stored code', () async {
        await repository.saveCode('FIRST001');
        await repository.saveCode('SECOND02');

        expect(repository.storedCode, equals('SECOND02'));
      });
    });

    group('clearCode', () {
      test('removes the stored code', () async {
        await repository.saveCode('ABCD1234');
        final cleared = await repository.clearCode();

        expect(cleared, isTrue);
        expect(repository.storedCode, isNull);
      });

      test('returns true even when no code was stored', () async {
        final cleared = await repository.clearCode();

        expect(cleared, isTrue);
      });
    });
  });
}
