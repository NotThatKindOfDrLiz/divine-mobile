# Divine Login Banner Dismissal TTL Design

## Goal

Make the dismissible "Session Expired" banner on the profile page come back after 30 days if the account is still expired, and clear the dismissal as soon as the user successfully restores their Divine OAuth session.

## Current Problem

PR `#2214` stores a permanent boolean dismissal keyed by pubkey. Once dismissed, the banner never appears again for that account because nothing resets the preference when auth recovers or when enough time passes.

## Design

Store dismissal as a timestamp instead of a boolean. The profile banner should be hidden only when:

- the current account has an expired OAuth session, and
- a stored dismissal timestamp exists for that account, and
- that dismissal is less than 30 days old.

If the dismissal is missing or older than 30 days, the banner should render again.

Use one shared helper for:

- generating the per-pubkey preference key
- reading whether the dismissal is still active
- writing the current dismissal timestamp
- clearing the dismissal after auth recovery

## Reset Behavior

Clear the dismissal when the app successfully restores a valid Divine OAuth session:

- after a successful silent refresh path
- after a successful Divine OAuth sign-in path

This keeps dismissal scoped to the current expired-session incident rather than muting future incidents forever.

## Tests

Add regression coverage for:

- dismissal hides the banner within 30 days
- dismissal older than 30 days allows the banner to show again
- successful expired-session refresh clears the stored dismissal key
