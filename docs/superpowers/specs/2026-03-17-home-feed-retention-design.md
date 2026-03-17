# Home Feed Retention Design

**Problem**

`VideoFeedBloc` currently clears visible videos on mode switches and several refresh paths. `HomeFeedCache` only helps once per bloc instance, and `VideoFeedPage` can recreate the bloc. The result is a cold-feeling UX even when the user has already loaded the same mode in the same session.

**Goals**

- Preserve already-loaded feed content across `home`, `latest`, and `popular` mode switches inside the Home screen.
- Preserve visible content during manual refresh, auto-refresh, and follow/list-triggered refreshes.
- Survive bloc recreation within the same app session.
- Keep the existing cold-start home cache for app relaunches.

**Non-Goals**

- Rebuild repository fetch policy for Explore providers.
- Add persistent disk caching for every mode beyond the existing home cold-start cache.
- Change feed ranking rules or pagination semantics.

**Current Code References**

- `mobile/lib/blocs/video_feed/video_feed_bloc.dart`
- `mobile/lib/blocs/video_feed/home_feed_cache.dart`
- `mobile/lib/screens/feed/video_feed_page.dart`
- `mobile/test/blocs/video_feed/video_feed_bloc_test.dart`
- `mobile/test/screens/feed/video_feed_page_test.dart`

**Proposed Design**

1. Add a session-scoped retained cache for `VideoFeedBloc`.
   - Store one snapshot per `FeedMode`.
   - Snapshot fields should include `videos`, `hasMore`, attribution metadata, and a refresh timestamp.
   - Keep this cache in memory, outside the bloc, so a recreated bloc can still reuse it.

2. Change destructive transitions to stale-while-revalidate.
   - `VideoFeedModeChanged` should immediately emit the retained snapshot for the target mode when one exists, then refresh in the background.
   - `VideoFeedRefreshRequested`, `VideoFeedAutoRefreshRequested`, `VideoFeedFollowingListChanged`, and `VideoFeedCuratedListsChanged` should preserve current visible content while reloading.
   - Cold loads with no retained snapshot should keep the current loading behavior.

3. Separate “no data yet” from “refreshing existing data”.
   - Extend `VideoFeedState` so refresh work does not require `status: loading` plus `videos: []`.
   - Keep pagination and attribution handling unchanged.

4. Keep the existing SharedPreferences-backed home cold-start cache.
   - That cache still serves relaunches.
   - The new retained cache only covers same-session mode switches and bloc recreation.

**File Boundaries**

- New cache model/service:
  - `mobile/lib/blocs/video_feed/video_feed_retained_cache.dart`
- Existing bloc wiring:
  - `mobile/lib/blocs/video_feed/video_feed_bloc.dart`
  - `mobile/lib/blocs/video_feed/video_feed_state.dart`
- Injection point:
  - `mobile/lib/providers/app_providers.dart`
  - `mobile/lib/screens/feed/video_feed_page.dart`

**Verification**

- Bloc tests for retained-mode snapshots, refresh-without-clear, and bloc recreation.
- Widget tests for mode switch UX and controller continuity.
- Smoke test:
  - `flutter test test/blocs/video_feed/video_feed_bloc_test.dart test/screens/feed/video_feed_page_test.dart`

**Risks**

- Showing stale videos for the wrong mode if the cache is keyed incorrectly.
- Regressing controller reset behavior if the UI cannot distinguish refresh from mode replacement.
- Double-accounting feed metrics if refresh emits are treated like first paints.
