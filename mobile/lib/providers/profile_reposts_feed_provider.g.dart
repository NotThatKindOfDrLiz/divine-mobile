// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_reposts_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Feed provider for user's reposted videos
///
/// Provides VideoFeedState with loadMore() support for use in
/// FullscreenVideoFeedScreen with ProfileRepostsFeedSource.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileRepostsFeedProvider(userId));
/// await ref.read(profileRepostsFeedProvider(userId).notifier).loadMore();
/// ```

@ProviderFor(ProfileRepostsFeed)
const profileRepostsFeedProvider = ProfileRepostsFeedFamily._();

/// Feed provider for user's reposted videos
///
/// Provides VideoFeedState with loadMore() support for use in
/// FullscreenVideoFeedScreen with ProfileRepostsFeedSource.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileRepostsFeedProvider(userId));
/// await ref.read(profileRepostsFeedProvider(userId).notifier).loadMore();
/// ```
final class ProfileRepostsFeedProvider
    extends $AsyncNotifierProvider<ProfileRepostsFeed, VideoFeedState> {
  /// Feed provider for user's reposted videos
  ///
  /// Provides VideoFeedState with loadMore() support for use in
  /// FullscreenVideoFeedScreen with ProfileRepostsFeedSource.
  ///
  /// Usage:
  /// ```dart
  /// final feed = ref.watch(profileRepostsFeedProvider(userId));
  /// await ref.read(profileRepostsFeedProvider(userId).notifier).loadMore();
  /// ```
  const ProfileRepostsFeedProvider._({
    required ProfileRepostsFeedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileRepostsFeedProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileRepostsFeedHash();

  @override
  String toString() {
    return r'profileRepostsFeedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProfileRepostsFeed create() => ProfileRepostsFeed();

  @override
  bool operator ==(Object other) {
    return other is ProfileRepostsFeedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileRepostsFeedHash() =>
    r'db281aebb8ce8b3a870f11b7660b5411bb9580cc';

/// Feed provider for user's reposted videos
///
/// Provides VideoFeedState with loadMore() support for use in
/// FullscreenVideoFeedScreen with ProfileRepostsFeedSource.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileRepostsFeedProvider(userId));
/// await ref.read(profileRepostsFeedProvider(userId).notifier).loadMore();
/// ```

final class ProfileRepostsFeedFamily extends $Family
    with
        $ClassFamilyOverride<
          ProfileRepostsFeed,
          AsyncValue<VideoFeedState>,
          VideoFeedState,
          FutureOr<VideoFeedState>,
          String
        > {
  const ProfileRepostsFeedFamily._()
    : super(
        retry: null,
        name: r'profileRepostsFeedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Feed provider for user's reposted videos
  ///
  /// Provides VideoFeedState with loadMore() support for use in
  /// FullscreenVideoFeedScreen with ProfileRepostsFeedSource.
  ///
  /// Usage:
  /// ```dart
  /// final feed = ref.watch(profileRepostsFeedProvider(userId));
  /// await ref.read(profileRepostsFeedProvider(userId).notifier).loadMore();
  /// ```

  ProfileRepostsFeedProvider call(String userId) =>
      ProfileRepostsFeedProvider._(argument: userId, from: this);

  @override
  String toString() => r'profileRepostsFeedProvider';
}

/// Feed provider for user's reposted videos
///
/// Provides VideoFeedState with loadMore() support for use in
/// FullscreenVideoFeedScreen with ProfileRepostsFeedSource.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileRepostsFeedProvider(userId));
/// await ref.read(profileRepostsFeedProvider(userId).notifier).loadMore();
/// ```

abstract class _$ProfileRepostsFeed extends $AsyncNotifier<VideoFeedState> {
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
