# Home Feed Retention Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve already-loaded Home feed content across mode switches, refreshes, and bloc recreation while still fetching fresh data in the background.

**Architecture:** Introduce a session-scoped retained snapshot cache keyed by `FeedMode`, inject it into `VideoFeedBloc`, and convert destructive transitions to stale-while-revalidate when a retained snapshot exists. Keep the existing SharedPreferences cold-start cache for app relaunches and only use the new cache for same-session reuse.

**Tech Stack:** Flutter, `flutter_bloc`, Riverpod dependency injection, SharedPreferences, widget tests, bloc tests

---

## Chunk 1: Retained Snapshot Model

### Task 1: Define the retained cache contract and codify expected behavior

**Files:**
- Create: `mobile/lib/blocs/video_feed/video_feed_retained_cache.dart`
- Modify: `mobile/test/blocs/video_feed/video_feed_bloc_test.dart`
- Modify: `mobile/test/screens/feed/video_feed_page_test.dart`

- [ ] **Step 1: Write the failing bloc tests**

```dart
blocTest<VideoFeedBloc, VideoFeedState>(
  'mode switch emits retained target-mode videos before refresh when cached',
  // seed cache with FeedMode.popular snapshot, switch from home to popular,
  // and expect no empty-videos loading state in between
);

blocTest<VideoFeedBloc, VideoFeedState>(
  'manual refresh preserves current videos while background refresh runs',
  // start from success state, add refresh event, and expect current videos
  // to remain visible until fresh results replace them
);
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `flutter test test/blocs/video_feed/video_feed_bloc_test.dart --plain-name "mode switch emits retained target-mode videos before refresh when cached"`

Expected: FAIL because `VideoFeedBloc` still emits `status: loading` with `videos: []`.

- [ ] **Step 3: Write the cache model and in-memory implementation**

```dart
class RetainedVideoFeedSnapshot {
  const RetainedVideoFeedSnapshot({
    required this.mode,
    required this.videos,
    required this.hasMore,
    required this.videoListSources,
    required this.listOnlyVideoIds,
    required this.refreshedAt,
  });
}

abstract class VideoFeedRetainedCache {
  RetainedVideoFeedSnapshot? read(FeedMode mode);
  void write(RetainedVideoFeedSnapshot snapshot);
  void clear(FeedMode mode);
}
```

- [ ] **Step 4: Inject the retained cache into `VideoFeedBloc`**

Run: `flutter test test/blocs/video_feed/video_feed_bloc_test.dart --plain-name "mode switch emits retained target-mode videos before refresh when cached"`

Expected: Still FAIL until transition logic changes, but compile should pass.

- [ ] **Step 5: Commit the contract layer**

```bash
git add mobile/lib/blocs/video_feed/video_feed_retained_cache.dart mobile/test/blocs/video_feed/video_feed_bloc_test.dart mobile/test/screens/feed/video_feed_page_test.dart
git commit -m "test(feed): codify retained home feed expectations"
```

## Chunk 2: Bloc Transition Changes

### Task 2: Convert destructive transitions to stale-while-revalidate

**Files:**
- Modify: `mobile/lib/blocs/video_feed/video_feed_bloc.dart`
- Modify: `mobile/lib/blocs/video_feed/video_feed_state.dart`
- Modify: `mobile/lib/screens/feed/video_feed_page.dart`
- Modify: `mobile/lib/providers/app_providers.dart`
- Test: `mobile/test/blocs/video_feed/video_feed_bloc_test.dart`
- Test: `mobile/test/screens/feed/video_feed_page_test.dart`

- [ ] **Step 1: Add state support for refresh-with-data**

```dart
const VideoFeedState(
  status: VideoFeedStatus.success,
  videos: [...],
  isRefreshing: true,
)
```

- [ ] **Step 2: Update bloc transitions**

```dart
final retained = _retainedCache.read(event.mode);
if (retained != null) {
  emit(state.copyWith(
    status: VideoFeedStatus.success,
    mode: event.mode,
    videos: retained.videos,
    hasMore: retained.hasMore,
    isRefreshing: true,
    videoListSources: retained.videoListSources,
    listOnlyVideoIds: retained.listOnlyVideoIds,
  ));
  await _loadVideos(event.mode, emit);
  return;
}
```

- [ ] **Step 3: Write snapshots on successful initial and paginated loads**

Run: `flutter test test/blocs/video_feed/video_feed_bloc_test.dart`

Expected: PASS with updated retained-cache coverage.

- [ ] **Step 4: Verify widget behavior**

Run: `flutter test test/screens/feed/video_feed_page_test.dart`

Expected: PASS with no regressions in controller/reset behavior.

- [ ] **Step 5: Run the focused suite**

Run: `flutter test test/blocs/video_feed/video_feed_bloc_test.dart test/screens/feed/video_feed_page_test.dart`

Expected: PASS

- [ ] **Step 6: Commit the implementation**

```bash
git add mobile/lib/blocs/video_feed/video_feed_bloc.dart mobile/lib/blocs/video_feed/video_feed_state.dart mobile/lib/providers/app_providers.dart mobile/lib/screens/feed/video_feed_page.dart mobile/test/blocs/video_feed/video_feed_bloc_test.dart mobile/test/screens/feed/video_feed_page_test.dart
git commit -m "feat(feed): retain mode snapshots during home refresh"
```
