// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_originals_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that returns only the user's original videos (excluding reposts)
///
/// Watches the profile feed provider and filters for videos where:
/// - isRepost == false
/// - pubkey == userIdHex (original author)

@ProviderFor(profileOriginals)
const profileOriginalsProvider = ProfileOriginalsFamily._();

/// Provider that returns only the user's original videos (excluding reposts)
///
/// Watches the profile feed provider and filters for videos where:
/// - isRepost == false
/// - pubkey == userIdHex (original author)

final class ProfileOriginalsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VideoEvent>>,
          List<VideoEvent>,
          FutureOr<List<VideoEvent>>
        >
    with $FutureModifier<List<VideoEvent>>, $FutureProvider<List<VideoEvent>> {
  /// Provider that returns only the user's original videos (excluding reposts)
  ///
  /// Watches the profile feed provider and filters for videos where:
  /// - isRepost == false
  /// - pubkey == userIdHex (original author)
  const ProfileOriginalsProvider._({
    required ProfileOriginalsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileOriginalsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileOriginalsHash();

  @override
  String toString() {
    return r'profileOriginalsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<VideoEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VideoEvent>> create(Ref ref) {
    final argument = this.argument as String;
    return profileOriginals(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileOriginalsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileOriginalsHash() => r'23bf9eaab5d216d9eef625d2f902cdb574dfbd7e';

/// Provider that returns only the user's original videos (excluding reposts)
///
/// Watches the profile feed provider and filters for videos where:
/// - isRepost == false
/// - pubkey == userIdHex (original author)

final class ProfileOriginalsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<VideoEvent>>, String> {
  const ProfileOriginalsFamily._()
    : super(
        retry: null,
        name: r'profileOriginalsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that returns only the user's original videos (excluding reposts)
  ///
  /// Watches the profile feed provider and filters for videos where:
  /// - isRepost == false
  /// - pubkey == userIdHex (original author)

  ProfileOriginalsProvider call(String userIdHex) =>
      ProfileOriginalsProvider._(argument: userIdHex, from: this);

  @override
  String toString() => r'profileOriginalsProvider';
}
