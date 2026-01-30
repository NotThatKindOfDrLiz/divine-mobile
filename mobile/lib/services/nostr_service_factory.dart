// ABOUTME: Factory for creating NostrClient instances
// ABOUTME: Handles platform-appropriate client creation with proper configuration

import 'package:db_client/db_client.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/auth_service_signer.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Factory class for creating NostrClient instances
class NostrServiceFactory {
  /// Create a NostrClient for the current platform
  ///
  /// Takes [keyContainer] directly since the nostrServiceProvider rebuilds
  /// when auth state changes, ensuring the key container is always current.
  ///
  /// Takes [environmentConfig] to determine the relay URL to use.
  /// If not provided, falls back to [AppConstants.defaultRelayUrl].
  ///
  /// Takes [dbClient] for local event caching with optimistic updates.
  ///
  /// Takes [pubkey] to store relay configuration per-user. If not provided,
  /// a shared storage key is used (not recommended for multi-user apps).
  static NostrClient create({
    SecureKeyContainer? keyContainer,
    RelayStatisticsService? statisticsService,
    EnvironmentConfig? environmentConfig,
    AppDbClient? dbClient,
    String? pubkey,

    /// Optional remote RPC signer (e.g. `KeycastRpc`). If provided, this
    /// signer will be used instead of the local `AuthServiceSigner`.
    NostrSigner? rpcSigner,
  }) {
    UnifiedLogger.info(
      'Creating NostrClient via factory',
      name: 'NostrServiceFactory',
    );

    // Prefer RPC signer when available (KeycastRpc implements NostrSigner),
    // otherwise fall back to local signer that uses the secure key container.
    // The signer is the single source of truth for the public key.
    final signer = rpcSigner ?? AuthServiceSigner(keyContainer);

    // Create NostrClient config - signer is the source of truth for publicKey
    final config = NostrClientConfig(signer: signer);

    // Create relay manager config with persistent storage
    // Use relay URL from environment config if provided, otherwise fall back to default
    // Use per-user storage when pubkey is provided to isolate relay configs
    final relayUrl =
        environmentConfig?.relayUrl ?? AppConstants.defaultRelayUrl;
    final storage = pubkey != null
        ? SharedPreferencesRelayStorage.forUser(pubkey: pubkey)
        : SharedPreferencesRelayStorage();
    final relayManagerConfig = RelayManagerConfig(
      defaultRelayUrl: relayUrl,
      storage: storage,
    );

    // Create the NostrClient
    return NostrClient(
      config: config,
      relayManagerConfig: relayManagerConfig,
      dbClient: dbClient,
    );
  }

  /// Initialize the created client
  static Future<void> initialize(NostrClient client) async {
    await client.initialize();
  }
}
