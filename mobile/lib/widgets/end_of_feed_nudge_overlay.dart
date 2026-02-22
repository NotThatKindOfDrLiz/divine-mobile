// ABOUTME: Shared overlay widget shown at end of loaded feed content
// ABOUTME: Prompts users to continue or take a break, with quiet hours support

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/utils/quiet_hours.dart';

/// Overlay displayed when a user reaches the end of loaded content in any feed.
///
/// Shows a "You're all caught up!" message with options to load more or dismiss.
/// During quiet hours (11 PM - 6 AM), uses sleep-themed copy to gently
/// encourage a break.
///
/// This widget is designed to be placed in a [Stack] on top of the feed content.
class EndOfFeedNudgeOverlay extends StatelessWidget {
  const EndOfFeedNudgeOverlay({
    required this.onShowMore,
    required this.onDismiss,
    super.key,
  });

  /// Called when the user taps "Show More" to load additional content.
  final VoidCallback onShowMore;

  /// Called when the user dismisses the nudge to stay at their current position.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final quiet = isQuietHours();
    final subtitle = quiet
        ? "It's getting late \u2014 maybe time for a break?"
        : 'Take a moment or keep scrolling';

    return ColoredBox(
      color: VineTheme.backgroundColor.withValues(alpha: 0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: _NudgeCard(
            subtitle: subtitle,
            isQuietHours: quiet,
            onShowMore: onShowMore,
            onDismiss: onDismiss,
          ),
        ),
      ),
    );
  }
}

class _NudgeCard extends StatelessWidget {
  const _NudgeCard({
    required this.subtitle,
    required this.isQuietHours,
    required this.onShowMore,
    required this.onDismiss,
  });

  final String subtitle;
  final bool isQuietHours;
  final VoidCallback onShowMore;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VineTheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isQuietHours ? Icons.bedtime_outlined : Icons.check_circle_outline,
            size: 48,
            color: VineTheme.vineGreen,
          ),
          const SizedBox(height: 16),
          Text(
            "You're all caught up!",
            style: VineTheme.titleMediumFont(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onShowMore,
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Show More',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                foregroundColor: VineTheme.secondaryText,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isQuietHours ? 'Take a Break' : 'Dismiss',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact version of the end-of-feed nudge for use in grid views.
///
/// Unlike the fullscreen overlay, this renders as an inline card widget
/// suitable for placement at the bottom of a scrollable grid.
class EndOfFeedNudgeCard extends StatelessWidget {
  const EndOfFeedNudgeCard({
    required this.onShowMore,
    required this.onDismiss,
    super.key,
  });

  /// Called when the user taps "Show More" to load additional content.
  final VoidCallback onShowMore;

  /// Called when the user dismisses the nudge.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final quiet = isQuietHours();
    final subtitle = quiet
        ? "It's getting late \u2014 maybe time for a break?"
        : 'Take a moment or keep scrolling';

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              quiet ? Icons.bedtime_outlined : Icons.check_circle_outline,
              size: 32,
              color: VineTheme.vineGreen,
            ),
            const SizedBox(height: 8),
            Text(
              "You're all caught up!",
              style: VineTheme.titleSmallFont(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: VineTheme.secondaryText,
                  ),
                  child: Text(quiet ? 'Take a Break' : 'Dismiss'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: onShowMore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: VineTheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Show More'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
