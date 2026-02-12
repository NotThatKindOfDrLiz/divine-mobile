// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'npub_verification_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for NpubVerificationBloc instance.
///
/// This is created as a Riverpod provider so it can be accessed in both:
/// - The router (for AppStateListenable)
/// - The widget tree (via BlocProvider.value)

@ProviderFor(npubVerificationBloc)
const npubVerificationBlocProvider = NpubVerificationBlocProvider._();

/// Provider for NpubVerificationBloc instance.
///
/// This is created as a Riverpod provider so it can be accessed in both:
/// - The router (for AppStateListenable)
/// - The widget tree (via BlocProvider.value)

final class NpubVerificationBlocProvider
    extends
        $FunctionalProvider<
          NpubVerificationBloc,
          NpubVerificationBloc,
          NpubVerificationBloc
        >
    with $Provider<NpubVerificationBloc> {
  /// Provider for NpubVerificationBloc instance.
  ///
  /// This is created as a Riverpod provider so it can be accessed in both:
  /// - The router (for AppStateListenable)
  /// - The widget tree (via BlocProvider.value)
  const NpubVerificationBlocProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'npubVerificationBlocProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$npubVerificationBlocHash();

  @$internal
  @override
  $ProviderElement<NpubVerificationBloc> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NpubVerificationBloc create(Ref ref) {
    return npubVerificationBloc(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NpubVerificationBloc value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NpubVerificationBloc>(value),
    );
  }
}

String _$npubVerificationBlocHash() =>
    r'e6322a67d2def3d32c13b002e5a47ccd0e858f29';

/// Provider for NpubVerificationRepository instance.
///
/// Lightweight provider for npub verification storage - safe for router redirects.

@ProviderFor(npubVerificationRepository)
const npubVerificationRepositoryProvider =
    NpubVerificationRepositoryProvider._();

/// Provider for NpubVerificationRepository instance.
///
/// Lightweight provider for npub verification storage - safe for router redirects.

final class NpubVerificationRepositoryProvider
    extends
        $FunctionalProvider<
          NpubVerificationRepository,
          NpubVerificationRepository,
          NpubVerificationRepository
        >
    with $Provider<NpubVerificationRepository> {
  /// Provider for NpubVerificationRepository instance.
  ///
  /// Lightweight provider for npub verification storage - safe for router redirects.
  const NpubVerificationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'npubVerificationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$npubVerificationRepositoryHash();

  @$internal
  @override
  $ProviderElement<NpubVerificationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NpubVerificationRepository create(Ref ref) {
    return npubVerificationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NpubVerificationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NpubVerificationRepository>(value),
    );
  }
}

String _$npubVerificationRepositoryHash() =>
    r'40d48fafe495332cd78d30de56b6c4d82f58750b';

/// Provider for NpubVerificationService instance.
///
/// Uses keepAlive to maintain singleton behavior across navigation.
/// Reuses device ID from InviteCodeService.

@ProviderFor(npubVerificationService)
const npubVerificationServiceProvider = NpubVerificationServiceProvider._();

/// Provider for NpubVerificationService instance.
///
/// Uses keepAlive to maintain singleton behavior across navigation.
/// Reuses device ID from InviteCodeService.

final class NpubVerificationServiceProvider
    extends
        $FunctionalProvider<
          NpubVerificationService,
          NpubVerificationService,
          NpubVerificationService
        >
    with $Provider<NpubVerificationService> {
  /// Provider for NpubVerificationService instance.
  ///
  /// Uses keepAlive to maintain singleton behavior across navigation.
  /// Reuses device ID from InviteCodeService.
  const NpubVerificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'npubVerificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$npubVerificationServiceHash();

  @$internal
  @override
  $ProviderElement<NpubVerificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NpubVerificationService create(Ref ref) {
    return npubVerificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NpubVerificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NpubVerificationService>(value),
    );
  }
}

String _$npubVerificationServiceHash() =>
    r'2d6a91d1f69f30848f6d9f16de17ad1e7d9433cc';

/// Synchronous provider that checks if current user's npub is verified.
///
/// Returns true if:
/// - User has a valid invite code (skip verification entirely), OR
/// - User's npub has been verified with the server
///
/// Use this for router redirect logic.

@ProviderFor(isNpubVerified)
const isNpubVerifiedProvider = IsNpubVerifiedProvider._();

/// Synchronous provider that checks if current user's npub is verified.
///
/// Returns true if:
/// - User has a valid invite code (skip verification entirely), OR
/// - User's npub has been verified with the server
///
/// Use this for router redirect logic.

final class IsNpubVerifiedProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Synchronous provider that checks if current user's npub is verified.
  ///
  /// Returns true if:
  /// - User has a valid invite code (skip verification entirely), OR
  /// - User's npub has been verified with the server
  ///
  /// Use this for router redirect logic.
  const IsNpubVerifiedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isNpubVerifiedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isNpubVerifiedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isNpubVerified(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isNpubVerifiedHash() => r'4fa6f54ea80f3646680a9bf5bd342412c58ec1b0';

/// Provider that checks if user needs npub verification.
///
/// Returns true if:
/// - User is authenticated AND
/// - User does NOT have an invite code AND
/// - User's npub is NOT yet verified
///
/// Use this in router redirect to gate access to home/explore.

@ProviderFor(needsNpubVerification)
const needsNpubVerificationProvider = NeedsNpubVerificationProvider._();

/// Provider that checks if user needs npub verification.
///
/// Returns true if:
/// - User is authenticated AND
/// - User does NOT have an invite code AND
/// - User's npub is NOT yet verified
///
/// Use this in router redirect to gate access to home/explore.

final class NeedsNpubVerificationProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider that checks if user needs npub verification.
  ///
  /// Returns true if:
  /// - User is authenticated AND
  /// - User does NOT have an invite code AND
  /// - User's npub is NOT yet verified
  ///
  /// Use this in router redirect to gate access to home/explore.
  const NeedsNpubVerificationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'needsNpubVerificationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$needsNpubVerificationHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return needsNpubVerification(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$needsNpubVerificationHash() =>
    r'de4d5b81700282ff05625f6ec555ce8e7d49f4c0';
