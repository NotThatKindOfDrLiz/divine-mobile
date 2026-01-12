// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_provider_cache_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages LRU cache for profile feed providers.
///
/// Tracks the most recently accessed user profiles and automatically
/// invalidates providers for older profiles when the cache limit is exceeded.
///
/// Usage:
/// ```dart
/// // In profile grid widgets:
/// ref.read(profileProviderCacheManagerProvider.notifier).recordAccess(userId);
/// ```

@ProviderFor(ProfileProviderCacheManager)
const profileProviderCacheManagerProvider =
    ProfileProviderCacheManagerProvider._();

/// Manages LRU cache for profile feed providers.
///
/// Tracks the most recently accessed user profiles and automatically
/// invalidates providers for older profiles when the cache limit is exceeded.
///
/// Usage:
/// ```dart
/// // In profile grid widgets:
/// ref.read(profileProviderCacheManagerProvider.notifier).recordAccess(userId);
/// ```
final class ProfileProviderCacheManagerProvider
    extends $NotifierProvider<ProfileProviderCacheManager, List<String>> {
  /// Manages LRU cache for profile feed providers.
  ///
  /// Tracks the most recently accessed user profiles and automatically
  /// invalidates providers for older profiles when the cache limit is exceeded.
  ///
  /// Usage:
  /// ```dart
  /// // In profile grid widgets:
  /// ref.read(profileProviderCacheManagerProvider.notifier).recordAccess(userId);
  /// ```
  const ProfileProviderCacheManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileProviderCacheManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileProviderCacheManagerHash();

  @$internal
  @override
  ProfileProviderCacheManager create() => ProfileProviderCacheManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$profileProviderCacheManagerHash() =>
    r'8cdfe099ee9816177f45e350afa6beeb8282e6ec';

/// Manages LRU cache for profile feed providers.
///
/// Tracks the most recently accessed user profiles and automatically
/// invalidates providers for older profiles when the cache limit is exceeded.
///
/// Usage:
/// ```dart
/// // In profile grid widgets:
/// ref.read(profileProviderCacheManagerProvider.notifier).recordAccess(userId);
/// ```

abstract class _$ProfileProviderCacheManager extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<String>, List<String>>,
              List<String>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
