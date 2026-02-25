// ABOUTME: FCM push notification service for token registration via NIP-XX
// ABOUTME: Handles FCM token lifecycle, NIP-44 encrypted registration
// (kind 3079/3080), and foreground notification display

import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/auth_service_signer.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Push service pubkey for NIP-44 encryption of FCM tokens.
///
/// This is the public key of the divine-push-service that monitors
/// relay.divine.video for kind 3079/3080 events.
const pushServicePubkey =
    'd93716b5d8048f4ddde4c5a60bdb89fbff1cd813ac12f838cc6fff35a3383bc6';

/// Relay URL for push notification registration events.
const pushRegistrationRelay = 'wss://relay.divine.video';

/// NIP-XX event kind for push token registration.
const pushRegistrationKind = 3079;

/// NIP-XX event kind for push token deregistration.
const pushDeregistrationKind = 3080;

/// App identifier sent in NIP-XX registration events.
const pushAppIdentifier = 'divine';

/// Duration before token expiration to trigger auto-renewal.
const _renewalThreshold = Duration(days: 60);

/// Token registration validity period.
const _registrationValidity = Duration(days: 90);

/// Service managing FCM push notification token lifecycle.
///
/// Handles:
/// - FCM token retrieval and refresh monitoring
/// - NIP-44 encrypted token registration (kind 3079) to relay
/// - Token deregistration (kind 3080) on logout
/// - Auto-renewal before expiration
/// - Foreground notification display via [NotificationService]
class PushNotificationService {
  PushNotificationService({
    required AuthService authService,
    required NostrClient nostrClient,
    FirebaseMessaging? messaging,
    NotificationService? notificationService,
  }) : _authService = authService,
       _nostrClient = nostrClient,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _notificationService = notificationService;

  final AuthService _authService;
  final NostrClient _nostrClient;
  final FirebaseMessaging _messaging;
  final NotificationService? _notificationService;

  String? _currentToken;
  DateTime? _lastRegisteredAt;
  Timer? _renewalTimer;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _disposed = false;

  /// Current FCM token, if available.
  String? get currentToken => _currentToken;

  /// Whether push notifications are registered with the relay.
  bool get isRegistered => _currentToken != null && _lastRegisteredAt != null;

  /// Initialize the push notification service.
  ///
  /// Requests notification permissions, retrieves the FCM token,
  /// registers it with the relay, and starts listening for token
  /// refreshes.
  ///
  /// Throws [PushNotificationException] if initialization fails.
  Future<void> initialize() async {
    if (_disposed) return;

    Log.info(
      'Initializing PushNotificationService',
      name: 'PushNotificationService',
      category: LogCategory.system,
    );

    try {
      // Request notification permissions
      await _requestPermissions();

      // Get current FCM token
      final token = await _messaging.getToken();
      if (token == null) {
        Log.warning(
          'FCM token unavailable',
          name: 'PushNotificationService',
          category: LogCategory.system,
        );
        return;
      }

      _currentToken = token;
      Log.info(
        'FCM token retrieved',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );

      // Register token with relay
      await _registerToken(token);

      // Listen for token refreshes
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
        _onTokenRefresh,
      );

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Schedule auto-renewal
      _scheduleRenewal();

      Log.info(
        'PushNotificationService initialized',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
    } on Exception catch (e, stackTrace) {
      Log.error(
        'Failed to initialize push notifications: $e',
        name: 'PushNotificationService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Request notification permissions from the platform.
  Future<NotificationSettings> _requestPermissions() async {
    final settings = await _messaging.requestPermission();

    Log.info(
      'Push notification permission: '
      '${settings.authorizationStatus.name}',
      name: 'PushNotificationService',
      category: LogCategory.system,
    );

    return settings;
  }

  /// Register the FCM token with the push service via NIP-XX kind 3079.
  ///
  /// Creates a NIP-44 encrypted Nostr event containing the FCM token
  /// and publishes it to [pushRegistrationRelay].
  Future<void> _registerToken(String token) async {
    if (!_authService.isAuthenticated) {
      Log.warning(
        'Cannot register push token - user not authenticated',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    try {
      // Encrypt the token payload using NIP-44
      final payload = jsonEncode({'token': token});
      // Use remote signer if available, fall back to local keys
      final NostrSigner signer =
          _authService.rpcSigner ??
          AuthServiceSigner(_authService.currentKeyContainer);
      final encrypted = await signer.nip44Encrypt(pushServicePubkey, payload);

      if (encrypted == null) {
        Log.error(
          'Failed to NIP-44 encrypt FCM token',
          name: 'PushNotificationService',
          category: LogCategory.system,
        );
        return;
      }

      // Calculate expiration (90 days from now)
      final expiration = DateTime.now().add(_registrationValidity);
      final expirationSecs = (expiration.millisecondsSinceEpoch ~/ 1000)
          .toString();

      // Create and sign the registration event
      final event = await _authService.createAndSignEvent(
        kind: pushRegistrationKind,
        content: encrypted,
        tags: [
          ['p', pushServicePubkey],
          ['app', pushAppIdentifier],
          ['expiration', expirationSecs],
        ],
      );

      if (event == null) {
        Log.error(
          'Failed to create registration event',
          name: 'PushNotificationService',
          category: LogCategory.system,
        );
        return;
      }

      // Publish to relay
      await _nostrClient.publishEvent(
        event,
        targetRelays: [pushRegistrationRelay],
      );

      _lastRegisteredAt = DateTime.now();

      Log.info(
        'Push token registered (expires: $expirationSecs)',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
    } on Exception catch (e, stackTrace) {
      Log.error(
        'Failed to register push token: $e',
        name: 'PushNotificationService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Deregister the current FCM token via NIP-XX kind 3080.
  ///
  /// Call this on user logout to stop receiving push notifications.
  Future<void> deregister() async {
    if (_currentToken == null || !_authService.isAuthenticated) {
      return;
    }

    try {
      // Encrypt the token payload using NIP-44
      final payload = jsonEncode({'token': _currentToken});
      // Use remote signer if available, fall back to local keys
      final NostrSigner signer =
          _authService.rpcSigner ??
          AuthServiceSigner(_authService.currentKeyContainer);
      final encrypted = await signer.nip44Encrypt(pushServicePubkey, payload);

      if (encrypted == null) {
        Log.error(
          'Failed to NIP-44 encrypt FCM token for deregistration',
          name: 'PushNotificationService',
          category: LogCategory.system,
        );
        return;
      }

      // Create and sign the deregistration event
      final event = await _authService.createAndSignEvent(
        kind: pushDeregistrationKind,
        content: encrypted,
        tags: [
          ['p', pushServicePubkey],
          ['app', pushAppIdentifier],
        ],
      );

      if (event == null) {
        Log.error(
          'Failed to create deregistration event',
          name: 'PushNotificationService',
          category: LogCategory.system,
        );
        return;
      }

      // Publish to relay
      await _nostrClient.publishEvent(
        event,
        targetRelays: [pushRegistrationRelay],
      );

      Log.info(
        'Push token deregistered',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );

      _currentToken = null;
      _lastRegisteredAt = null;
      _renewalTimer?.cancel();
    } on Exception catch (e, stackTrace) {
      Log.error(
        'Failed to deregister push token: $e',
        name: 'PushNotificationService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Handle FCM token refresh by re-registering with the relay.
  Future<void> _onTokenRefresh(String newToken) async {
    if (_disposed) return;

    Log.info(
      'FCM token refreshed, re-registering',
      name: 'PushNotificationService',
      category: LogCategory.system,
    );

    _currentToken = newToken;
    await _registerToken(newToken);
    _scheduleRenewal();
  }

  /// Handle foreground FCM messages by showing a local notification.
  ///
  /// The push service sends **data-only** FCM messages (`notification: null`)
  /// rather than display messages. This gives the client full control:
  /// the app can silently process, aggregate, or ignore messages, and
  /// supports structured payloads (eventId, senderPubkey, type) beyond
  /// simple title/body. Title and body are read from [RemoteMessage.data].
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    if (_disposed) return;

    final title = message.data['title'] as String? ?? 'divine';
    final body = message.data['body'] as String? ?? '';

    Log.debug(
      'Foreground push received: $title',
      name: 'PushNotificationService',
      category: LogCategory.system,
    );

    // Show via existing local notification service
    final ns = _notificationService ?? NotificationService.instance;
    await ns.sendLocal(title: title, body: body);
  }

  /// Schedule auto-renewal of the push token registration.
  ///
  /// Renews at [_renewalThreshold] (60 days) before the 90-day
  /// expiration to ensure continuous push delivery.
  void _scheduleRenewal() {
    _renewalTimer?.cancel();

    if (_lastRegisteredAt == null || _currentToken == null) return;

    final renewAt = _lastRegisteredAt!.add(_renewalThreshold);
    final delay = renewAt.difference(DateTime.now());

    if (delay.isNegative) {
      // Already past renewal threshold, renew immediately
      _renewRegistration();
      return;
    }

    _renewalTimer = Timer(delay, _renewRegistration);

    Log.debug(
      'Push token renewal scheduled in ${delay.inDays} days',
      name: 'PushNotificationService',
      category: LogCategory.system,
    );
  }

  /// Re-register the current token with the relay.
  Future<void> _renewRegistration() async {
    if (_disposed || _currentToken == null) return;

    Log.info(
      'Renewing push token registration',
      name: 'PushNotificationService',
      category: LogCategory.system,
    );

    await _registerToken(_currentToken!);
    _scheduleRenewal();
  }

  /// Clean up resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _renewalTimer?.cancel();
    _tokenRefreshSubscription?.cancel();

    Log.debug(
      'PushNotificationService disposed',
      name: 'PushNotificationService',
      category: LogCategory.system,
    );
  }
}

/// Exception for push notification operations.
class PushNotificationException implements Exception {
  const PushNotificationException(this.message);

  final String message;

  @override
  String toString() => 'PushNotificationException: $message';
}
