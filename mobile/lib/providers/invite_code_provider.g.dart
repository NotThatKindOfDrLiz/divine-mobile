// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_code_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

/// State notifier for invite code entry/claiming.
///
/// Manages the async state of claiming an invite code.
/// Uses keepAlive to prevent disposal during async operations.

@ProviderFor(InviteCodeClaim)
const inviteCodeClaimProvider = InviteCodeClaimProvider._();

/// State notifier for invite code entry/claiming.
///
/// Manages the async state of claiming an invite code.
/// Uses keepAlive to prevent disposal during async operations.
final class InviteCodeClaimProvider
    extends $NotifierProvider<InviteCodeClaim, AsyncValue<InviteCodeResult?>> {
  /// State notifier for invite code entry/claiming.
  ///
  /// Manages the async state of claiming an invite code.
  /// Uses keepAlive to prevent disposal during async operations.
  const InviteCodeClaimProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inviteCodeClaimProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inviteCodeClaimHash();

  @$internal
  @override
  InviteCodeClaim create() => InviteCodeClaim();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<InviteCodeResult?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<InviteCodeResult?>>(
        value,
      ),
    );
  }
}

String _$inviteCodeClaimHash() => r'391793fa80efac92e3e26f18b96a0f178fe1316b';

/// State notifier for invite code entry/claiming.
///
/// Manages the async state of claiming an invite code.
/// Uses keepAlive to prevent disposal during async operations.

abstract class _$InviteCodeClaim
    extends $Notifier<AsyncValue<InviteCodeResult?>> {
  AsyncValue<InviteCodeResult?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              AsyncValue<InviteCodeResult?>,
              AsyncValue<InviteCodeResult?>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<InviteCodeResult?>,
                AsyncValue<InviteCodeResult?>
              >,
              AsyncValue<InviteCodeResult?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider to store pending invite code from deep link.
///
/// When a deep link like https://divine.video/invite/ABC123 is received,
/// the code is stored here so the InviteCodeScreen can auto-fill it.

@ProviderFor(PendingInviteCode)
const pendingInviteCodeProvider = PendingInviteCodeProvider._();

/// Provider to store pending invite code from deep link.
///
/// When a deep link like https://divine.video/invite/ABC123 is received,
/// the code is stored here so the InviteCodeScreen can auto-fill it.
final class PendingInviteCodeProvider
    extends $NotifierProvider<PendingInviteCode, String?> {
  /// Provider to store pending invite code from deep link.
  ///
  /// When a deep link like https://divine.video/invite/ABC123 is received,
  /// the code is stored here so the InviteCodeScreen can auto-fill it.
  const PendingInviteCodeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingInviteCodeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingInviteCodeHash();

  @$internal
  @override
  PendingInviteCode create() => PendingInviteCode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$pendingInviteCodeHash() => r'195ba58af5d7ca54fb657f32d91fdace294a0984';

/// Provider to store pending invite code from deep link.
///
/// When a deep link like https://divine.video/invite/ABC123 is received,
/// the code is stored here so the InviteCodeScreen can auto-fill it.

abstract class _$PendingInviteCode extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
