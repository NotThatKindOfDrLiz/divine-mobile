// ABOUTME: Service for importing relay list from NIP-65 (kind 10002) events
// ABOUTME: Queries indexer relays to discover user's relay configuration

import 'dart:async';
import 'dart:developer' as developer;

import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/constants/app_constants.dart';

/// Result of NIP-65 relay import operation
class Nip65ImportResult {
  const Nip65ImportResult({required this.relays, required this.source});

  /// The list of relay URLs to use
  final List<String> relays;

  /// The source of the relay list
  final Nip65ImportSource source;
}

/// Source of the imported relay list
enum Nip65ImportSource {
  /// Relays were imported from a NIP-65 kind 10002 event
  nip65Event,

  /// No NIP-65 event found, using default relay only
  defaultOnly,

  /// An error occurred, falling back to default relay
  errorFallback,
}

/// Service for fetching and importing relay lists from NIP-65 events.
///
/// This service queries indexer relays (like Purple Pages) to discover
/// the user's kind 10002 relay list metadata. Indexer relays aggregate
/// user metadata from across the Nostr network, making it possible to
/// find relay lists regardless of where they were originally published.
///
/// Flow:
/// 1. Query each indexer relay for the user's kind 10002 event
/// 2. If found, import all relays (union of read + write)
/// 3. Always include the default relay in the result
/// 4. If not found on any indexer, return default relay only
class Nip65RelayImportService {
  /// Creates a new NIP-65 relay import service.
  ///
  /// [defaultRelayUrl] is always included in the result, even if relays
  /// are found from NIP-65.
  ///
  /// [indexerRelayUrls] are the indexer relays to query for the user's
  /// kind 10002 event. Defaults to [AppConstants.indexerRelayUrls] if not
  /// provided.
  Nip65RelayImportService({
    required this.defaultRelayUrl,
    List<String>? indexerRelayUrls,
  }) : indexerRelayUrls = indexerRelayUrls ?? AppConstants.indexerRelayUrls;

  /// The default relay URL to always include in results
  final String defaultRelayUrl;

  /// Indexer relay URLs to query for NIP-65 events
  final List<String> indexerRelayUrls;

  /// Timeout for fetching the relay list from each indexer
  static const Duration _fetchTimeout = Duration(seconds: 10);

  /// Fetches the relay list for a user from their NIP-65 event.
  ///
  /// Queries indexer relays for the user's kind 10002 event and
  /// returns the union of all read and write relays, plus the default
  /// relay.
  ///
  /// Returns [Nip65ImportResult] with:
  /// - [Nip65ImportSource.nip65Event] if relays were imported from the event
  /// - [Nip65ImportSource.defaultOnly] if no kind 10002 event was found
  /// - [Nip65ImportSource.errorFallback] if an error occurred
  Future<Nip65ImportResult> fetchRelayList(String pubkey) async {
    _log('Fetching relay list for pubkey: $pubkey');
    _log('Querying ${indexerRelayUrls.length} indexer relays');

    try {
      // Try each indexer relay until we find the event
      for (final indexerUrl in indexerRelayUrls) {
        _log('Trying indexer: $indexerUrl');

        final event = await _fetchKind10002Event(pubkey, indexerUrl);

        if (event != null) {
          final relays = _parseRelaysFromEvent(event);
          _log(
            'Found ${relays.length} relays from kind 10002 event '
            'on $indexerUrl',
          );

          // Always include default relay
          final relaySet = <String>{...relays, defaultRelayUrl};

          return Nip65ImportResult(
            relays: relaySet.toList(),
            source: Nip65ImportSource.nip65Event,
          );
        }
      }

      // No event found on any indexer
      _log('No kind 10002 event found on any indexer, using default relay');
      return Nip65ImportResult(
        relays: [defaultRelayUrl],
        source: Nip65ImportSource.defaultOnly,
      );
    } catch (e) {
      _log('Error fetching relay list: $e');
      return Nip65ImportResult(
        relays: [defaultRelayUrl],
        source: Nip65ImportSource.errorFallback,
      );
    }
  }

  /// Fetches the kind 10002 event from a specific relay.
  Future<Event?> _fetchKind10002Event(String pubkey, String relayUrl) async {
    RelayBase? relay;

    try {
      // Create temporary relay connection
      relay = RelayBase(relayUrl, RelayStatus(relayUrl));

      // Create subscription for kind 10002
      final completer = Completer<Event?>();
      var receivedEvent = false;

      final filter = Filter(
        authors: [pubkey],
        kinds: [EventKind.relayListMetadata], // 10002
        limit: 1,
      );

      final subscriptionId =
          'nip65_import_${DateTime.now().millisecondsSinceEpoch}';

      // Set up message handler before connecting
      relay.onMessage = (_, List<dynamic> message) {
        if (message.isEmpty) return;

        final messageType = message[0];
        _log('Received message type: $messageType from $relayUrl');

        if (messageType == 'EVENT' &&
            message.length >= 3 &&
            message[1] == subscriptionId) {
          _log('Received EVENT for our subscription');
          final eventJson = message[2] as Map<String, dynamic>;
          final event = Event.fromJson(eventJson);

          if (event.kind == EventKind.relayListMetadata) {
            _log('Found kind 10002 event with ${event.tags.length} tags');
            receivedEvent = true;
            if (!completer.isCompleted) {
              completer.complete(event);
            }
          }
        } else if (messageType == 'EOSE' && message[1] == subscriptionId) {
          // End of stored events
          _log('Received EOSE - no kind 10002 event found on this relay');
          if (!receivedEvent && !completer.isCompleted) {
            completer.complete(null);
          }
        } else if (messageType == 'NOTICE') {
          _log(
            'Relay NOTICE: ${message.length > 1 ? message[1] : "no message"}',
          );
        } else if (messageType == 'CLOSED') {
          _log(
            'Subscription CLOSED: ${message.length > 2 ? message[2] : "no reason"}',
          );
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      };

      // Connect to relay
      final connected = await relay.connect().timeout(
        _fetchTimeout,
        onTimeout: () => false,
      );

      if (!connected) {
        _log('Failed to connect to indexer: $relayUrl');
        return null;
      }

      _log('Connected to indexer: $relayUrl');

      // Brief delay to ensure WebSocket is fully ready
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Send subscription request
      final filterJson = filter.toJson();
      _log('Sending REQ with filter: $filterJson');
      await relay.send(['REQ', subscriptionId, filterJson]);
      _log('REQ sent, waiting for response...');

      // Wait for result with timeout
      final event = await completer.future.timeout(
        _fetchTimeout,
        onTimeout: () {
          _log('Timeout waiting for kind 10002 event from $relayUrl');
          return null;
        },
      );

      // Cleanup
      await relay.send(['CLOSE', subscriptionId]);

      return event;
    } catch (e) {
      _log('Error fetching from $relayUrl: $e');
      return null;
    } finally {
      relay?.disconnect();
    }
  }

  /// Parses relay URLs from a kind 10002 event.
  ///
  /// Returns the union of all readable and writable relays.
  List<String> _parseRelaysFromEvent(Event event) {
    final metadata = RelayListMetadata.fromEvent(event);

    // Union of read and write relays
    final relaySet = <String>{
      ...metadata.readAbleRelays,
      ...metadata.writeAbleRelays,
    };

    return relaySet.toList();
  }

  void _log(String message) {
    developer.log('[Nip65RelayImportService] $message');
  }
}
