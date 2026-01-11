// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_liked_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Feed provider for a user's liked videos
///
/// Provides VideoFeedState with sync and loadMore support for use in
/// FullscreenVideoFeedScreen with LikedVideosFeedSource.
///
/// This provider:
/// - For current user: Uses LikesRepository (has local cache)
/// - For other users: Queries relays directly for Kind 7 reactions
/// - Fetches video data from cache first, then relays
/// - Filters out unsupported video formats
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileLikedFeedProvider(userId));
/// await ref.read(profileLikedFeedProvider(userId).notifier).loadMore();
/// ```

@ProviderFor(ProfileLikedFeed)
const profileLikedFeedProvider = ProfileLikedFeedFamily._();

/// Feed provider for a user's liked videos
///
/// Provides VideoFeedState with sync and loadMore support for use in
/// FullscreenVideoFeedScreen with LikedVideosFeedSource.
///
/// This provider:
/// - For current user: Uses LikesRepository (has local cache)
/// - For other users: Queries relays directly for Kind 7 reactions
/// - Fetches video data from cache first, then relays
/// - Filters out unsupported video formats
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileLikedFeedProvider(userId));
/// await ref.read(profileLikedFeedProvider(userId).notifier).loadMore();
/// ```
final class ProfileLikedFeedProvider
    extends $AsyncNotifierProvider<ProfileLikedFeed, VideoFeedState> {
  /// Feed provider for a user's liked videos
  ///
  /// Provides VideoFeedState with sync and loadMore support for use in
  /// FullscreenVideoFeedScreen with LikedVideosFeedSource.
  ///
  /// This provider:
  /// - For current user: Uses LikesRepository (has local cache)
  /// - For other users: Queries relays directly for Kind 7 reactions
  /// - Fetches video data from cache first, then relays
  /// - Filters out unsupported video formats
  ///
  /// Usage:
  /// ```dart
  /// final feed = ref.watch(profileLikedFeedProvider(userId));
  /// await ref.read(profileLikedFeedProvider(userId).notifier).loadMore();
  /// ```
  const ProfileLikedFeedProvider._({
    required ProfileLikedFeedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileLikedFeedProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileLikedFeedHash();

  @override
  String toString() {
    return r'profileLikedFeedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProfileLikedFeed create() => ProfileLikedFeed();

  @override
  bool operator ==(Object other) {
    return other is ProfileLikedFeedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileLikedFeedHash() => r'b9726aa1b28f3d306010048bc0bc69f29500f2a0';

/// Feed provider for a user's liked videos
///
/// Provides VideoFeedState with sync and loadMore support for use in
/// FullscreenVideoFeedScreen with LikedVideosFeedSource.
///
/// This provider:
/// - For current user: Uses LikesRepository (has local cache)
/// - For other users: Queries relays directly for Kind 7 reactions
/// - Fetches video data from cache first, then relays
/// - Filters out unsupported video formats
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileLikedFeedProvider(userId));
/// await ref.read(profileLikedFeedProvider(userId).notifier).loadMore();
/// ```

final class ProfileLikedFeedFamily extends $Family
    with
        $ClassFamilyOverride<
          ProfileLikedFeed,
          AsyncValue<VideoFeedState>,
          VideoFeedState,
          FutureOr<VideoFeedState>,
          String
        > {
  const ProfileLikedFeedFamily._()
    : super(
        retry: null,
        name: r'profileLikedFeedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Feed provider for a user's liked videos
  ///
  /// Provides VideoFeedState with sync and loadMore support for use in
  /// FullscreenVideoFeedScreen with LikedVideosFeedSource.
  ///
  /// This provider:
  /// - For current user: Uses LikesRepository (has local cache)
  /// - For other users: Queries relays directly for Kind 7 reactions
  /// - Fetches video data from cache first, then relays
  /// - Filters out unsupported video formats
  ///
  /// Usage:
  /// ```dart
  /// final feed = ref.watch(profileLikedFeedProvider(userId));
  /// await ref.read(profileLikedFeedProvider(userId).notifier).loadMore();
  /// ```

  ProfileLikedFeedProvider call(String userId) =>
      ProfileLikedFeedProvider._(argument: userId, from: this);

  @override
  String toString() => r'profileLikedFeedProvider';
}

/// Feed provider for a user's liked videos
///
/// Provides VideoFeedState with sync and loadMore support for use in
/// FullscreenVideoFeedScreen with LikedVideosFeedSource.
///
/// This provider:
/// - For current user: Uses LikesRepository (has local cache)
/// - For other users: Queries relays directly for Kind 7 reactions
/// - Fetches video data from cache first, then relays
/// - Filters out unsupported video formats
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileLikedFeedProvider(userId));
/// await ref.read(profileLikedFeedProvider(userId).notifier).loadMore();
/// ```

abstract class _$ProfileLikedFeed extends $AsyncNotifier<VideoFeedState> {
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
