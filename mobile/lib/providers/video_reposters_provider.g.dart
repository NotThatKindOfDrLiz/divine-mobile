// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_reposters_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches the pubkeys of users who reposted a video.
///
/// Queries the relay for Kind 16 (NIP-18 generic repost) events that reference
/// [videoId]. Uses the existing [VideoEventService.getRepostersForVideo] which
/// has a 5-second timeout.
///
/// Auto-disposes when the metadata sheet closes.

@ProviderFor(videoReposters)
const videoRepostersProvider = VideoRepostersFamily._();

/// Fetches the pubkeys of users who reposted a video.
///
/// Queries the relay for Kind 16 (NIP-18 generic repost) events that reference
/// [videoId]. Uses the existing [VideoEventService.getRepostersForVideo] which
/// has a 5-second timeout.
///
/// Auto-disposes when the metadata sheet closes.

final class VideoRepostersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Fetches the pubkeys of users who reposted a video.
  ///
  /// Queries the relay for Kind 16 (NIP-18 generic repost) events that reference
  /// [videoId]. Uses the existing [VideoEventService.getRepostersForVideo] which
  /// has a 5-second timeout.
  ///
  /// Auto-disposes when the metadata sheet closes.
  const VideoRepostersProvider._({
    required VideoRepostersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'videoRepostersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$videoRepostersHash();

  @override
  String toString() {
    return r'videoRepostersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    final argument = this.argument as String;
    return videoReposters(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VideoRepostersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$videoRepostersHash() => r'185ad463b5bc8b3fde20174f208c4b3aba9db188';

/// Fetches the pubkeys of users who reposted a video.
///
/// Queries the relay for Kind 16 (NIP-18 generic repost) events that reference
/// [videoId]. Uses the existing [VideoEventService.getRepostersForVideo] which
/// has a 5-second timeout.
///
/// Auto-disposes when the metadata sheet closes.

final class VideoRepostersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<String>>, String> {
  const VideoRepostersFamily._()
    : super(
        retry: null,
        name: r'videoRepostersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetches the pubkeys of users who reposted a video.
  ///
  /// Queries the relay for Kind 16 (NIP-18 generic repost) events that reference
  /// [videoId]. Uses the existing [VideoEventService.getRepostersForVideo] which
  /// has a 5-second timeout.
  ///
  /// Auto-disposes when the metadata sheet closes.

  VideoRepostersProvider call(String videoId) =>
      VideoRepostersProvider._(argument: videoId, from: this);

  @override
  String toString() => r'videoRepostersProvider';
}
