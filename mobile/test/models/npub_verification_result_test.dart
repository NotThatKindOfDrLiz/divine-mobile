// ABOUTME: Tests for NpubVerificationResult model
// ABOUTME: Verifies fromJson, toJson, constructor, and toString

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/npub_verification_result.dart';

void main() {
  group(NpubVerificationResult, () {
    group('constructor', () {
      test('creates instance with required valid field', () {
        const result = NpubVerificationResult(valid: true);

        expect(result.valid, isTrue);
        expect(result.message, isNull);
      });

      test('creates instance with valid and message', () {
        const result = NpubVerificationResult(
          valid: false,
          message: 'Not authorized',
        );

        expect(result.valid, isFalse);
        expect(result.message, equals('Not authorized'));
      });
    });

    group('fromJson', () {
      test('parses valid true with message', () {
        final result = NpubVerificationResult.fromJson({
          'valid': true,
          'message': 'Verified successfully',
        });

        expect(result.valid, isTrue);
        expect(result.message, equals('Verified successfully'));
      });

      test('parses valid false with message', () {
        final result = NpubVerificationResult.fromJson({
          'valid': false,
          'message': 'Not found',
        });

        expect(result.valid, isFalse);
        expect(result.message, equals('Not found'));
      });

      test('defaults valid to false when missing', () {
        final result = NpubVerificationResult.fromJson({
          'message': 'Some message',
        });

        expect(result.valid, isFalse);
        expect(result.message, equals('Some message'));
      });

      test('defaults message to null when missing', () {
        final result = NpubVerificationResult.fromJson({'valid': true});

        expect(result.valid, isTrue);
        expect(result.message, isNull);
      });

      test('handles empty json map', () {
        final result = NpubVerificationResult.fromJson({});

        expect(result.valid, isFalse);
        expect(result.message, isNull);
      });
    });

    group('toJson', () {
      test('includes valid and message when message is non-null', () {
        const result = NpubVerificationResult(valid: true, message: 'OK');

        expect(result.toJson(), equals({'valid': true, 'message': 'OK'}));
      });

      test('excludes message when null', () {
        const result = NpubVerificationResult(valid: false);

        expect(result.toJson(), equals({'valid': false}));
      });
    });

    group('toString', () {
      test('includes valid and message', () {
        const result = NpubVerificationResult(valid: true, message: 'Verified');

        expect(
          result.toString(),
          equals('NpubVerificationResult(valid: true, message: Verified)'),
        );
      });

      test('includes null message', () {
        const result = NpubVerificationResult(valid: false);

        expect(
          result.toString(),
          equals('NpubVerificationResult(valid: false, message: null)'),
        );
      });
    });
  });
}
