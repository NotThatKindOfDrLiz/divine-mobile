// ABOUTME: Repository for persisting invite code state locally
// ABOUTME: Uses SharedPreferences to track whether device has a claimed code

import 'package:shared_preferences/shared_preferences.dart';

/// Repository for local invite code state.
///
/// Persists whether the device has successfully claimed an invite code.
/// This is read synchronously by the router for redirect logic.
class InviteCodeRepository {
  InviteCodeRepository({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static const String _hasClaimedCodeKey = 'invite_code_claimed';
  static const String _claimedCodeKey = 'invite_code_value';

  /// Whether this device has a verified invite code stored locally.
  bool get hasClaimedCode => _prefs.getBool(_hasClaimedCodeKey) ?? false;

  /// Persists a successfully claimed invite code.
  Future<void> setClaimedCode(String code) async {
    await _prefs.setBool(_hasClaimedCodeKey, true);
    await _prefs.setString(_claimedCodeKey, code);
  }

  /// Clears the stored invite code (e.g. on logout).
  Future<void> clear() async {
    await _prefs.remove(_hasClaimedCodeKey);
    await _prefs.remove(_claimedCodeKey);
  }
}
