// ABOUTME: Represents a client-initiated NIP-46 connection (nostrconnect://)
// ABOUTME: Unlike bunker://, the client generates the URL for bunker to scan

import 'dart:math';

import '../client_utils/keys.dart';
import '../nip19/nip19.dart';
import '../utils/string_util.dart';

/// Represents a client-initiated NIP-46 connection (nostrconnect://).
///
/// Unlike [NostrRemoteSignerInfo] (bunker://), this is initiated by the client:
/// - Client generates ephemeral keypair
/// - Client creates nostrconnect:// URL with its pubkey
/// - User scans QR code with bunker app (Amber, Nsec.app, etc.)
/// - Bunker sends connect RESPONSE (not request) to client
/// - Client validates the secret in the response
/// - Client discovers remoteSignerPubkey from response event author
class NostrConnectInfo {
  /// Client's ephemeral public key (hex format).
  /// This is the pubkey in the nostrconnect:// URL.
  final String clientPubkey;

  /// Relay URLs for communication between client and bunker.
  final List<String> relays;

  /// Required secret for security (prevents spoofing).
  /// The bunker must return this in its connect response.
  final String secret;

  /// App name displayed to user in bunker approval screen.
  final String? appName;

  /// App URL for verification in bunker.
  final String? appUrl;

  /// App icon URL displayed in bunker.
  final String? appImage;

  /// Requested permissions (comma-separated).
  /// e.g., "sign_event,get_public_key,nip44_encrypt,nip44_decrypt"
  final String? permissions;

  /// Client's ephemeral nsec (stored for session use).
  /// Used to encrypt/decrypt NIP-46 messages.
  String? clientNsec;

  /// Remote signer's public key (discovered from connect response author).
  String? remoteSignerPubkey;

  /// User's public key (retrieved via get_public_key after connect).
  String? userPubkey;

  NostrConnectInfo({
    required this.clientPubkey,
    required this.relays,
    required this.secret,
    this.appName,
    this.appUrl,
    this.appImage,
    this.permissions,
    this.clientNsec,
    this.remoteSignerPubkey,
    this.userPubkey,
  });

  /// Creates a new [NostrConnectInfo] with generated ephemeral keypair and secret.
  ///
  /// Use this to start a new nostrconnect session.
  factory NostrConnectInfo.generate({
    required List<String> relays,
    String? appName,
    String? appUrl,
    String? appImage,
    String? permissions,
  }) {
    // Generate ephemeral keypair for this session
    final privateKeyHex = generatePrivateKey();
    final nsec = Nip19.encodePrivateKey(privateKeyHex);
    final pubkeyHex = getPublicKey(privateKeyHex);

    return NostrConnectInfo(
      clientPubkey: pubkeyHex,
      relays: relays,
      secret: generateSecret(),
      appName: appName,
      appUrl: appUrl,
      appImage: appImage,
      permissions: permissions,
      clientNsec: nsec,
    );
  }

  /// Generates a nostrconnect:// URL for display as QR code.
  ///
  /// Format per NIP-46:
  /// ```
  /// nostrconnect://<client-pubkey>?relay=wss://...&secret=...&name=...&url=...&perms=...
  /// ```
  String toNostrConnectUrl() {
    final params = <String, dynamic>{};
    params['relay'] = relays;
    params['secret'] = secret;

    if (appName != null && appName!.isNotEmpty) {
      params['name'] = appName;
    }
    if (appUrl != null && appUrl!.isNotEmpty) {
      params['url'] = appUrl;
    }
    if (appImage != null && appImage!.isNotEmpty) {
      params['image'] = appImage;
    }
    if (permissions != null && permissions!.isNotEmpty) {
      params['perms'] = permissions;
    }

    final uri = Uri(
      scheme: 'nostrconnect',
      host: clientPubkey,
      queryParameters: params,
    );

    return uri.toString();
  }

  /// Checks if a string is a nostrconnect:// URL.
  static bool isNostrConnectUrl(String? url) {
    if (url != null) {
      return url.startsWith('nostrconnect://');
    }
    return false;
  }

  /// Parses a nostrconnect:// URL into a [NostrConnectInfo] object.
  ///
  /// Returns null if the URL is invalid or missing required fields.
  static NostrConnectInfo? parseNostrConnectUrl(String url) {
    if (!isNostrConnectUrl(url)) {
      return null;
    }

    try {
      final uri = Uri.parse(url);
      final params = uri.queryParametersAll;

      final clientPubkey = uri.host;
      if (StringUtil.isBlank(clientPubkey)) {
        return null;
      }

      final relays = params['relay'];
      if (relays == null || relays.isEmpty) {
        return null;
      }

      // Secret is required for nostrconnect://
      final secrets = params['secret'];
      if (secrets == null || secrets.isEmpty) {
        return null;
      }
      final secret = secrets.first;

      // Optional fields
      String? appName;
      if (params['name'] != null && params['name']!.isNotEmpty) {
        appName = params['name']!.first;
      }

      String? appUrl;
      if (params['url'] != null && params['url']!.isNotEmpty) {
        appUrl = params['url']!.first;
      }

      String? appImage;
      if (params['image'] != null && params['image']!.isNotEmpty) {
        appImage = params['image']!.first;
      }

      String? permissions;
      if (params['perms'] != null && params['perms']!.isNotEmpty) {
        permissions = params['perms']!.first;
      }

      return NostrConnectInfo(
        clientPubkey: clientPubkey,
        relays: relays,
        secret: secret,
        appName: appName,
        appUrl: appUrl,
        appImage: appImage,
        permissions: permissions,
      );
    } catch (e) {
      return null;
    }
  }

  /// Generates a random secret string for nostrconnect:// URLs.
  ///
  /// Per NIP-46, the secret is required and should be a short random string.
  /// Returns an 8-character hex string.
  static String generateSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(4, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Creates a copy with updated fields.
  NostrConnectInfo copyWith({
    String? clientPubkey,
    List<String>? relays,
    String? secret,
    String? appName,
    String? appUrl,
    String? appImage,
    String? permissions,
    String? clientNsec,
    String? remoteSignerPubkey,
    String? userPubkey,
  }) {
    return NostrConnectInfo(
      clientPubkey: clientPubkey ?? this.clientPubkey,
      relays: relays ?? this.relays,
      secret: secret ?? this.secret,
      appName: appName ?? this.appName,
      appUrl: appUrl ?? this.appUrl,
      appImage: appImage ?? this.appImage,
      permissions: permissions ?? this.permissions,
      clientNsec: clientNsec ?? this.clientNsec,
      remoteSignerPubkey: remoteSignerPubkey ?? this.remoteSignerPubkey,
      userPubkey: userPubkey ?? this.userPubkey,
    );
  }

  @override
  String toString() => toNostrConnectUrl();
}
