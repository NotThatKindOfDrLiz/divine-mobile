part of 'video_feed_bloc.dart';

/// Session-retained snapshot of a feed mode.
final class RetainedVideoFeedSnapshot extends Equatable {
  const RetainedVideoFeedSnapshot({
    required this.mode,
    required this.videos,
    required this.hasMore,
    required this.videoListSources,
    required this.listOnlyVideoIds,
    required this.creatorProfiles,
    required this.refreshedAt,
  });

  final FeedMode mode;
  final List<VideoEvent> videos;
  final bool hasMore;
  final Map<String, Set<String>> videoListSources;
  final Set<String> listOnlyVideoIds;
  final Map<String, UserProfile> creatorProfiles;
  final DateTime refreshedAt;

  @override
  List<Object?> get props => [
    mode,
    videos,
    hasMore,
    videoListSources,
    listOnlyVideoIds,
    creatorProfiles,
    refreshedAt,
  ];
}

abstract interface class VideoFeedRetainedCache {
  RetainedVideoFeedSnapshot? read(FeedMode mode);
  void write(RetainedVideoFeedSnapshot snapshot);
  void clear(FeedMode mode);
}

final class InMemoryVideoFeedRetainedCache implements VideoFeedRetainedCache {
  final Map<FeedMode, RetainedVideoFeedSnapshot> _snapshots = {};

  @override
  RetainedVideoFeedSnapshot? read(FeedMode mode) => _snapshots[mode];

  @override
  void write(RetainedVideoFeedSnapshot snapshot) {
    _snapshots[snapshot.mode] = snapshot;
  }

  @override
  void clear(FeedMode mode) {
    _snapshots.remove(mode);
  }
}
