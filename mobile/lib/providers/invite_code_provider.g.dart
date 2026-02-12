// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_code_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for InviteCodeBloc instance.
///
/// This is created as a Riverpod provider so it can be accessed in both:
/// - The router (for AppStateListenable)
/// - The widget tree (via BlocProvider.value)

@ProviderFor(inviteCodeBloc)
const inviteCodeBlocProvider = InviteCodeBlocProvider._();

/// Provider for InviteCodeBloc instance.
///
/// This is created as a Riverpod provider so it can be accessed in both:
/// - The router (for AppStateListenable)
/// - The widget tree (via BlocProvider.value)

final class InviteCodeBlocProvider
    extends $FunctionalProvider<InviteCodeBloc, InviteCodeBloc, InviteCodeBloc>
    with $Provider<InviteCodeBloc> {
  /// Provider for InviteCodeBloc instance.
  ///
  /// This is created as a Riverpod provider so it can be accessed in both:
  /// - The router (for AppStateListenable)
  /// - The widget tree (via BlocProvider.value)
  const InviteCodeBlocProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inviteCodeBlocProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inviteCodeBlocHash();

  @$internal
  @override
  $ProviderElement<InviteCodeBloc> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InviteCodeBloc create(Ref ref) {
    return inviteCodeBloc(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InviteCodeBloc value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InviteCodeBloc>(value),
    );
  }
}

String _$inviteCodeBlocHash() => r'8c214575d7d6d18208fcbb4adb59c0bac5a0a4bf';

/// Provider for InviteCodeRepository instance.
///
/// Lightweight provider for invite code storage - safe for router redirects.

@ProviderFor(inviteCodeRepository)
const inviteCodeRepositoryProvider = InviteCodeRepositoryProvider._();

/// Provider for InviteCodeRepository instance.
///
/// Lightweight provider for invite code storage - safe for router redirects.

final class InviteCodeRepositoryProvider
    extends
        $FunctionalProvider<
          InviteCodeRepository,
          InviteCodeRepository,
          InviteCodeRepository
        >
    with $Provider<InviteCodeRepository> {
  /// Provider for InviteCodeRepository instance.
  ///
  /// Lightweight provider for invite code storage - safe for router redirects.
  const InviteCodeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inviteCodeRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inviteCodeRepositoryHash();

  @$internal
  @override
  $ProviderElement<InviteCodeRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InviteCodeRepository create(Ref ref) {
    return inviteCodeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InviteCodeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InviteCodeRepository>(value),
    );
  }
}

String _$inviteCodeRepositoryHash() =>
    r'22eedceffb41a3afa4ae6e7ad519fc1e93ff3916';

/// Provider for InviteCodeService instance.
///
/// Uses keepAlive to maintain singleton behavior across navigation.

@ProviderFor(inviteCodeService)
const inviteCodeServiceProvider = InviteCodeServiceProvider._();

/// Provider for InviteCodeService instance.
///
/// Uses keepAlive to maintain singleton behavior across navigation.

final class InviteCodeServiceProvider
    extends
        $FunctionalProvider<
          InviteCodeService,
          InviteCodeService,
          InviteCodeService
        >
    with $Provider<InviteCodeService> {
  /// Provider for InviteCodeService instance.
  ///
  /// Uses keepAlive to maintain singleton behavior across navigation.
  const InviteCodeServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inviteCodeServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inviteCodeServiceHash();

  @$internal
  @override
  $ProviderElement<InviteCodeService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InviteCodeService create(Ref ref) {
    return inviteCodeService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InviteCodeService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InviteCodeService>(value),
    );
  }
}

String _$inviteCodeServiceHash() => r'717f076cbe3c8496b4d47294b46142a0653148a7';

/// Synchronous check if an invite code is stored locally.
///
/// Use this for router redirect logic - it does NOT verify with server.
/// For full verification, use [inviteCodeVerificationProvider].

@ProviderFor(hasStoredInviteCode)
const hasStoredInviteCodeProvider = HasStoredInviteCodeProvider._();

/// Synchronous check if an invite code is stored locally.
///
/// Use this for router redirect logic - it does NOT verify with server.
/// For full verification, use [inviteCodeVerificationProvider].

final class HasStoredInviteCodeProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Synchronous check if an invite code is stored locally.
  ///
  /// Use this for router redirect logic - it does NOT verify with server.
  /// For full verification, use [inviteCodeVerificationProvider].
  const HasStoredInviteCodeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasStoredInviteCodeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasStoredInviteCodeHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return hasStoredInviteCode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hasStoredInviteCodeHash() =>
    r'0346dd9c8e9f335e25739b943b16d516afae7ba2';

/// Async verification of stored invite code with server.
///
/// Returns InviteCodeResult with validity status.
/// Use [hasStoredInviteCodeProvider] for synchronous checks in redirects.

@ProviderFor(inviteCodeVerification)
const inviteCodeVerificationProvider = InviteCodeVerificationProvider._();

/// Async verification of stored invite code with server.
///
/// Returns InviteCodeResult with validity status.
/// Use [hasStoredInviteCodeProvider] for synchronous checks in redirects.

final class InviteCodeVerificationProvider
    extends
        $FunctionalProvider<
          AsyncValue<InviteCodeResult>,
          InviteCodeResult,
          FutureOr<InviteCodeResult>
        >
    with $FutureModifier<InviteCodeResult>, $FutureProvider<InviteCodeResult> {
  /// Async verification of stored invite code with server.
  ///
  /// Returns InviteCodeResult with validity status.
  /// Use [hasStoredInviteCodeProvider] for synchronous checks in redirects.
  const InviteCodeVerificationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inviteCodeVerificationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inviteCodeVerificationHash();

  @$internal
  @override
  $FutureProviderElement<InviteCodeResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InviteCodeResult> create(Ref ref) {
    return inviteCodeVerification(ref);
  }
}

String _$inviteCodeVerificationHash() =>
    r'ee8bb989943ca6122f055134c1aa6e67b7e4577b';
