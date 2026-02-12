// ABOUTME: Repository for invite code storage operations
// ABOUTME: Single source of truth for invite code persistence in SharedPreferences

import 'package:shared_preferences/shared_preferences.dart';

/// Repository for managing invite code storage.
///
/// Provides a clean interface for storing and retrieving verified invite codes.
/// This is the single source of truth for invite code persistence.
class InviteCodeRepository {
  InviteCodeRepository(this._prefs);

  final SharedPreferences _prefs;

  /// SharedPreferences key for the verified invite code.
  static const inviteCodeKey = 'verified_invite_code';

  /// Get the currently stored invite code, or null if none.
  String? get storedCode => _prefs.getString(inviteCodeKey);

  /// Check if a verified invite code is stored.
  bool get hasStoredCode => storedCode != null;

  /// Save a verified invite code.
  Future<bool> saveCode(String code) => _prefs.setString(inviteCodeKey, code);

  /// Clear the stored invite code.
  Future<bool> clearCode() => _prefs.remove(inviteCodeKey);
}
