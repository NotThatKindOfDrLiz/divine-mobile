// ABOUTME: Repository for npub verification status storage
// ABOUTME: Single source of truth for per-user npub verification in SharedPreferences

import 'package:shared_preferences/shared_preferences.dart';

/// Repository for managing npub verification status.
///
/// Stores verification status per-npub to support multiple identities.
/// When a user signs in without an invite code, their npub must be verified
/// with the server before they can access the app.
class NpubVerificationRepository {
  NpubVerificationRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Key prefix for npub verification status.
  /// Format: 'npub_verified_{npub}' = 'true'
  static const _keyPrefix = 'npub_verified_';

  /// Check if the given npub has been verified.
  bool isVerified(String npub) {
    return _prefs.getBool('$_keyPrefix$npub') ?? false;
  }

  /// Mark an npub as verified.
  Future<bool> setVerified(String npub) {
    return _prefs.setBool('$_keyPrefix$npub', true);
  }

  /// Clear verification status for an npub.
  Future<bool> clearVerification(String npub) {
    return _prefs.remove('$_keyPrefix$npub');
  }
}
