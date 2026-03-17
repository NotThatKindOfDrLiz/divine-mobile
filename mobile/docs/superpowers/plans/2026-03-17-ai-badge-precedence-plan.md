# AI Badge Precedence Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make AI verdicts override `Human Made` trust language for scores above `0.5`, while preserving existing low-score proof behavior and Vine precedence.

**Architecture:** Keep the current badge row and verification modal flow, but centralize the AI score band decision so both surfaces use the same verdict thresholds. Preserve proof details as supporting metadata while the AI verdict controls the top-level messaging for high scores.

**Tech Stack:** Flutter, Riverpod, widget tests, mocktail

---

## Chunk 1: Lock The Behavior With Tests

### Task 1: Badge Row Regression Tests

**Files:**
- Modify: `mobile/test/widgets/proofmode_badge_row_test.dart`
- Verify against: `mobile/lib/widgets/proofmode_badge_row.dart`

- [ ] **Step 1: Write the failing test**

Add widget coverage for a Divine-hosted proof-backed video where `VideoModerationStatusService.fetchStatus()` returns:
- `aiScore: 0.65` and expect `Likely AI`
- `aiScore: 0.99` and expect `Probably AI`

Also assert `Human Made` is absent so the regression is explicit.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/proofmode_badge_row_test.dart`
Expected: FAIL because the current badge row still renders `Human Made` for proof-backed videos with high AI scores.

### Task 2: Modal Regression Tests

**Files:**
- Modify: `mobile/test/widgets/badge_explanation_modal_test.dart`
- Verify against: `mobile/lib/widgets/badge_explanation_modal.dart`

- [ ] **Step 1: Write the failing test**

Add modal coverage for proof-backed videos with:
- `aiScore: 0.65` and expect `likely AI-generated` headline copy
- `aiScore: 0.99` and expect `probably AI-generated` headline copy

Assert the modal no longer leads with the Proofmode-verified intro in those cases.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/badge_explanation_modal_test.dart`
Expected: FAIL because the current modal intro always prefers Proofmode verification copy when proof tags exist.

## Chunk 2: Minimal Production Changes

### Task 3: Implement Shared AI Verdict Logic

**Files:**
- Modify: `mobile/lib/widgets/proofmode_badge.dart`
- Modify: `mobile/lib/widgets/proofmode_badge_row.dart`
- Modify: `mobile/lib/widgets/badge_explanation_modal.dart`

- [ ] **Step 1: Add the minimal implementation**

Implement a shared score-band decision:
- `> 0.8` => `Probably AI`
- `> 0.5 && <= 0.8` => `Likely AI`
- otherwise no AI-warning override

Use it to:
- replace proof-backed `Human Made` badges in the badge row
- update modal intro copy for the same score bands
- preserve proof details and existing low-score behavior

- [ ] **Step 2: Run targeted tests**

Run:
- `flutter test test/widgets/proofmode_badge_row_test.dart`
- `flutter test test/widgets/badge_explanation_modal_test.dart`

Expected: PASS

## Chunk 3: Verification

### Task 4: Run Focused Verification

**Files:**
- No additional file edits

- [ ] **Step 1: Run final focused verification**

Run:
- `flutter test test/widgets/proofmode_badge_row_test.dart`
- `flutter test test/widgets/badge_explanation_modal_test.dart`
- `flutter test test/widgets/proofmode_badge_test.dart`

Expected: PASS

- [ ] **Step 2: Review diff and commit**

Run:
- `git status --short`
- `git diff -- mobile/lib/widgets/proofmode_badge.dart mobile/lib/widgets/proofmode_badge_row.dart mobile/lib/widgets/badge_explanation_modal.dart mobile/test/widgets/proofmode_badge_row_test.dart mobile/test/widgets/badge_explanation_modal_test.dart mobile/docs/superpowers/specs/2026-03-17-ai-badge-precedence-design.md mobile/docs/superpowers/plans/2026-03-17-ai-badge-precedence-plan.md`

Commit with a conventional message after verification passes.
