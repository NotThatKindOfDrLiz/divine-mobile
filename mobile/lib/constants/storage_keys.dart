// ABOUTME: Centralized constants for SharedPreferences and secure storage keys
// ABOUTME: Provides single source of truth for all persisted key names

/// Constants for SharedPreferences and secure storage keys.
abstract class StorageKeys {
  /// Hex-encoded public key of the currently logged-in user.
  static const currentUserPubkeyHex = 'current_user_pubkey_hex';

  /// Whether the user has accepted TOS and verified they are 16+.
  static const ageVerified16Plus = 'age_verified_16_plus';

  /// ISO 8601 timestamp of when the user accepted terms of service.
  static const termsAcceptedAt = 'terms_accepted_at';

  /// Prefix for per-user following list cache.
  /// Full key is: `${followingListPrefix}$pubkeyHex`
  static const followingListPrefix = 'following_list_';

  /// Builds the full key for a user's cached following list.
  static String followingListKey(String pubkeyHex) =>
      '$followingListPrefix$pubkeyHex';
}
