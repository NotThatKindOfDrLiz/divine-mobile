// ABOUTME: Unit tests for SharedPreferencesRelayStorage implementation.
// ABOUTME: Tests relay URL persistence using SharedPreferences.

import 'package:nostr_client/nostr_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

void main() {
  group('SharedPreferencesRelayStorage', () {
    setUp(() {
      // Set up fake SharedPreferences values before each test
      SharedPreferences.setMockInitialValues({});
    });

    group('loadRelays', () {
      test('returns empty list when no relays stored', () async {
        final storage = SharedPreferencesRelayStorage();

        final relays = await storage.loadRelays();

        expect(relays, isEmpty);
      });

      test('returns stored relays', () async {
        SharedPreferences.setMockInitialValues({
          'configured_relays': [
            'wss://relay1.example.com',
            'wss://relay2.example.com',
          ],
        });
        final storage = SharedPreferencesRelayStorage();

        final relays = await storage.loadRelays();

        expect(
          relays,
          equals(['wss://relay1.example.com', 'wss://relay2.example.com']),
        );
      });

      test('returns copy of list (not reference)', () async {
        SharedPreferences.setMockInitialValues({
          'configured_relays': ['wss://relay1.example.com'],
        });
        final storage = SharedPreferencesRelayStorage();

        final relays1 = await storage.loadRelays();
        final relays2 = await storage.loadRelays();

        expect(identical(relays1, relays2), isFalse);
      });
    });

    group('saveRelays', () {
      test('saves relay URLs to SharedPreferences', () async {
        final storage = SharedPreferencesRelayStorage();

        await storage.saveRelays([
          'wss://relay1.example.com',
          'wss://relay2.example.com',
        ]);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('configured_relays'),
          equals(['wss://relay1.example.com', 'wss://relay2.example.com']),
        );
      });

      test('overwrites existing relays', () async {
        SharedPreferences.setMockInitialValues({
          'configured_relays': ['wss://old.example.com'],
        });
        final storage = SharedPreferencesRelayStorage();

        await storage.saveRelays(['wss://new.example.com']);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('configured_relays'),
          equals(['wss://new.example.com']),
        );
      });

      test('can save empty list', () async {
        SharedPreferences.setMockInitialValues({
          'configured_relays': ['wss://relay.example.com'],
        });
        final storage = SharedPreferencesRelayStorage();

        await storage.saveRelays([]);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('configured_relays'), isEmpty);
      });
    });

    group('round-trip', () {
      test('load returns what was saved', () async {
        final storage = SharedPreferencesRelayStorage();
        final originalRelays = [
          'wss://relay1.example.com',
          'wss://relay2.example.com',
          'wss://relay3.example.com',
        ];

        await storage.saveRelays(originalRelays);
        final loadedRelays = await storage.loadRelays();

        expect(loadedRelays, equals(originalRelays));
      });
    });

    group('custom key', () {
      test('uses custom key when provided', () async {
        final storage = SharedPreferencesRelayStorage(key: 'custom_relay_key');

        await storage.saveRelays(['wss://relay.example.com']);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('custom_relay_key'),
          equals(['wss://relay.example.com']),
        );
        expect(prefs.getStringList('configured_relays'), isNull);
      });

      test('loads from custom key', () async {
        SharedPreferences.setMockInitialValues({
          'custom_relay_key': ['wss://relay.example.com'],
        });
        final storage = SharedPreferencesRelayStorage(key: 'custom_relay_key');

        final relays = await storage.loadRelays();

        expect(relays, equals(['wss://relay.example.com']));
      });
    });

    group('forUser factory', () {
      test('creates storage with user-specific key', () async {
        const pubkey = 'abc123def456';
        final storage = SharedPreferencesRelayStorage.forUser(pubkey: pubkey);

        await storage.saveRelays(['wss://relay.example.com']);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('configured_relays_$pubkey'),
          equals(['wss://relay.example.com']),
        );
        // Default key should be empty
        expect(prefs.getStringList('configured_relays'), isNull);
      });

      test('different users have isolated storage', () async {
        const pubkey1 = 'user1pubkey';
        const pubkey2 = 'user2pubkey';
        final storage1 = SharedPreferencesRelayStorage.forUser(pubkey: pubkey1);
        final storage2 = SharedPreferencesRelayStorage.forUser(pubkey: pubkey2);

        await storage1.saveRelays(['wss://relay1.example.com']);
        await storage2.saveRelays(['wss://relay2.example.com']);

        final relays1 = await storage1.loadRelays();
        final relays2 = await storage2.loadRelays();

        expect(relays1, equals(['wss://relay1.example.com']));
        expect(relays2, equals(['wss://relay2.example.com']));
      });

      test('loads relays for specific user', () async {
        const pubkey = 'testpubkey';
        SharedPreferences.setMockInitialValues({
          'configured_relays_$pubkey': ['wss://user-relay.example.com'],
          'configured_relays': ['wss://default-relay.example.com'],
        });
        final storage = SharedPreferencesRelayStorage.forUser(pubkey: pubkey);

        final relays = await storage.loadRelays();

        expect(relays, equals(['wss://user-relay.example.com']));
      });
    });
  });
}
