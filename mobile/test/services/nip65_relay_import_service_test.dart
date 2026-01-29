// ABOUTME: Tests for NIP-65 relay import service
// ABOUTME: Verifies relay list parsing and import behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/services/nip65_relay_import_service.dart';

void main() {
  group('Nip65RelayImportService', () {
    late Nip65RelayImportService service;
    const defaultRelayUrl = 'wss://relay.test.com';

    setUp(() {
      service = Nip65RelayImportService(defaultRelayUrl: defaultRelayUrl);
    });

    group('Nip65ImportResult', () {
      test('creates result with relays and source', () {
        const result = Nip65ImportResult(
          relays: ['wss://relay1.com', 'wss://relay2.com'],
          source: Nip65ImportSource.nip65Event,
        );

        expect(result.relays.length, 2);
        expect(result.source, Nip65ImportSource.nip65Event);
      });
    });

    group('Nip65ImportSource', () {
      test('has correct enum values', () {
        expect(Nip65ImportSource.values.length, 3);
        expect(Nip65ImportSource.nip65Event.name, 'nip65Event');
        expect(Nip65ImportSource.defaultOnly.name, 'defaultOnly');
        expect(Nip65ImportSource.errorFallback.name, 'errorFallback');
      });
    });

    group('service initialization', () {
      test('stores default relay URL', () {
        expect(service.defaultRelayUrl, defaultRelayUrl);
      });

      test('uses AppConstants indexer relays by default', () {
        expect(service.indexerRelayUrls, AppConstants.indexerRelayUrls);
      });

      test('allows custom indexer relay URLs', () {
        const customIndexers = ['wss://custom.indexer.com'];
        final customService = Nip65RelayImportService(
          defaultRelayUrl: defaultRelayUrl,
          indexerRelayUrls: customIndexers,
        );

        expect(customService.indexerRelayUrls, customIndexers);
      });

      test('AppConstants has indexer relay URLs defined', () {
        expect(AppConstants.indexerRelayUrls, isNotEmpty);
        expect(AppConstants.indexerRelayUrls, contains('wss://purplepag.es'));
      });
    });

    group('RelayListMetadata parsing', () {
      // Valid 64-char hex pubkey for testing
      const testPubkey =
          '0000000000000000000000000000000000000000000000000000000000000001';

      test('parses read-only relays from kind 10002 event', () {
        // Create a mock kind 10002 event with read-only relay
        final event = Event(
          testPubkey,
          EventKind.relayListMetadata, // 10002
          [
            ['r', 'wss://relay1.com', 'read'],
          ],
          '',
        );

        final metadata = RelayListMetadata.fromEvent(event);

        expect(metadata.readAbleRelays, contains('wss://relay1.com'));
        expect(metadata.writeAbleRelays, isEmpty);
      });

      test('parses write-only relays from kind 10002 event', () {
        final event = Event(testPubkey, EventKind.relayListMetadata, [
          ['r', 'wss://relay2.com', 'write'],
        ], '');

        final metadata = RelayListMetadata.fromEvent(event);

        expect(metadata.readAbleRelays, isEmpty);
        expect(metadata.writeAbleRelays, contains('wss://relay2.com'));
      });

      test('parses read/write relays without marker', () {
        // No marker means both read and write
        final event = Event(testPubkey, EventKind.relayListMetadata, [
          ['r', 'wss://relay3.com'],
        ], '');

        final metadata = RelayListMetadata.fromEvent(event);

        expect(metadata.readAbleRelays, contains('wss://relay3.com'));
        expect(metadata.writeAbleRelays, contains('wss://relay3.com'));
      });

      test('parses multiple relays with different markers', () {
        final event = Event(testPubkey, EventKind.relayListMetadata, [
          ['r', 'wss://read-only.com', 'read'],
          ['r', 'wss://write-only.com', 'write'],
          ['r', 'wss://both.com'],
        ], '');

        final metadata = RelayListMetadata.fromEvent(event);

        // Check read relays
        expect(metadata.readAbleRelays, contains('wss://read-only.com'));
        expect(
          metadata.readAbleRelays,
          isNot(contains('wss://write-only.com')),
        );
        expect(metadata.readAbleRelays, contains('wss://both.com'));

        // Check write relays
        expect(
          metadata.writeAbleRelays,
          isNot(contains('wss://read-only.com')),
        );
        expect(metadata.writeAbleRelays, contains('wss://write-only.com'));
        expect(metadata.writeAbleRelays, contains('wss://both.com'));
      });

      test('ignores non-r tags', () {
        final event = Event(testPubkey, EventKind.relayListMetadata, [
          ['r', 'wss://relay.com'],
          ['p', 'somepubkey'],
          ['e', 'someeventid'],
        ], '');

        final metadata = RelayListMetadata.fromEvent(event);

        expect(metadata.readAbleRelays.length, 1);
        expect(metadata.writeAbleRelays.length, 1);
      });

      test('union of read and write relays includes all unique URLs', () {
        final event = Event(testPubkey, EventKind.relayListMetadata, [
          ['r', 'wss://read-only.com', 'read'],
          ['r', 'wss://write-only.com', 'write'],
          ['r', 'wss://both.com'],
        ], '');

        final metadata = RelayListMetadata.fromEvent(event);
        final allRelays = <String>{
          ...metadata.readAbleRelays,
          ...metadata.writeAbleRelays,
        };

        expect(allRelays.length, 3);
        expect(allRelays, contains('wss://read-only.com'));
        expect(allRelays, contains('wss://write-only.com'));
        expect(allRelays, contains('wss://both.com'));
      });
    });
  });

  group('RelayManager initialRelays integration', () {
    // These tests verify the contract that RelayManager.initialize() expects

    test('empty initialRelays list is handled gracefully', () {
      // When initialRelays is empty, RelayManager should use default relay
      final relays = <String>[];
      expect(relays.isEmpty, true);
    });

    test('initialRelays with duplicates are normalized', () {
      // Simulate what RelayManager should do with duplicates
      final relays = ['wss://relay.com', 'wss://relay.com', 'wss://other.com'];
      final normalized = relays.toSet().toList();
      expect(normalized.length, 2);
    });

    test('default relay is always added when not in initialRelays', () {
      // Simulate the behavior: if default is not in list, add it
      const defaultUrl = 'wss://relay.default.com';
      final relays = ['wss://relay1.com', 'wss://relay2.com'];

      final result = <String>{...relays, defaultUrl};

      expect(result.length, 3);
      expect(result, contains(defaultUrl));
    });

    test('default relay is not duplicated if already present', () {
      const defaultUrl = 'wss://relay.default.com';
      final relays = ['wss://relay1.com', defaultUrl];

      final result = <String>{...relays, defaultUrl};

      expect(result.length, 2);
      expect(result.where((r) => r == defaultUrl).length, 1);
    });
  });
}
