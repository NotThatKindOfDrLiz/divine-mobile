import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip65_relay_import_service.dart';
import 'package:openvine/services/nostr_service_factory.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'nostr_client_provider.g.dart';

/// Core Nostr service via NostrClient for relay communication
/// Uses a Notifier to react to auth state changes and recreate the client
/// when the keyContainer changes (e.g., user signs out and signs in with different keys)
@Riverpod(keepAlive: true)
class NostrService extends _$NostrService {
  StreamSubscription<AuthState>? _authSubscription;
  String? _lastPubkey;

  @override
  NostrClient build() {
    final authService = ref.watch(authServiceProvider);
    final statisticsService = ref.watch(relayStatisticsServiceProvider);
    final environmentConfig = ref.watch(currentEnvironmentProvider);
    final dbClient = ref.watch(appDbClientProvider);

    _lastPubkey = authService.currentPublicKeyHex;

    _authSubscription?.cancel();
    _authSubscription = authService.authStateStream.listen(_onAuthStateChanged);

    // Create initial NostrClient (prefer RPC signer when available)
    // Pass pubkey for per-user relay storage
    final client = NostrServiceFactory.create(
      keyContainer: authService.currentKeyContainer,
      statisticsService: statisticsService,
      environmentConfig: environmentConfig,
      dbClient: dbClient,
      pubkey: authService.currentPublicKeyHex,
      rpcSigner: authService.rpcSigner,
    );

    // Schedule initialization after build completes
    // This ensures relays are connected when the client is first used
    Future.microtask(() async {
      try {
        // Check if we need to import relays from NIP-65
        final initialRelays = await _fetchNip65RelaysIfNeeded(
          authService.currentPublicKeyHex,
          environmentConfig.relayUrl,
        );

        await client.initialize(initialRelays: initialRelays);
        Log.info(
          '[NostrService] Client initialized via build()',
          name: 'NostrService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          '[NostrService] Failed to initialize client in build(): $e',
          name: 'NostrService',
          category: LogCategory.system,
        );
      }
    });

    // Capture client reference for disposal - can't access state inside onDispose
    ref.onDispose(() {
      _authSubscription?.cancel();
      client.dispose();
    });

    return client;
  }

  Future<void> _onAuthStateChanged(AuthState newState) async {
    final authService = ref.read(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex;

    if (currentPubkey != _lastPubkey) {
      Log.info(
        '[NostrService] Public key changed from $_lastPubkey to $currentPubkey, '
        'recreating NostrClient',
        name: 'NostrService',
        category: LogCategory.system,
      );

      state.dispose();

      // Create new client with updated signer and public key
      final statisticsService = ref.read(relayStatisticsServiceProvider);
      final environmentConfig = ref.read(currentEnvironmentProvider);
      final dbClient = ref.read(appDbClientProvider);

      final newClient = NostrServiceFactory.create(
        keyContainer: authService.currentKeyContainer,
        statisticsService: statisticsService,
        environmentConfig: environmentConfig,
        dbClient: dbClient,
        pubkey: currentPubkey,
        rpcSigner: authService.rpcSigner,
      );

      _lastPubkey = currentPubkey;

      // Check if we need to import relays from NIP-65 for the new user
      final initialRelays = await _fetchNip65RelaysIfNeeded(
        currentPubkey,
        environmentConfig.relayUrl,
      );

      // Initialize the new client
      await newClient.initialize(initialRelays: initialRelays);
      state = newClient;
    }
  }

  /// Fetches NIP-65 relay list if storage is empty and user is authenticated.
  ///
  /// Returns the list of relays to use as initial configuration, or null
  /// if relays are already stored locally.
  Future<List<String>?> _fetchNip65RelaysIfNeeded(
    String? pubkey,
    String defaultRelayUrl,
  ) async {
    // No user authenticated, skip NIP-65 import
    if (pubkey == null || pubkey.isEmpty) {
      return null;
    }

    // Check if relays are already stored locally for this user
    final storage = SharedPreferencesRelayStorage.forUser(pubkey: pubkey);
    final savedRelays = await storage.loadRelays();

    if (savedRelays.isNotEmpty) {
      Log.info(
        '[NostrService] Found ${savedRelays.length} stored relays, '
        'skipping NIP-65 import',
        name: 'NostrService',
        category: LogCategory.system,
      );
      return null;
    }

    // No stored relays, attempt NIP-65 import
    Log.info(
      '[NostrService] No stored relays, attempting NIP-65 import for $pubkey',
      name: 'NostrService',
      category: LogCategory.system,
    );

    final importService = Nip65RelayImportService(
      defaultRelayUrl: defaultRelayUrl,
    );
    final result = await importService.fetchRelayList(pubkey);

    Log.info(
      '[NostrService] NIP-65 import result: ${result.source.name}, '
      '${result.relays.length} relays',
      name: 'NostrService',
      category: LogCategory.system,
    );

    return result.relays;
  }
}
