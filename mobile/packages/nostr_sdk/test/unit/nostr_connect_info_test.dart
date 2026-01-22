// ABOUTME: Tests for NostrConnectInfo class (NIP-46 nostrconnect:// URLs)
// ABOUTME: Validates URL generation, parsing, and secret generation

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('NostrConnectInfo', () {
    const testPubkey =
        '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
    const testRelay = 'wss://relay.divine.video';
    const testSecret = 'a1b2c3d4';

    group('URL generation', () {
      test('generates valid nostrconnect:// URL with required fields', () {
        final info = NostrConnectInfo(
          clientPubkey: testPubkey,
          relays: [testRelay],
          secret: testSecret,
        );

        final url = info.toNostrConnectUrl();

        expect(url, startsWith('nostrconnect://'));
        expect(url, contains(testPubkey));
        expect(url, contains('relay='));
        expect(url, contains('secret=$testSecret'));
      });

      test('includes optional app name in URL', () {
        final info = NostrConnectInfo(
          clientPubkey: testPubkey,
          relays: [testRelay],
          secret: testSecret,
          appName: 'Divine',
        );

        final url = info.toNostrConnectUrl();

        expect(url, contains('name=Divine'));
      });

      test('includes optional app URL in URL', () {
        final info = NostrConnectInfo(
          clientPubkey: testPubkey,
          relays: [testRelay],
          secret: testSecret,
          appUrl: 'https://divine.video',
        );

        final url = info.toNostrConnectUrl();

        expect(url, contains('url='));
        expect(url, contains('divine.video'));
      });

      test('includes optional permissions in URL', () {
        final info = NostrConnectInfo(
          clientPubkey: testPubkey,
          relays: [testRelay],
          secret: testSecret,
          permissions: 'sign_event,get_public_key',
        );

        final url = info.toNostrConnectUrl();

        expect(url, contains('perms=sign_event'));
      });

      test('includes optional app image in URL', () {
        final info = NostrConnectInfo(
          clientPubkey: testPubkey,
          relays: [testRelay],
          secret: testSecret,
          appImage: 'https://divine.video/icon.png',
        );

        final url = info.toNostrConnectUrl();

        expect(url, contains('image='));
      });

      test('supports multiple relays', () {
        final info = NostrConnectInfo(
          clientPubkey: testPubkey,
          relays: ['wss://relay1.example.com', 'wss://relay2.example.com'],
          secret: testSecret,
        );

        final url = info.toNostrConnectUrl();

        expect(url, contains('relay='));
        // Both relays should be in URL (as repeated query params)
        expect(url, contains('relay1.example.com'));
        expect(url, contains('relay2.example.com'));
      });

      test('toString returns nostrconnect:// URL', () {
        final info = NostrConnectInfo(
          clientPubkey: testPubkey,
          relays: [testRelay],
          secret: testSecret,
        );

        expect(info.toString(), equals(info.toNostrConnectUrl()));
      });
    });

    group('URL parsing', () {
      test('parses valid nostrconnect:// URL', () {
        final originalInfo = NostrConnectInfo(
          clientPubkey: testPubkey,
          relays: [testRelay],
          secret: testSecret,
          appName: 'Divine',
          appUrl: 'https://divine.video',
        );

        final url = originalInfo.toNostrConnectUrl();
        final parsed = NostrConnectInfo.parseNostrConnectUrl(url);

        expect(parsed, isNotNull);
        expect(parsed!.clientPubkey, equals(testPubkey));
        expect(parsed.relays, contains(testRelay));
        expect(parsed.secret, equals(testSecret));
        expect(parsed.appName, equals('Divine'));
      });

      test('returns null for non-nostrconnect URL', () {
        expect(NostrConnectInfo.parseNostrConnectUrl('bunker://...'), isNull);
        expect(
          NostrConnectInfo.parseNostrConnectUrl('https://example.com'),
          isNull,
        );
        expect(NostrConnectInfo.parseNostrConnectUrl('invalid'), isNull);
      });

      test('returns null for URL missing relay', () {
        final url = 'nostrconnect://$testPubkey?secret=$testSecret';
        expect(NostrConnectInfo.parseNostrConnectUrl(url), isNull);
      });

      test('returns null for URL missing secret', () {
        final url =
            'nostrconnect://$testPubkey?relay=${Uri.encodeComponent(testRelay)}';
        expect(NostrConnectInfo.parseNostrConnectUrl(url), isNull);
      });

      test('returns null for URL missing client pubkey', () {
        final url =
            'nostrconnect://?relay=${Uri.encodeComponent(testRelay)}&secret=$testSecret';
        expect(NostrConnectInfo.parseNostrConnectUrl(url), isNull);
      });

      test('parses URL with all optional fields', () {
        final info = NostrConnectInfo(
          clientPubkey: testPubkey,
          relays: [testRelay],
          secret: testSecret,
          appName: 'Divine',
          appUrl: 'https://divine.video',
          appImage: 'https://divine.video/icon.png',
          permissions: 'sign_event,get_public_key',
        );

        final url = info.toNostrConnectUrl();
        final parsed = NostrConnectInfo.parseNostrConnectUrl(url);

        expect(parsed, isNotNull);
        expect(parsed!.appName, equals('Divine'));
        expect(parsed.appUrl, equals('https://divine.video'));
        expect(parsed.appImage, equals('https://divine.video/icon.png'));
        expect(parsed.permissions, equals('sign_event,get_public_key'));
      });
    });

    group('URL detection', () {
      test('isNostrConnectUrl returns true for valid URL', () {
        expect(
          NostrConnectInfo.isNostrConnectUrl('nostrconnect://$testPubkey'),
          isTrue,
        );
        expect(
          NostrConnectInfo.isNostrConnectUrl(
            'nostrconnect://$testPubkey?relay=wss://relay.example.com',
          ),
          isTrue,
        );
      });

      test('isNostrConnectUrl returns false for other URLs', () {
        expect(
          NostrConnectInfo.isNostrConnectUrl('bunker://$testPubkey'),
          isFalse,
        );
        expect(
          NostrConnectInfo.isNostrConnectUrl('https://example.com'),
          isFalse,
        );
        expect(NostrConnectInfo.isNostrConnectUrl('invalid'), isFalse);
        expect(NostrConnectInfo.isNostrConnectUrl(null), isFalse);
        expect(NostrConnectInfo.isNostrConnectUrl(''), isFalse);
      });
    });

    group('Secret generation', () {
      test('generateSecret returns 8-character hex string', () {
        final secret = NostrConnectInfo.generateSecret();

        expect(secret.length, equals(8));
        expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(secret), isTrue);
      });

      test('generateSecret produces unique values', () {
        final secrets = <String>{};
        for (var i = 0; i < 100; i++) {
          secrets.add(NostrConnectInfo.generateSecret());
        }

        // All 100 secrets should be unique
        expect(secrets.length, equals(100));
      });
    });

    group('Factory constructor', () {
      test('generate creates info with ephemeral keypair', () {
        final info = NostrConnectInfo.generate(
          relays: [testRelay],
          appName: 'Divine',
          appUrl: 'https://divine.video',
        );

        // Client pubkey should be 64-char hex
        expect(info.clientPubkey.length, equals(64));
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(info.clientPubkey), isTrue);

        // Client nsec should be set
        expect(info.clientNsec, isNotNull);
        expect(info.clientNsec, startsWith('nsec1'));

        // Secret should be generated
        expect(info.secret.length, equals(8));

        // Relays and app info should match
        expect(info.relays, contains(testRelay));
        expect(info.appName, equals('Divine'));
        expect(info.appUrl, equals('https://divine.video'));
      });

      test('generate produces different keypairs each time', () {
        final info1 = NostrConnectInfo.generate(relays: [testRelay]);
        final info2 = NostrConnectInfo.generate(relays: [testRelay]);

        expect(info1.clientPubkey, isNot(equals(info2.clientPubkey)));
        expect(info1.clientNsec, isNot(equals(info2.clientNsec)));
        expect(info1.secret, isNot(equals(info2.secret)));
      });

      test('generate includes permissions when provided', () {
        final info = NostrConnectInfo.generate(
          relays: [testRelay],
          permissions: 'sign_event,get_public_key',
        );

        expect(info.permissions, equals('sign_event,get_public_key'));
        expect(info.toNostrConnectUrl(), contains('perms=sign_event'));
      });
    });

    group('copyWith', () {
      test('copies all fields correctly', () {
        final original = NostrConnectInfo(
          clientPubkey: testPubkey,
          relays: [testRelay],
          secret: testSecret,
          appName: 'Divine',
          appUrl: 'https://divine.video',
          clientNsec: 'nsec1...',
        );

        final copied = original.copyWith(
          remoteSignerPubkey: 'signer_pubkey_hex',
          userPubkey: 'user_pubkey_hex',
        );

        // Original fields preserved
        expect(copied.clientPubkey, equals(testPubkey));
        expect(copied.relays, equals([testRelay]));
        expect(copied.secret, equals(testSecret));
        expect(copied.appName, equals('Divine'));
        expect(copied.clientNsec, equals('nsec1...'));

        // New fields added
        expect(copied.remoteSignerPubkey, equals('signer_pubkey_hex'));
        expect(copied.userPubkey, equals('user_pubkey_hex'));
      });

      test('allows overriding existing fields', () {
        final original = NostrConnectInfo(
          clientPubkey: testPubkey,
          relays: [testRelay],
          secret: testSecret,
        );

        final copied = original.copyWith(
          appName: 'New App',
          appUrl: 'https://new.app',
        );

        expect(copied.appName, equals('New App'));
        expect(copied.appUrl, equals('https://new.app'));
      });
    });

    group('Round-trip tests', () {
      test('generate -> toNostrConnectUrl -> parse maintains data', () {
        final original = NostrConnectInfo.generate(
          relays: [testRelay, 'wss://relay2.example.com'],
          appName: 'Divine',
          appUrl: 'https://divine.video',
          appImage: 'https://divine.video/icon.png',
          permissions: 'sign_event,get_public_key,nip44_encrypt',
        );

        final url = original.toNostrConnectUrl();
        final parsed = NostrConnectInfo.parseNostrConnectUrl(url);

        expect(parsed, isNotNull);
        expect(parsed!.clientPubkey, equals(original.clientPubkey));
        expect(parsed.relays, containsAll(original.relays));
        expect(parsed.secret, equals(original.secret));
        expect(parsed.appName, equals(original.appName));
        expect(parsed.appUrl, equals(original.appUrl));
        expect(parsed.appImage, equals(original.appImage));
        expect(parsed.permissions, equals(original.permissions));
      });
    });
  });
}
