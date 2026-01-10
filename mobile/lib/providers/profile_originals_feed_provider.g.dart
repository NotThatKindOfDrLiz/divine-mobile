// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_originals_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Feed provider for user's original videos (excluding reposts)
///
/// Provides VideoFeedState with loadMore() support for use in
/// FullscreenVideoFeedScreen with ProfileOriginalsFeedSource.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileOriginalsFeedProvider(userId));
/// await ref.read(profileOriginalsFeedProvider(userId).notifier).loadMore();
/// ```

@ProviderFor(ProfileOriginalsFeed)
const profileOriginalsFeedProvider = ProfileOriginalsFeedFamily._();

/// Feed provider for user's original videos (excluding reposts)
///
/// Provides VideoFeedState with loadMore() support for use in
/// FullscreenVideoFeedScreen with ProfileOriginalsFeedSource.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileOriginalsFeedProvider(userId));
/// await ref.read(profileOriginalsFeedProvider(userId).notifier).loadMore();
/// ```
final class ProfileOriginalsFeedProvider
    extends $AsyncNotifierProvider<ProfileOriginalsFeed, VideoFeedState> {
  /// Feed provider for user's original videos (excluding reposts)
  ///
  /// Provides VideoFeedState with loadMore() support for use in
  /// FullscreenVideoFeedScreen with ProfileOriginalsFeedSource.
  ///
  /// Usage:
  /// ```dart
  /// final feed = ref.watch(profileOriginalsFeedProvider(userId));
  /// await ref.read(profileOriginalsFeedProvider(userId).notifier).loadMore();
  /// ```
  const ProfileOriginalsFeedProvider._({
    required ProfileOriginalsFeedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileOriginalsFeedProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileOriginalsFeedHash();

  @override
  String toString() {
    return r'profileOriginalsFeedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProfileOriginalsFeed create() => ProfileOriginalsFeed();

  @override
  bool operator ==(Object other) {
    return other is ProfileOriginalsFeedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileOriginalsFeedHash() =>
    r'b4fbc85cda1621ee2198e0fb3a6e80119fdfdc67';

/// Feed provider for user's original videos (excluding reposts)
///
/// Provides VideoFeedState with loadMore() support for use in
/// FullscreenVideoFeedScreen with ProfileOriginalsFeedSource.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileOriginalsFeedProvider(userId));
/// await ref.read(profileOriginalsFeedProvider(userId).notifier).loadMore();
/// ```

final class ProfileOriginalsFeedFamily extends $Family
    with
        $ClassFamilyOverride<
          ProfileOriginalsFeed,
          AsyncValue<VideoFeedState>,
          VideoFeedState,
          FutureOr<VideoFeedState>,
          String
        > {
  const ProfileOriginalsFeedFamily._()
    : super(
        retry: null,
        name: r'profileOriginalsFeedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Feed provider for user's original videos (excluding reposts)
  ///
  /// Provides VideoFeedState with loadMore() support for use in
  /// FullscreenVideoFeedScreen with ProfileOriginalsFeedSource.
  ///
  /// Usage:
  /// ```dart
  /// final feed = ref.watch(profileOriginalsFeedProvider(userId));
  /// await ref.read(profileOriginalsFeedProvider(userId).notifier).loadMore();
  /// ```

  ProfileOriginalsFeedProvider call(String userId) =>
      ProfileOriginalsFeedProvider._(argument: userId, from: this);

  @override
  String toString() => r'profileOriginalsFeedProvider';
}

/// Feed provider for user's original videos (excluding reposts)
///
/// Provides VideoFeedState with loadMore() support for use in
/// FullscreenVideoFeedScreen with ProfileOriginalsFeedSource.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileOriginalsFeedProvider(userId));
/// await ref.read(profileOriginalsFeedProvider(userId).notifier).loadMore();
/// ```

abstract class _$ProfileOriginalsFeed extends $AsyncNotifier<VideoFeedState> {
  late final _$args = ref.$arg as String;
  String get userId => _$args;

  FutureOr<VideoFeedState> build(String userId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<VideoFeedState>, VideoFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VideoFeedState>, VideoFeedState>,
              AsyncValue<VideoFeedState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
