// ABOUTME: Tests for InviteCodeService
// ABOUTME: Verifies API calls for validate and claim with mocked HTTP client

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/invite_code_service.dart';

void main() {
  group(InviteCodeService, () {
    group('validateCode', () {
      test('returns valid result on 200 with valid=true', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, equals('/v1/validate'));
          expect(request.method, equals('POST'));

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['code'], equals('ABCD-1234'));

          return http.Response(
            jsonEncode({
              'valid': true,
              'message': 'Code is valid',
              'code': 'ABCD-1234',
              'remaining_uses': 3,
            }),
            200,
          );
        });

        final service = InviteCodeService(client: mockClient);
        final result = await service.validateCode('ABCD-1234');

        expect(result.valid, isTrue);
        expect(result.message, equals('Code is valid'));
        expect(result.code, equals('ABCD-1234'));
        expect(result.remainingUses, equals(3));
      });

      test('returns invalid result on 200 with valid=false', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'valid': false,
              'message': 'Code has been used',
              'code': 'USED-0001',
              'remaining_uses': 0,
            }),
            200,
          );
        });

        final service = InviteCodeService(client: mockClient);
        final result = await service.validateCode('USED-0001');

        expect(result.valid, isFalse);
        expect(result.message, equals('Code has been used'));
      });

      test('returns invalid result on non-200 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Not found'}),
            404,
          );
        });

        final service = InviteCodeService(client: mockClient);
        final result = await service.validateCode('BADC-ODE1');

        expect(result.valid, isFalse);
        expect(result.message, equals('Not found'));
        expect(result.code, equals('BADC-ODE1'));
      });

      test(
        'returns invalid result with default message on non-200 '
        'with unparseable body',
        () async {
          final mockClient = MockClient((request) async {
            return http.Response('Internal Server Error', 500);
          });

          final service = InviteCodeService(client: mockClient);
          final result = await service.validateCode('TEST-0001');

          expect(result.valid, isFalse);
          expect(result.message, equals('Code not found. Please try again.'));
        },
      );

      test('throws $InviteCodeException on network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Connection refused');
        });

        final service = InviteCodeService(client: mockClient);

        expect(
          () => service.validateCode('TEST-0001'),
          throwsA(isA<InviteCodeException>()),
        );
      });
    });

    group('claimCode', () {
      test('delegates to validateCode and returns valid result', () async {
        final mockClient = MockClient((request) async {
          // claimCode delegates to validateCode, so hits /v1/validate
          expect(request.url.path, equals('/v1/validate'));
          expect(request.method, equals('POST'));

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['code'], equals('CLAM-0001'));

          return http.Response(
            jsonEncode({
              'valid': true,
              'message': 'Code is valid',
              'code': 'CLAM-0001',
              'remaining_uses': 1,
            }),
            200,
          );
        });

        final service = InviteCodeService(client: mockClient);
        final result = await service.claimCode('CLAM-0001');

        expect(result.valid, isTrue);
        expect(result.message, equals('Code is valid'));
        expect(result.code, equals('CLAM-0001'));
        expect(result.remainingUses, equals(1));
      });

      test('returns invalid result when code is invalid', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'valid': false,
              'message': 'Code already claimed',
            }),
            200,
          );
        });

        final service = InviteCodeService(client: mockClient);
        final result = await service.claimCode('USED-0002');

        expect(result.valid, isFalse);
        expect(result.message, equals('Code already claimed'));
      });

      test('throws $InviteCodeException on network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Socket closed');
        });

        final service = InviteCodeService(client: mockClient);

        expect(
          () => service.claimCode('TEST-0002'),
          throwsA(isA<InviteCodeException>()),
        );
      });
    });

    group('normalizeCode', () {
      test('uppercases and formats with hyphen', () {
        expect(
          InviteCodeService.normalizeCode('abcd1234'),
          equals('ABCD-1234'),
        );
      });

      test('strips non-alphanumeric characters', () {
        expect(
          InviteCodeService.normalizeCode('ab-cd-12-34'),
          equals('ABCD-1234'),
        );
      });

      test('handles short codes without hyphen', () {
        expect(InviteCodeService.normalizeCode('abc'), equals('ABC'));
      });

      test('truncates to 8 alphanumeric characters', () {
        expect(
          InviteCodeService.normalizeCode('ABCDEFGHIJ'),
          equals('ABCD-EFGH'),
        );
      });
    });

    group('looksLikeInviteCode', () {
      test('returns true for valid XXXX-XXXX format', () {
        expect(InviteCodeService.looksLikeInviteCode('ABCD-1234'), isTrue);
      });

      test('returns true for lowercase input', () {
        expect(InviteCodeService.looksLikeInviteCode('abcd1234'), isTrue);
      });

      test('returns false for short input', () {
        expect(InviteCodeService.looksLikeInviteCode('ABC'), isFalse);
      });

      test('returns false for empty input', () {
        expect(InviteCodeService.looksLikeInviteCode(''), isFalse);
      });
    });

    group('validateCode used detection', () {
      test('returns "Code already redeemed." when used flag is set', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Code used', 'used': true}),
            404,
          );
        });

        final service = InviteCodeService(client: mockClient);
        final result = await service.validateCode('USED-0003');

        expect(result.valid, isFalse);
        expect(result.message, equals('Code already redeemed.'));
      });
    });

    group('$InviteCodeException', () {
      test('toString includes message and status code', () {
        const exception = InviteCodeException(
          'Test error',
          statusCode: 500,
        );

        expect(
          exception.toString(),
          equals('InviteCodeException: Test error (status: 500)'),
        );
      });

      test('toString handles null status code', () {
        const exception = InviteCodeException('No status');

        expect(
          exception.toString(),
          equals('InviteCodeException: No status (status: none)'),
        );
      });
    });
  });
}
