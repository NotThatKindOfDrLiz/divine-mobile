// ABOUTME: Unit tests for InviteCodeResult model
// ABOUTME: Tests JSON parsing and default values

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/invite_code_result.dart';

void main() {
  group('InviteCodeResult', () {
    group('fromJson', () {
      test('parses valid response with all fields', () {
        final json = {
          'valid': true,
          'message': 'Invite code claimed successfully',
          'code': 'ABCD1234',
          'claimedAt': '2026-02-02T10:30:00Z',
        };

        final result = InviteCodeResult.fromJson(json);

        expect(result.valid, isTrue);
        expect(result.message, equals('Invite code claimed successfully'));
        expect(result.code, equals('ABCD1234'));
        expect(result.claimedAt, isA<DateTime>());
        expect(result.claimedAt!.year, equals(2026));
        expect(result.claimedAt!.month, equals(2));
        expect(result.claimedAt!.day, equals(2));
      });

      test('parses minimal valid response', () {
        final json = {'valid': true};

        final result = InviteCodeResult.fromJson(json);

        expect(result.valid, isTrue);
        expect(result.message, isNull);
        expect(result.code, isNull);
        expect(result.claimedAt, isNull);
      });

      test('parses invalid code response', () {
        final json = {'valid': false, 'message': 'Invalid invite code'};

        final result = InviteCodeResult.fromJson(json);

        expect(result.valid, isFalse);
        expect(result.message, equals('Invalid invite code'));
        expect(result.code, isNull);
      });

      test('defaults valid to false when missing', () {
        final json = <String, dynamic>{};

        final result = InviteCodeResult.fromJson(json);

        expect(result.valid, isFalse);
      });

      test('defaults valid to false when null', () {
        final json = {'valid': null};

        final result = InviteCodeResult.fromJson(json);

        expect(result.valid, isFalse);
      });

      test('handles claimedAt with different ISO formats', () {
        // With timezone offset
        final json1 = {'valid': true, 'claimedAt': '2026-02-02T10:30:00+00:00'};
        final result1 = InviteCodeResult.fromJson(json1);
        expect(result1.claimedAt, isA<DateTime>());

        // Without timezone (UTC assumed)
        final json2 = {'valid': true, 'claimedAt': '2026-02-02T10:30:00Z'};
        final result2 = InviteCodeResult.fromJson(json2);
        expect(result2.claimedAt, isA<DateTime>());
      });

      test('handles null claimedAt gracefully', () {
        final json = {'valid': true, 'claimedAt': null};

        final result = InviteCodeResult.fromJson(json);

        expect(result.claimedAt, isNull);
      });
    });

    group('constructor', () {
      test('creates instance with required valid field', () {
        const result = InviteCodeResult(valid: true);

        expect(result.valid, isTrue);
        expect(result.message, isNull);
        expect(result.code, isNull);
        expect(result.claimedAt, isNull);
      });

      test('creates instance with all fields', () {
        final claimedAt = DateTime(2026, 2, 2, 10, 30);
        final result = InviteCodeResult(
          valid: true,
          message: 'Success',
          code: 'TEST1234',
          claimedAt: claimedAt,
        );

        expect(result.valid, isTrue);
        expect(result.message, equals('Success'));
        expect(result.code, equals('TEST1234'));
        expect(result.claimedAt, equals(claimedAt));
      });

      test('can be const constructed', () {
        const result = InviteCodeResult(valid: false, message: 'Error');

        expect(result.valid, isFalse);
        expect(result.message, equals('Error'));
      });
    });
  });
}
