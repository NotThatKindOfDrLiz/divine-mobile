// ABOUTME: Utility to determine if the current time is during quiet hours
// ABOUTME: Used by feed break nudges to show sleep-themed messaging

/// Returns true if the current time is during quiet hours (11 PM - 6 AM).
///
/// During quiet hours, the app shows sleep-themed copy in feed break nudges
/// to gently encourage users to take a break.
bool isQuietHours() {
  final hour = DateTime.now().hour;
  return hour >= 23 || hour < 6;
}
