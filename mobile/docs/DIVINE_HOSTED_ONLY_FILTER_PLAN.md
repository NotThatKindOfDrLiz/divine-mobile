# Divine-Hosted-Only Filter Plan

## Goal

Add a user setting that hides videos whose media is not hosted on Divine-owned
domains.

Default behavior should stay unchanged. The setting should be opt-in.

## Current Findings

### Existing Divine-hosted detection

- `mobile/lib/extensions/video_event_extensions.dart`
  already exposes `VideoEvent.isFromDivineServer`.
- The current implementation is:
  `video.videoUrl?.toLowerCase().contains('divine.video') == true`.
- That is good enough for badge copy, but it is too loose for a hard filter.
  It would treat hosts like `notdivine.video.example.com` as Divine-hosted.

### Existing user-facing concept

- The app already surfaces "Not Divine Hosted" state in:
  `mobile/lib/widgets/proofmode_badge_row.dart`
- That means the product language already exists and users can understand what
  the filter means.

### Existing settings home

- `mobile/lib/screens/settings_screen.dart` routes users into
  `mobile/lib/screens/safety_settings_screen.dart`.
- `SafetySettingsScreen` already owns feed-safety controls:
  age verification, content filters, moderation labelers, and blocked users.
- This setting belongs there, not in relay or media server settings.

### Existing filtering split

Video filtering is currently split across two main pipelines:

1. Repository-backed loading
   - `mobile/lib/providers/app_providers.dart`
   - `mobile/packages/videos_repository/lib/src/videos_repository.dart`
   - Used by `VideoFeedBloc` and several repository-backed screens/BLoCs.

2. Subscription/live-feed loading
   - `mobile/lib/services/video_event_service.dart`
   - `mobile/lib/providers/for_you_provider.dart`
   - `mobile/lib/providers/popular_now_feed_provider.dart`
   - `mobile/lib/providers/profile_feed_provider.dart`
   - `mobile/lib/providers/classic_vines_provider.dart`

The feature needs to cover both pipelines or it will behave inconsistently by
tab.

### Important edge cases

- `mobile/lib/screens/video_detail_screen.dart` fetches a video by ID and does
  not currently run it through content filtering before display.
- `ClassicVinesFeed` will likely become mostly or entirely empty when this
  setting is enabled because classic Vine archive videos are not Divine-hosted.
- `VideoEvent.shouldShowNotDivineBadge` exempts original Vine videos from the
  badge, but that is only badge logic. It is not a hosting exception.

## Proposed UX

Add a switch to `SafetySettingsScreen` under the existing `SETTINGS` section.

- Title: `Only show videos hosted by Divine`
- Subtitle: `Hide videos served from other Nostr media hosts`
- Default: `false`

Why this location:

- It matches the current moderation/safety mental model.
- It is a personal feed-filtering preference, not a publishing setting.

## Proposed Technical Design

### 1. Harden Divine host detection first

Update `VideoEvent.isFromDivineServer` to parse the URL host and match:

- `divine.video`
- any subdomain ending in `.divine.video`

Do not rely on `String.contains`.

Add tests for:

- `media.divine.video`
- `cdn.divine.video`
- `divine.video`
- a false positive like `https://notdivine.video.evil.com/foo.mp4`

### 2. Add a dedicated preference service

Create a small service, for example:

- `mobile/lib/services/divine_host_filter_service.dart`

Suggested shape:

- `bool get showDivineHostedOnly`
- `Future<void> initialize()`
- `Future<void> setShowDivineHostedOnly(bool value)`

Implementation notes:

- Persist with `SharedPreferences`
- Make it `ChangeNotifier` so feeds can rebuild immediately
- Add Riverpod providers in `mobile/lib/providers/app_providers.dart`
  similar to `contentFilterServiceProvider` and `contentFilterVersionProvider`

### 3. Add one shared host filter helper

Create a small app-layer helper that answers:

- should this `VideoEvent` be filtered out because it is not Divine-hosted?

Example file:

- `mobile/lib/services/divine_host_content_filter.dart`

That keeps repository code decoupled from app services, matching the existing
`createNsfwFilter` and `createBlocklistFilter` pattern.

### 4. Wire repository-backed filtering

`VideosRepository` only accepts one `contentFilter` callback today, so the new
host filter should be composed with the existing NSFW filter in
`videosRepositoryProvider`.

Expected behavior:

- filter out when `nsfwFilter(video)` is true
- filter out when `divineHostOnlyFilter(video)` is true
- keep warning-label resolution unchanged

This covers:

- `VideoFeedBloc` home/latest/popular flows
- repository-backed fetches such as liked/reposted/profile helpers that already
  depend on `VideosRepository`

### 5. Wire subscription/live-feed filtering

Extend `VideoEventService` so the setting applies to:

- incoming real-time events
- historical backfill events
- `filterVideoList(...)`

Suggested additions:

- inject `DivineHostFilterService` via `setDivineHostFilterService(...)`
- add a helper like `shouldFilterNonDivineVideo(VideoEvent video)`
- add a purge method like `filterNonDivineFromExistingVideos()`

The service should early-return on non-Divine videos when the setting is on,
similar to current blocklist/content-hide handling.

### 6. Make feed state update immediately

This part matters. Some feeds already rebuild on content-filter changes, but
`VideoFeedBloc` does not automatically refresh when a preference changes.

Implementation should explicitly refresh or recreate affected state when the
toggle changes:

- Riverpod feed providers should watch a new
  `divineHostFilterVersionProvider`
- `VideoFeedBloc` home page should get an explicit refresh path
  instead of assuming provider rebuilds will recreate the bloc
- `SafetySettingsScreen` should call the relevant refresh/purge logic after the
  toggle changes so users do not need to manually restart the app

### 7. Decide deep-link behavior

Open product question:

- Should `VideoDetailScreen` still open an external video when reached by a
  direct link or notification while the filter is enabled?

Recommended default:

- filter direct loads too, and show a clear empty/error state such as
  `This video is not hosted by Divine and is hidden by your safety settings.`

That matches the setting label most literally.

## Recommended Scope

### Phase 1

- Add the setting
- Apply it to all main browsing feeds
- Refresh/purge visible feed state immediately
- Keep behavior consistent across repository and `VideoEventService` paths

### Phase 2

- Apply the setting to direct video loads and any remaining one-off fetch paths
- Add polish copy for empty states when an entire surface becomes empty
  because everything there is external

## Test Plan

### Unit tests

- `mobile/test/extensions/video_event_divine_server_test.dart`
  - strict host matching
  - false-positive rejection
- `mobile/test/services/divine_host_filter_service_test.dart`
  - default value
  - persistence
  - listener notification
- `mobile/test/services/divine_host_content_filter_test.dart`
  - returns `true` only when setting is enabled and host is external

### Repository tests

- `mobile/packages/videos_repository/test/src/videos_repository_test.dart`
  - Nostr event path filters external-host videos
  - Funnelcake API path filters external-host videos
  - composed NSFW + host filter keeps existing NSFW behavior intact

### Widget/provider tests

- `mobile/test/screens/safety_settings_screen_test.dart`
  - switch is visible
  - toggle persists the setting
- update one representative feed test to prove the filter removes external
  videos after preference change

### Verification during implementation

Run from `mobile/`:

- `flutter test test/extensions/video_event_divine_server_test.dart`
- `flutter test test/screens/safety_settings_screen_test.dart`
- `flutter test test/services/divine_host_filter_service_test.dart`
- `flutter test --coverage` from `mobile/packages/videos_repository`

If the final UI changes materially, also run:

- `mobile/scripts/golden.sh verify`

## Recommendation

Implement this as a safety preference in `SafetySettingsScreen`, backed by a
dedicated `ChangeNotifier` service, and enforce it in both
`VideosRepository` and `VideoEventService`.

Do not build the feature on top of the current `contains('divine.video')`
check. Tightening host detection is the first required step.
