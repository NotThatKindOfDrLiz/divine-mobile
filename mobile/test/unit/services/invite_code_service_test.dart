// ABOUTME: Unit tests for InviteCodeService
// ABOUTME: Tests claim, verify, device ID generation with mocked HTTP

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/repositories/invite_code_repository.dart';
import 'package:openvine/services/invite_code_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

class _FakeNip98Token extends Fake implements Nip98Token {
  @override
  String get authorizationHeader => 'Nostr fakebase64token';
}

void main() {
  setUpAll(() {
    registerFallbackValue(HttpMethod.get);
  });

  group('InviteCodeService', () {
    late SharedPreferences prefs;
    late InviteCodeRepository repository;
    late List<http.Request> capturedRequests;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = InviteCodeRepository(prefs);
      capturedRequests = [];
    });

    group('claimCode', () {
      test('sends correct request to claim endpoint', () async {
        final mockClient = MockClient((request) async {
          capturedRequests.add(request);
          return http.Response(
            jsonEncode({'valid': true, 'code': 'ABCD1234'}),
            200,
          );
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );
        await service.claimCode('abcd1234');

        expect(capturedRequests.length, equals(1));
        final request = capturedRequests.first;

        expect(request.url.path, contains('/v1/consume-invite'));
        expect(request.method, equals('POST'));
        expect(request.headers['Content-Type'], equals('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['code'], equals('ABCD1234')); // Normalized to uppercase
        expect(body['deviceId'], isNotEmpty);
      });

      test('normalizes code to uppercase', () async {
        final mockClient = MockClient((request) async {
          capturedRequests.add(request);
          return http.Response(
            jsonEncode({'valid': true, 'code': 'ABCD1234'}),
            200,
          );
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );
        await service.claimCode('  abCD1234  '); // Mixed case with spaces

        final body =
            jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
        expect(body['code'], equals('ABCD1234'));
      });

      test('returns valid result on successful claim', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'valid': true,
              'code': 'ABCD1234',
              'message': 'Invite code claimed successfully',
            }),
            200,
          );
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );
        final result = await service.claimCode('ABCD1234');

        expect(result.valid, isTrue);
        expect(result.code, equals('ABCD1234'));
        expect(result.message, equals('Invite code claimed successfully'));
      });

      test('stores code in SharedPreferences on successful claim', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'valid': true, 'code': 'GOOD1234'}),
            200,
          );
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );

        expect(service.hasVerifiedCode, isFalse);

        await service.claimCode('GOOD1234');

        expect(service.hasVerifiedCode, isTrue);
        expect(service.storedInviteCode, equals('GOOD1234'));
      });

      test('returns invalid result when code is rejected', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'valid': false, 'message': 'Invalid invite code'}),
            200,
          );
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );
        final result = await service.claimCode('BADCODE1');

        expect(result.valid, isFalse);
        expect(result.message, equals('Invalid invite code'));
        expect(service.hasVerifiedCode, isFalse);
      });

      test('returns invalid result on 400 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'message': 'Code not found'}), 400);
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );
        final result = await service.claimCode('NOTFOUND');

        expect(result.valid, isFalse);
        expect(result.message, equals('Code not found'));
      });

      test('returns invalid result on 404 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Invalid invite code'}),
            404,
          );
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );
        final result = await service.claimCode('NOTFOUND');

        expect(result.valid, isFalse);
        expect(result.message, equals('Invalid invite code'));
      });

      test('throws InviteCodeException on server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );

        expect(
          () => service.claimCode('ABCD1234'),
          throwsA(isA<InviteCodeException>()),
        );
      });
    });

    group('verifyStoredCode', () {
      test('returns invalid when no code stored', () async {
        final mockClient = MockClient((request) async {
          fail('Should not make HTTP request when no code stored');
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );
        final result = await service.verifyStoredCode();

        expect(result.valid, isFalse);
        expect(result.message, equals('No invite code stored'));
      });

      test('verifies stored code with server', () async {
        // Pre-store a code
        await prefs.setString(InviteCodeRepository.inviteCodeKey, 'STORED12');

        final mockClient = MockClient((request) async {
          capturedRequests.add(request);
          return http.Response(
            jsonEncode({'valid': true, 'code': 'STORED12'}),
            200,
          );
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );
        final result = await service.verifyStoredCode();

        expect(result.valid, isTrue);
        expect(capturedRequests.length, equals(1));
        expect(
          capturedRequests.first.url.path,
          contains('/v1/validate-invite'),
        );

        final body =
            jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
        expect(body['code'], equals('STORED12'));
      });

      test('clears stored code when verification fails', () async {
        await prefs.setString(InviteCodeRepository.inviteCodeKey, 'REVOKED1');

        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'valid': false, 'message': 'Code has been revoked'}),
            200,
          );
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );
        expect(service.hasVerifiedCode, isTrue);

        final result = await service.verifyStoredCode();

        expect(result.valid, isFalse);
        expect(service.hasVerifiedCode, isFalse);
        expect(service.storedInviteCode, isNull);
      });

      test('fails open on network timeout (allows access)', () async {
        await prefs.setString(InviteCodeRepository.inviteCodeKey, 'OFFLINE1');

        final mockClient = MockClient((request) async {
          throw Exception('Timeout');
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );
        final result = await service.verifyStoredCode();

        // Should fail open - return valid to allow offline access
        expect(result.valid, isTrue);
        expect(result.code, equals('OFFLINE1'));
        expect(service.hasVerifiedCode, isTrue);
      });
    });

    group('getDeviceId', () {
      test('generates and caches device ID', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{}', 200);
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );

        final deviceId1 = await service.getDeviceId();
        final deviceId2 = await service.getDeviceId();

        expect(deviceId1, isNotEmpty);
        expect(deviceId1, equals(deviceId2)); // Same ID returned
      });

      test('returns cached device ID from SharedPreferences', () async {
        await prefs.setString('device_unique_id', 'cached-device-id-123');

        final mockClient = MockClient((request) async {
          return http.Response('{}', 200);
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );
        final deviceId = await service.getDeviceId();

        expect(deviceId, equals('cached-device-id-123'));
      });
    });

    group('clearStoredCode', () {
      test('removes stored code from SharedPreferences', () async {
        await prefs.setString(InviteCodeRepository.inviteCodeKey, 'TOREMOVE');

        final mockClient = MockClient((request) async {
          return http.Response('{}', 200);
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );
        expect(service.hasVerifiedCode, isTrue);

        await service.clearStoredCode();

        expect(service.hasVerifiedCode, isFalse);
        expect(service.storedInviteCode, isNull);
      });
    });

    group('getInviteStatus', () {
      late _MockNip98AuthService mockNip98AuthService;

      setUp(() {
        mockNip98AuthService = _MockNip98AuthService();
      });

      test('throws when nip98AuthService is null', () async {
        final service = InviteCodeService(
          client: MockClient((_) async => http.Response('', 200)),
          repository: repository,
          prefs: prefs,
        );

        expect(
          () => service.getInviteStatus(),
          throwsA(
            isA<InviteCodeException>().having(
              (e) => e.message,
              'message',
              'NIP-98 auth service not available',
            ),
          ),
        );
      });

      test('throws when auth token creation fails', () async {
        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: any(named: 'method'),
          ),
        ).thenAnswer((_) async => null);

        final service = InviteCodeService(
          client: MockClient((_) async => http.Response('', 200)),
          repository: repository,
          prefs: prefs,
          nip98AuthService: mockNip98AuthService,
        );

        expect(
          () => service.getInviteStatus(),
          throwsA(
            isA<InviteCodeException>().having(
              (e) => e.message,
              'message',
              'Failed to create NIP-98 auth token',
            ),
          ),
        );
      });

      test('sends GET request with NIP-98 authorization header', () async {
        final fakeToken = _FakeNip98Token();

        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: any(named: 'method'),
          ),
        ).thenAnswer((_) async => fakeToken);

        final mockClient = MockClient((request) async {
          capturedRequests.add(request);
          return http.Response(
            jsonEncode({'valid': true, 'code': 'ABCD1234'}),
            200,
          );
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
          nip98AuthService: mockNip98AuthService,
        );

        await service.getInviteStatus();

        expect(capturedRequests.length, equals(1));
        final request = capturedRequests.first;
        expect(request.url.path, contains('/v1/invite-status'));
        expect(request.method, equals('GET'));
        expect(
          request.headers['Authorization'],
          equals('Nostr fakebase64token'),
        );
      });

      test('returns InviteCodeResult on 200 response', () async {
        final fakeToken = _FakeNip98Token();

        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: any(named: 'method'),
          ),
        ).thenAnswer((_) async => fakeToken);

        final mockClient = MockClient((_) async {
          return http.Response(
            jsonEncode({
              'valid': true,
              'code': 'ABCD1234',
              'message': 'Active invite',
            }),
            200,
          );
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
          nip98AuthService: mockNip98AuthService,
        );

        final result = await service.getInviteStatus();

        expect(result.valid, isTrue);
        expect(result.code, equals('ABCD1234'));
        expect(result.message, equals('Active invite'));
      });

      test('throws InviteCodeException on non-200 response', () async {
        final fakeToken = _FakeNip98Token();

        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: any(named: 'method'),
          ),
        ).thenAnswer((_) async => fakeToken);

        final mockClient = MockClient((_) async {
          return http.Response('Internal Server Error', 500);
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
          nip98AuthService: mockNip98AuthService,
        );

        expect(
          () => service.getInviteStatus(),
          throwsA(
            isA<InviteCodeException>().having(
              (e) => e.statusCode,
              'statusCode',
              500,
            ),
          ),
        );
      });

      test('passes correct HttpMethod.get to createAuthToken', () async {
        final fakeToken = _FakeNip98Token();

        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: any(named: 'method'),
          ),
        ).thenAnswer((_) async => fakeToken);

        final mockClient = MockClient((_) async {
          return http.Response(jsonEncode({'valid': true}), 200);
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
          nip98AuthService: mockNip98AuthService,
        );

        await service.getInviteStatus();

        verify(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url', that: contains('/v1/invite-status')),
            method: HttpMethod.get,
          ),
        ).called(1);
      });
    });

    group('code validation', () {
      test('same device ID used across requests', () async {
        final mockClient = MockClient((request) async {
          capturedRequests.add(request);
          return http.Response(
            jsonEncode({'valid': true, 'code': 'TEST1234'}),
            200,
          );
        });

        final service = InviteCodeService(
          client: mockClient,
          repository: repository,
          prefs: prefs,
        );

        await service.claimCode('TEST1234');
        await service.claimCode('TEST5678');

        final body1 =
            jsonDecode(capturedRequests[0].body) as Map<String, dynamic>;
        final body2 =
            jsonDecode(capturedRequests[1].body) as Map<String, dynamic>;

        expect(body1['deviceId'], equals(body2['deviceId']));
      });
    });
  });
}
