# Divine Login Banner Dismissal TTL Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the profile session-expired banner snooze for 30 days instead of forever, and clear the snooze when Divine OAuth recovery succeeds.

**Architecture:** Add a tiny shared helper for the dismissal key and TTL logic, then reuse it from the profile header and auth service. Cover the behavior with one widget regression slice and one auth regression slice before implementation.

**Tech Stack:** Flutter, Riverpod, SharedPreferences, Flutter widget tests, auth service unit tests

---

## Chunk 1: TTL Read/Write Behavior

### Task 1: Add the failing widget regressions

**Files:**
- Modify: `mobile/test/widgets/profile/profile_header_widget_test.dart`

- [ ] **Step 1: Write the failing tests**

Add tests for:
- a recent dismissal timestamp hides the expired-session banner
- a dismissal older than 30 days shows the banner again

- [ ] **Step 2: Run the widget test file to verify the new case fails**

Run: `cd mobile && flutter test test/widgets/profile/profile_header_widget_test.dart`
Expected: the new TTL expectation fails because the current code treats dismissal as permanent.

### Task 2: Implement the TTL helper and widget update

**Files:**
- Create: `mobile/lib/utils/divine_login_banner_dismissal.dart`
- Modify: `mobile/lib/widgets/profile/profile_header_widget.dart`

- [ ] **Step 3: Add the minimal helper**

Add:
- per-pubkey preference key builder
- 30-day TTL constant
- `isDismissed(...)`
- `dismiss(...)`
- `clear(...)`

- [ ] **Step 4: Update the profile header to use the helper**

Read the active dismissal via the helper and write a timestamp on dismiss instead of a boolean.

- [ ] **Step 5: Re-run the widget test file**

Run: `cd mobile && flutter test test/widgets/profile/profile_header_widget_test.dart`
Expected: the TTL tests pass.

## Chunk 2: Shared Helper Coverage And Auth Reset

### Task 3: Add the failing helper regression

**Files:**
- Create: `mobile/test/utils/divine_login_banner_dismissal_test.dart`

- [ ] **Step 6: Write the failing helper test**

Cover:
- dismissal remains active within 30 days
- dismissal expires after 30 days
- clear removes the stored dismissal

- [ ] **Step 7: Run the helper test file to verify it fails**

Run: `cd mobile && flutter test test/utils/divine_login_banner_dismissal_test.dart`
Expected: compilation or test failure because the helper does not exist yet.

### Task 4: Clear dismissal on auth recovery

**Files:**
- Modify: `mobile/lib/services/auth_service.dart`
- Reuse: `mobile/lib/utils/divine_login_banner_dismissal.dart`

- [ ] **Step 8: Add the minimal auth-side reset**

Clear the stored dismissal when:
- a silent refresh succeeds
- Divine OAuth sign-in establishes the session for a pubkey

- [ ] **Step 9: Re-run the helper test file**

Run: `cd mobile && flutter test test/utils/divine_login_banner_dismissal_test.dart`
Expected: the helper regression passes, and the auth service compiles cleanly against it.

## Chunk 3: Focused Verification

### Task 5: Verify the final touched set

**Files:**
- Verify: `mobile/lib/widgets/profile/profile_header_widget.dart`
- Verify: `mobile/lib/services/auth_service.dart`
- Verify: `mobile/lib/utils/divine_login_banner_dismissal.dart`
- Verify: `mobile/test/widgets/profile/profile_header_widget_test.dart`
- Verify: `mobile/test/utils/divine_login_banner_dismissal_test.dart`

- [ ] **Step 10: Run focused analyzer**

Run: `cd mobile && flutter analyze --no-pub lib/widgets/profile/profile_header_widget.dart lib/services/auth_service.dart lib/utils/divine_login_banner_dismissal.dart test/widgets/profile/profile_header_widget_test.dart test/utils/divine_login_banner_dismissal_test.dart`
Expected: no issues found.

- [ ] **Step 11: Run focused tests together**

Run: `cd mobile && flutter test test/utils/divine_login_banner_dismissal_test.dart test/widgets/profile/profile_header_widget_test.dart`
Expected: all tests pass.

- [ ] **Step 12: Commit**

```bash
git add docs/superpowers/specs/2026-03-22-divine-login-banner-dismissal-ttl-design.md \
  docs/superpowers/plans/2026-03-22-divine-login-banner-dismissal-ttl.md \
  mobile/lib/utils/divine_login_banner_dismissal.dart \
  mobile/lib/widgets/profile/profile_header_widget.dart \
  mobile/lib/services/auth_service.dart \
  mobile/test/widgets/profile/profile_header_widget_test.dart \
  mobile/test/utils/divine_login_banner_dismissal_test.dart
git commit -m "fix(profile): expire dismissed session banner"
```
