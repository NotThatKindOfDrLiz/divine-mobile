// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'individual_video_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for individual video controllers with autoDispose.
///
/// This is a thin wrapper around VideoControllerPool. The pool handles:
/// - Controller creation (platform-specific, cache-aware)
/// - Initialization with retry logic (in background)
/// - Loop enforcement for long videos
/// - State change tracking
/// - LRU eviction when at capacity
///
/// This provider only handles:
/// - Ref-specific error reactions (cache corruption retry, broken video tracking)
/// - Lifecycle management (checkin on dispose)
///
/// **Important:** The controller is returned immediately but may not be
/// initialized yet. Callers should check `controller.value.isInitialized`.

@ProviderFor(individualVideoController)
const individualVideoControllerProvider = IndividualVideoControllerFamily._();

/// Provider for individual video controllers with autoDispose.
///
/// This is a thin wrapper around VideoControllerPool. The pool handles:
/// - Controller creation (platform-specific, cache-aware)
/// - Initialization with retry logic (in background)
/// - Loop enforcement for long videos
/// - State change tracking
/// - LRU eviction when at capacity
///
/// This provider only handles:
/// - Ref-specific error reactions (cache corruption retry, broken video tracking)
/// - Lifecycle management (checkin on dispose)
///
/// **Important:** The controller is returned immediately but may not be
/// initialized yet. Callers should check `controller.value.isInitialized`.

final class IndividualVideoControllerProvider
    extends
        $FunctionalProvider<
          VideoPlayerController,
          VideoPlayerController,
          VideoPlayerController
        >
    with $Provider<VideoPlayerController> {
  /// Provider for individual video controllers with autoDispose.
  ///
  /// This is a thin wrapper around VideoControllerPool. The pool handles:
  /// - Controller creation (platform-specific, cache-aware)
  /// - Initialization with retry logic (in background)
  /// - Loop enforcement for long videos
  /// - State change tracking
  /// - LRU eviction when at capacity
  ///
  /// This provider only handles:
  /// - Ref-specific error reactions (cache corruption retry, broken video tracking)
  /// - Lifecycle management (checkin on dispose)
  ///
  /// **Important:** The controller is returned immediately but may not be
  /// initialized yet. Callers should check `controller.value.isInitialized`.
  const IndividualVideoControllerProvider._({
    required IndividualVideoControllerFamily super.from,
    required VideoControllerParams super.argument,
  }) : super(
         retry: null,
         name: r'individualVideoControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$individualVideoControllerHash();

  @override
  String toString() {
    return r'individualVideoControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<VideoPlayerController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoPlayerController create(Ref ref) {
    final argument = this.argument as VideoControllerParams;
    return individualVideoController(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoPlayerController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoPlayerController>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IndividualVideoControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$individualVideoControllerHash() =>
    r'a03936f5533ddbf9d06184427db581ac2039b1e1';

/// Provider for individual video controllers with autoDispose.
///
/// This is a thin wrapper around VideoControllerPool. The pool handles:
/// - Controller creation (platform-specific, cache-aware)
/// - Initialization with retry logic (in background)
/// - Loop enforcement for long videos
/// - State change tracking
/// - LRU eviction when at capacity
///
/// This provider only handles:
/// - Ref-specific error reactions (cache corruption retry, broken video tracking)
/// - Lifecycle management (checkin on dispose)
///
/// **Important:** The controller is returned immediately but may not be
/// initialized yet. Callers should check `controller.value.isInitialized`.

final class IndividualVideoControllerFamily extends $Family
    with
        $FunctionalFamilyOverride<
          VideoPlayerController,
          VideoControllerParams
        > {
  const IndividualVideoControllerFamily._()
    : super(
        retry: null,
        name: r'individualVideoControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for individual video controllers with autoDispose.
  ///
  /// This is a thin wrapper around VideoControllerPool. The pool handles:
  /// - Controller creation (platform-specific, cache-aware)
  /// - Initialization with retry logic (in background)
  /// - Loop enforcement for long videos
  /// - State change tracking
  /// - LRU eviction when at capacity
  ///
  /// This provider only handles:
  /// - Ref-specific error reactions (cache corruption retry, broken video tracking)
  /// - Lifecycle management (checkin on dispose)
  ///
  /// **Important:** The controller is returned immediately but may not be
  /// initialized yet. Callers should check `controller.value.isInitialized`.

  IndividualVideoControllerProvider call(VideoControllerParams params) =>
      IndividualVideoControllerProvider._(argument: params, from: this);

  @override
  String toString() => r'individualVideoControllerProvider';
}

/// Provider for video loading state

@ProviderFor(videoLoadingState)
const videoLoadingStateProvider = VideoLoadingStateFamily._();

/// Provider for video loading state

final class VideoLoadingStateProvider
    extends
        $FunctionalProvider<
          VideoLoadingState,
          VideoLoadingState,
          VideoLoadingState
        >
    with $Provider<VideoLoadingState> {
  /// Provider for video loading state
  const VideoLoadingStateProvider._({
    required VideoLoadingStateFamily super.from,
    required VideoControllerParams super.argument,
  }) : super(
         retry: null,
         name: r'videoLoadingStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$videoLoadingStateHash();

  @override
  String toString() {
    return r'videoLoadingStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<VideoLoadingState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoLoadingState create(Ref ref) {
    final argument = this.argument as VideoControllerParams;
    return videoLoadingState(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoLoadingState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoLoadingState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VideoLoadingStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$videoLoadingStateHash() => r'22f741beecbea8885fcd115ef3047a2fa2eb5e0d';

/// Provider for video loading state

final class VideoLoadingStateFamily extends $Family
    with $FunctionalFamilyOverride<VideoLoadingState, VideoControllerParams> {
  const VideoLoadingStateFamily._()
    : super(
        retry: null,
        name: r'videoLoadingStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for video loading state

  VideoLoadingStateProvider call(VideoControllerParams params) =>
      VideoLoadingStateProvider._(argument: params, from: this);

  @override
  String toString() => r'videoLoadingStateProvider';
}
