// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_notification_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider managing push notification registration lifecycle.
///
/// Watches auth state to automatically:
/// - Register FCM token on login
/// - Deregister on logout
/// - Re-register on token refresh
///
/// Skips initialization on web platform where FCM is not supported.

@ProviderFor(PushNotifications)
const pushNotificationsProvider = PushNotificationsProvider._();

/// Provider managing push notification registration lifecycle.
///
/// Watches auth state to automatically:
/// - Register FCM token on login
/// - Deregister on logout
/// - Re-register on token refresh
///
/// Skips initialization on web platform where FCM is not supported.
final class PushNotificationsProvider
    extends $NotifierProvider<PushNotifications, PushNotificationState> {
  /// Provider managing push notification registration lifecycle.
  ///
  /// Watches auth state to automatically:
  /// - Register FCM token on login
  /// - Deregister on logout
  /// - Re-register on token refresh
  ///
  /// Skips initialization on web platform where FCM is not supported.
  const PushNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushNotificationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushNotificationsHash();

  @$internal
  @override
  PushNotifications create() => PushNotifications();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushNotificationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushNotificationState>(value),
    );
  }
}

String _$pushNotificationsHash() => r'38a5ddd05d23a4116f7f9ad9941c2c550b7bd113';

/// Provider managing push notification registration lifecycle.
///
/// Watches auth state to automatically:
/// - Register FCM token on login
/// - Deregister on logout
/// - Re-register on token refresh
///
/// Skips initialization on web platform where FCM is not supported.

abstract class _$PushNotifications extends $Notifier<PushNotificationState> {
  PushNotificationState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PushNotificationState, PushNotificationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PushNotificationState, PushNotificationState>,
              PushNotificationState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
