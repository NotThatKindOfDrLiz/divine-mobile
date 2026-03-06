// ABOUTME: Tests for InviteCodeResult model
// ABOUTME: Verifies fromJson parsing for valid, invalid, and edge-case inputs

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/invite_code_result.dart';

void main() {
  group(InviteCodeResult, () {
    group('fromJson', () {
      test('parses valid response with all fields', () {
        final json = <String, dynamic>{
          'valid': true,
          'message': 'Code accepted',
          'code': 'DIVINE-2024',
          'remaining_uses': 5,
        };

        final result = InviteCodeResult.fromJson(json);

        expect(result.valid, isTrue);
        expect(result.message, equals('Code accepted'));
        expect(result.code, equals('DIVINE-2024'));
        expect(result.remainingUses, equals(5));
      });

      test('parses invalid response with valid=false', () {
        final json = <String, dynamic>{
          'valid': false,
          'message': 'Code has expired',
          'code': 'EXPIRED-CODE',
          'remaining_uses': 0,
        };

        final result = InviteCodeResult.fromJson(json);

        expect(result.valid, isFalse);
        expect(result.message, equals('Code has expired'));
        expect(result.code, equals('EXPIRED-CODE'));
        expect(result.remainingUses, equals(0));
      });

      test('defaults valid to false when missing', () {
        final json = <String, dynamic>{
          'message': 'Some message',
        };

        final result = InviteCodeResult.fromJson(json);

        expect(result.valid, isFalse);
      });

      test('handles missing optional fields as null', () {
        final json = <String, dynamic>{
          'valid': true,
        };

        final result = InviteCodeResult.fromJson(json);

        expect(result.valid, isTrue);
        expect(result.message, isNull);
        expect(result.code, isNull);
        expect(result.remainingUses, isNull);
      });

      test('handles empty JSON map', () {
        final json = <String, dynamic>{};

        final result = InviteCodeResult.fromJson(json);

        expect(result.valid, isFalse);
        expect(result.message, isNull);
        expect(result.code, isNull);
        expect(result.remainingUses, isNull);
      });

      test('parses response with only valid field', () {
        final json = <String, dynamic>{
          'valid': true,
        };

        final result = InviteCodeResult.fromJson(json);

        expect(result.valid, isTrue);
        expect(result.message, isNull);
      });
    });

    group('equality', () {
      test('two results with same values are equal', () {
        const result1 = InviteCodeResult(
          valid: true,
          message: 'OK',
          code: 'ABC',
          remainingUses: 3,
        );
        const result2 = InviteCodeResult(
          valid: true,
          message: 'OK',
          code: 'ABC',
          remainingUses: 3,
        );

        expect(result1, equals(result2));
      });

      test('two results with different values are not equal', () {
        const result1 = InviteCodeResult(valid: true, code: 'ABC');
        const result2 = InviteCodeResult(valid: false, code: 'ABC');

        expect(result1, isNot(equals(result2)));
      });
    });

    group('props', () {
      test('contains all fields', () {
        const result = InviteCodeResult(
          valid: true,
          message: 'OK',
          code: 'ABC',
          remainingUses: 3,
        );

        expect(result.props, equals([true, 'OK', 'ABC', 3]));
      });

      test('contains null for missing optional fields', () {
        const result = InviteCodeResult(valid: false);

        expect(result.props, equals([false, null, null, null]));
      });
    });
  });
}
