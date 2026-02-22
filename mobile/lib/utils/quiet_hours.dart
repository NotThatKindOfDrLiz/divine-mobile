// ABOUTME: Utility for determining quiet hours based on local device time.

/// Returns true when the current local time falls within quiet hours.
///
/// Defaults to 11:00 PM -> 6:00 AM.
bool isQuietHoursNow({DateTime? now, int startHour = 23, int endHour = 6}) {
  final localNow = now ?? DateTime.now();
  final hour = localNow.hour;

  // Window crosses midnight (e.g., 23 -> 6).
  if (startHour > endHour) {
    return hour >= startHour || hour < endHour;
  }

  // Same-day window (e.g., 9 -> 17).
  return hour >= startHour && hour < endHour;
}
