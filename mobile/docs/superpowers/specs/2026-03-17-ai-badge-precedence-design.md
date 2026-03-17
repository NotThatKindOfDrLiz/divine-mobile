# AI Badge Precedence For Proof-Backed Videos

**Date:** 2026-03-17
**Branch:** feat-web-video-playback
**Status:** Approved

## Problem

The app can currently show `Human Made` for proof-backed videos even when AI detection reports a high likelihood of generated media. That creates contradictory trust language. In the current UI, proof data always wins the headline state, and the moderation score is treated as secondary context.

There is also a reliability concern around AI score surfacing. The badge row should consume moderation results for Divine-hosted proof-backed videos, not just proofless ones.

## Approved Behavior

For non-Vine videos:

- `aiScore > 0.8` overrides proof-backed trust copy and shows `Probably AI`
- `aiScore > 0.5 && aiScore <= 0.8` overrides proof-backed trust copy and shows `Likely AI`
- `aiScore <= 0.5` preserves the existing proof and human-made behavior
- missing AI score preserves the existing proof and human-made behavior

For Vine archives:

- `Original Vine` remains the top-priority badge and explanation state

## UI Rules

### Badge Row

- A proof-backed video with `aiScore > 0.5` must not render `Human Made`
- A proof-backed video with `aiScore > 0.8` renders `Probably AI`
- A proof-backed video with `aiScore > 0.5 && <= 0.8` renders `Likely AI`
- Proofless videos continue using the existing human-made promotion for low AI scores
- Divine-hosted videos without proof or AI result continue showing the pending AI state

### Verification Modal

- The intro copy must match the AI verdict when `aiScore > 0.5`
- Proof checklist items and proof details remain visible, but they are supporting evidence, not the headline verdict
- Existing low-score human-made copy stays unchanged for `aiScore <= 0.5`

## Data Resolution

- Keep the current lookup order: moderation label service first, moderation status service fallback second
- Ensure the badge row test coverage proves a Divine-hosted proof-backed video can consume moderation status fallback data

## Files In Scope

- `mobile/lib/widgets/proofmode_badge_row.dart`
- `mobile/lib/widgets/proofmode_badge.dart`
- `mobile/lib/widgets/badge_explanation_modal.dart`
- `mobile/test/widgets/proofmode_badge_row_test.dart`
- `mobile/test/widgets/badge_explanation_modal_test.dart`

## Testing

- Add failing widget tests for proof-backed Divine-hosted videos with moderation-service AI scores above `0.5`
- Verify both score bands:
  - `0.51` to `0.80` => `Likely AI`
  - `> 0.80` => `Probably AI`
- Verify the modal intro no longer claims Proofmode verification as the top-level verdict in those cases
