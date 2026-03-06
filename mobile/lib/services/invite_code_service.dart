// ABOUTME: API client for the invite code server (invite.divine.video)
// ABOUTME: Handles validate and claim endpoints for invite code gating

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/config/app_config.dart';
import 'package:openvine/models/invite_code_result.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Exception thrown by invite code API operations.
class InviteCodeException implements Exception {
  const InviteCodeException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'InviteCodeException: $message (status: ${statusCode ?? 'none'})';
}

/// API client for the invite code server.
///
/// Endpoints (on invite.divine.video):
/// - `POST /v1/validate` — check if a code is valid without consuming it
/// - `POST /v1/consume-invite` — consume a code (requires auth, done later)
///
/// For the pre-auth gate we only use validate. Consumption happens during
/// account creation when the user has a keypair.
class InviteCodeService {
  InviteCodeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static String get _baseUrl => AppConfig.inviteServerBaseUrl;
  static const Duration _defaultTimeout = Duration(seconds: 20);

  /// Normalizes an invite code to uppercase XXXX-XXXX format.
  static String normalizeCode(String raw) {
    final alphanumeric = raw.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    final upper = alphanumeric.toUpperCase();

    if (upper.length <= 4) return upper;

    final end = upper.length > 8 ? 8 : upper.length;
    return '${upper.substring(0, 4)}-${upper.substring(4, end)}';
  }

  /// Whether [raw] looks like a valid XXXX-XXXX invite code.
  static bool looksLikeInviteCode(String raw) {
    final normalized = normalizeCode(raw);
    return RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(normalized);
  }

  /// Validates an invite code without consuming it.
  ///
  /// Returns an [InviteCodeResult] indicating whether the code is valid.
  ///
  /// Throws:
  /// * [InviteCodeException] if the request fails or times out.
  Future<InviteCodeResult> validateCode(String code) async {
    final normalized = normalizeCode(code);

    try {
      final uri = Uri.parse('$_baseUrl/v1/validate');
      final response = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({'code': normalized}),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return InviteCodeResult.fromJson(json);
      }

      final body = _tryDecodeBody(response.body);
      final message =
          body?['message'] as String? ?? 'Code not found. Please try again.';

      // Check for "used" flag in error response
      final used = body?['used'] as bool? ?? false;
      if (used) {
        return InviteCodeResult(
          valid: false,
          message: 'Code already redeemed.',
          code: normalized,
        );
      }

      return InviteCodeResult(valid: false, message: message, code: normalized);
    } on TimeoutException {
      throw const InviteCodeException('Request timed out. Please try again.');
    } catch (e) {
      if (e is InviteCodeException) rethrow;
      Log.error(
        'Failed to validate invite code: $e',
        name: 'InviteCodeService',
        category: LogCategory.api,
      );
      throw const InviteCodeException(
        'Code not found. Please try again.',
      );
    }
  }

  /// Claims (validates) an invite code for the pre-auth gate.
  ///
  /// This validates the code and marks it locally as claimed. The actual
  /// server-side consumption happens later during account creation via
  /// `POST /v1/consume-invite` with NIP-98 auth.
  ///
  /// Throws:
  /// * [InviteCodeException] if the request fails or times out.
  Future<InviteCodeResult> claimCode(String code) async {
    // For the pre-auth gate, claiming == validating.
    // Server-side consumption requires a keypair and happens during
    // account creation.
    return validateCode(code);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'Divine-Mobile/1.0',
  };

  Map<String, dynamic>? _tryDecodeBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
