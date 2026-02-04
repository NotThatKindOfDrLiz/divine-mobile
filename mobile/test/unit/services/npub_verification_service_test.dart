// ABOUTME: Unit tests for NpubVerificationService
// ABOUTME: Tests verify npub, device ID usage, and error handling with mocked HTTP

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/repositories/npub_verification_repository.dart';
import 'package:openvine/services/npub_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NpubVerificationService', () {
    late SharedPreferences prefs;
    late NpubVerificationRepository repository;
    late List<http.Request> capturedRequests;
    const testNpub = 'npub1test1234567890abcdef';
    const testDeviceId = 'test-device-id-123';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = NpubVerificationRepository(prefs);
      capturedRequests = [];
    });

    group('verifyNpub', () {
      test('sends correct request to verify endpoint', () async {
        final mockClient = MockClient((request) async {
          capturedRequests.add(request);
          return http.Response(jsonEncode({'valid': true}), 200);
        });

        final service = NpubVerificationService(
          client: mockClient,
          repository: repository,
          getDeviceId: () async => testDeviceId,
        );
        await service.verifyNpub(testNpub);

        expect(capturedRequests.length, equals(1));
        final request = capturedRequests.first;

        expect(request.url.path, contains('/v1/verify-npub'));
        expect(request.method, equals('POST'));
        expect(request.headers['Content-Type'], equals('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['npub'], equals(testNpub));
        expect(body['deviceId'], equals(testDeviceId));
      });

      test('returns valid result on successful verification', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'valid': true,
              'message': 'Account verified successfully',
            }),
            200,
          );
        });

        final service = NpubVerificationService(
          client: mockClient,
          repository: repository,
          getDeviceId: () async => testDeviceId,
        );
        final result = await service.verifyNpub(testNpub);

        expect(result.valid, isTrue);
        expect(result.message, equals('Account verified successfully'));
      });

      test('stores verification in repository on success', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'valid': true}), 200);
        });

        final service = NpubVerificationService(
          client: mockClient,
          repository: repository,
          getDeviceId: () async => testDeviceId,
        );

        expect(service.isVerified(testNpub), isFalse);

        await service.verifyNpub(testNpub);

        expect(service.isVerified(testNpub), isTrue);
      });

      test('returns invalid result when verification fails', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'valid': false,
              'message': 'Account not authorized for access',
            }),
            200,
          );
        });

        final service = NpubVerificationService(
          client: mockClient,
          repository: repository,
          getDeviceId: () async => testDeviceId,
        );
        final result = await service.verifyNpub(testNpub);

        expect(result.valid, isFalse);
        expect(result.message, equals('Account not authorized for access'));
        expect(service.isVerified(testNpub), isFalse);
      });

      test('returns invalid result on 400 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Invalid npub format'}),
            400,
          );
        });

        final service = NpubVerificationService(
          client: mockClient,
          repository: repository,
          getDeviceId: () async => testDeviceId,
        );
        final result = await service.verifyNpub(testNpub);

        expect(result.valid, isFalse);
        expect(result.message, equals('Invalid npub format'));
      });

      test('returns invalid result on 404 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Account not found'}),
            404,
          );
        });

        final service = NpubVerificationService(
          client: mockClient,
          repository: repository,
          getDeviceId: () async => testDeviceId,
        );
        final result = await service.verifyNpub(testNpub);

        expect(result.valid, isFalse);
        expect(result.message, equals('Account not found'));
      });

      test('throws NpubVerificationException on server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final service = NpubVerificationService(
          client: mockClient,
          repository: repository,
          getDeviceId: () async => testDeviceId,
        );

        expect(
          () => service.verifyNpub(testNpub),
          throwsA(isA<NpubVerificationException>()),
        );
      });
    });

    group('clearVerification', () {
      test('removes verification status from repository', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'valid': true}), 200);
        });

        final service = NpubVerificationService(
          client: mockClient,
          repository: repository,
          getDeviceId: () async => testDeviceId,
        );

        // First verify the npub
        await service.verifyNpub(testNpub);
        expect(service.isVerified(testNpub), isTrue);

        // Then clear it
        await service.clearVerification(testNpub);
        expect(service.isVerified(testNpub), isFalse);
      });
    });

    group('isVerified', () {
      test('returns true when npub is verified', () async {
        // Pre-set verification in repository
        await repository.setVerified(testNpub);

        final mockClient = MockClient((request) async {
          return http.Response('{}', 200);
        });

        final service = NpubVerificationService(
          client: mockClient,
          repository: repository,
          getDeviceId: () async => testDeviceId,
        );

        expect(service.isVerified(testNpub), isTrue);
      });

      test('returns false when npub is not verified', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{}', 200);
        });

        final service = NpubVerificationService(
          client: mockClient,
          repository: repository,
          getDeviceId: () async => testDeviceId,
        );

        expect(service.isVerified(testNpub), isFalse);
      });
    });

    group('device ID usage', () {
      test('uses device ID from getDeviceId callback', () async {
        const customDeviceId = 'custom-device-id-456';

        final mockClient = MockClient((request) async {
          capturedRequests.add(request);
          return http.Response(jsonEncode({'valid': true}), 200);
        });

        final service = NpubVerificationService(
          client: mockClient,
          repository: repository,
          getDeviceId: () async => customDeviceId,
        );

        await service.verifyNpub(testNpub);

        final body =
            jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
        expect(body['deviceId'], equals(customDeviceId));
      });
    });
  });
}
