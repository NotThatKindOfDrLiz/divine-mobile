// ABOUTME: Tests for NostrIdentity — unified signing identity type
// ABOUTME: Validates local and remote signing paths, encryption, and delegation

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_identity.dart';

class _MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  const testPublicKeyHex =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';
  const testNpub =
      'npub18pwrax0qhv6474xvxahv2zfxd7t06qus79dlw28xm2h83jph58xstjk6pz';
  const testPrivateKey =
      '6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e';

  group(NostrIdentity, () {
    group('local', () {
      late _MockSecureKeyContainer mockContainer;
      late _MockSecureKeyStorage mockStorage;

      setUp(() {
        mockContainer = _MockSecureKeyContainer();
        mockStorage = _MockSecureKeyStorage();
        when(() => mockContainer.publicKeyHex).thenReturn(testPublicKeyHex);
        when(() => mockContainer.npub).thenReturn(testNpub);
      });

      test('sets signing method to local', () {
        final identity = NostrIdentity.local(
          keyContainer: mockContainer,
          keyStorage: mockStorage,
          authSource: AuthenticationSource.importedKeys,
        );

        expect(identity.signingMethod, equals(SigningMethod.local));
        expect(identity.isRemote, isFalse);
      });

      test('exposes public key from key container', () async {
        final identity = NostrIdentity.local(
          keyContainer: mockContainer,
          keyStorage: mockStorage,
          authSource: AuthenticationSource.automatic,
        );

        expect(identity.publicKeyHex, equals(testPublicKeyHex));
        expect(identity.npub, equals(testNpub));
        expect(await identity.getPublicKey(), equals(testPublicKeyHex));
      });

      test('signs event via key storage', () async {
        final event = Event(testPublicKeyHex, 1, [], 'test content');
        when(
          () => mockStorage.withPrivateKey<Event?>(
            any(),
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Event? Function(String);
          return callback(testPrivateKey);
        });

        final identity = NostrIdentity.local(
          keyContainer: mockContainer,
          keyStorage: mockStorage,
          authSource: AuthenticationSource.importedKeys,
        );

        final signed = await identity.signEvent(event);

        expect(signed, isNotNull);
        expect(signed!.isSigned, isTrue);
        verify(
          () => mockStorage.withPrivateKey<Event?>(
            any(),
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).called(1);
      });

      test('returns null when local signing fails', () async {
        final event = Event(testPublicKeyHex, 1, [], 'test content');
        when(
          () => mockStorage.withPrivateKey<Event?>(
            any(),
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenThrow(Exception('storage locked'));

        final identity = NostrIdentity.local(
          keyContainer: mockContainer,
          keyStorage: mockStorage,
          authSource: AuthenticationSource.importedKeys,
        );

        final signed = await identity.signEvent(event);

        expect(signed, isNull);
      });

      test('encrypts via NIP-04 using local key', () async {
        when(
          () => mockStorage.withPrivateKey<String?>(
            any(),
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as String? Function(String);
          return callback(testPrivateKey);
        });

        final identity = NostrIdentity.local(
          keyContainer: mockContainer,
          keyStorage: mockStorage,
          authSource: AuthenticationSource.importedKeys,
        );

        final encrypted = await identity.encrypt(testPublicKeyHex, 'hello');

        expect(encrypted, isNotNull);
        expect(encrypted, isNotEmpty);
      });

      test('getRelays returns null for local identity', () async {
        final identity = NostrIdentity.local(
          keyContainer: mockContainer,
          keyStorage: mockStorage,
          authSource: AuthenticationSource.importedKeys,
        );

        final relays = await identity.getRelays();

        expect(relays, isNull);
      });

      test('exposes key container', () {
        final identity = NostrIdentity.local(
          keyContainer: mockContainer,
          keyStorage: mockStorage,
          authSource: AuthenticationSource.importedKeys,
        );

        expect(identity.keyContainer, same(mockContainer));
      });

      test('exposes auth source', () {
        final identity = NostrIdentity.local(
          keyContainer: mockContainer,
          keyStorage: mockStorage,
          authSource: AuthenticationSource.importedKeys,
        );

        expect(identity.authSource, equals(AuthenticationSource.importedKeys));
      });
    });

    group('remote', () {
      late _MockNostrSigner mockSigner;

      setUp(() {
        mockSigner = _MockNostrSigner();
      });

      test('sets signing method and isRemote', () {
        final identity = NostrIdentity.remote(
          publicKeyHex: testPublicKeyHex,
          npub: testNpub,
          signer: mockSigner,
          signingMethod: SigningMethod.keycastRpc,
          authSource: AuthenticationSource.divineOAuth,
        );

        expect(identity.signingMethod, equals(SigningMethod.keycastRpc));
        expect(identity.isRemote, isTrue);
      });

      test('delegates signEvent to remote signer', () async {
        final event = Event(testPublicKeyHex, 1, [], 'test content');
        when(() => mockSigner.signEvent(event)).thenAnswer((_) async => event);

        final identity = NostrIdentity.remote(
          publicKeyHex: testPublicKeyHex,
          npub: testNpub,
          signer: mockSigner,
          signingMethod: SigningMethod.keycastRpc,
          authSource: AuthenticationSource.divineOAuth,
        );

        final signed = await identity.signEvent(event);

        expect(signed, same(event));
        verify(() => mockSigner.signEvent(event)).called(1);
      });

      test('delegates encrypt to remote signer', () async {
        when(
          () => mockSigner.encrypt(testPublicKeyHex, 'hello'),
        ).thenAnswer((_) async => 'encrypted');

        final identity = NostrIdentity.remote(
          publicKeyHex: testPublicKeyHex,
          npub: testNpub,
          signer: mockSigner,
          signingMethod: SigningMethod.bunker,
          authSource: AuthenticationSource.bunker,
        );

        final result = await identity.encrypt(testPublicKeyHex, 'hello');

        expect(result, equals('encrypted'));
        verify(() => mockSigner.encrypt(testPublicKeyHex, 'hello')).called(1);
      });

      test('delegates decrypt to remote signer', () async {
        when(
          () => mockSigner.decrypt(testPublicKeyHex, 'cipher'),
        ).thenAnswer((_) async => 'decrypted');

        final identity = NostrIdentity.remote(
          publicKeyHex: testPublicKeyHex,
          npub: testNpub,
          signer: mockSigner,
          signingMethod: SigningMethod.bunker,
          authSource: AuthenticationSource.bunker,
        );

        final result = await identity.decrypt(testPublicKeyHex, 'cipher');

        expect(result, equals('decrypted'));
      });

      test('delegates nip44Encrypt to remote signer', () async {
        when(
          () => mockSigner.nip44Encrypt(testPublicKeyHex, 'hello'),
        ).thenAnswer((_) async => 'encrypted44');

        final identity = NostrIdentity.remote(
          publicKeyHex: testPublicKeyHex,
          npub: testNpub,
          signer: mockSigner,
          signingMethod: SigningMethod.amber,
          authSource: AuthenticationSource.amber,
        );

        final result = await identity.nip44Encrypt(testPublicKeyHex, 'hello');

        expect(result, equals('encrypted44'));
      });

      test('delegates nip44Decrypt to remote signer', () async {
        when(
          () => mockSigner.nip44Decrypt(testPublicKeyHex, 'cipher44'),
        ).thenAnswer((_) async => 'decrypted44');

        final identity = NostrIdentity.remote(
          publicKeyHex: testPublicKeyHex,
          npub: testNpub,
          signer: mockSigner,
          signingMethod: SigningMethod.amber,
          authSource: AuthenticationSource.amber,
        );

        final result = await identity.nip44Decrypt(
          testPublicKeyHex,
          'cipher44',
        );

        expect(result, equals('decrypted44'));
      });

      test('delegates getRelays to remote signer', () async {
        when(
          () => mockSigner.getRelays(),
        ).thenAnswer((_) async => {'wss://relay.test': {}});

        final identity = NostrIdentity.remote(
          publicKeyHex: testPublicKeyHex,
          npub: testNpub,
          signer: mockSigner,
          signingMethod: SigningMethod.keycastRpc,
          authSource: AuthenticationSource.divineOAuth,
        );

        final relays = await identity.getRelays();

        expect(relays, isNotNull);
        verify(() => mockSigner.getRelays()).called(1);
      });

      test('close delegates to remote signer', () {
        when(() => mockSigner.close()).thenReturn(null);

        final identity = NostrIdentity.remote(
          publicKeyHex: testPublicKeyHex,
          npub: testNpub,
          signer: mockSigner,
          signingMethod: SigningMethod.keycastRpc,
          authSource: AuthenticationSource.divineOAuth,
        );

        identity.close();

        verify(() => mockSigner.close()).called(1);
      });

      test('keyContainer is null by default for remote identity', () {
        final identity = NostrIdentity.remote(
          publicKeyHex: testPublicKeyHex,
          npub: testNpub,
          signer: mockSigner,
          signingMethod: SigningMethod.keycastRpc,
          authSource: AuthenticationSource.divineOAuth,
        );

        expect(identity.keyContainer, isNull);
      });

      test('keyContainer can be provided for remote identity', () {
        final mockContainer = _MockSecureKeyContainer();
        final identity = NostrIdentity.remote(
          publicKeyHex: testPublicKeyHex,
          npub: testNpub,
          signer: mockSigner,
          signingMethod: SigningMethod.keycastRpc,
          authSource: AuthenticationSource.divineOAuth,
          keyContainer: mockContainer,
        );

        expect(identity.keyContainer, same(mockContainer));
      });
    });
  });
}
