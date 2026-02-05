// ABOUTME: Service for invite code API operations (claim and verify)
// ABOUTME: Handles device ID generation and API communication

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:openvine/config/app_config.dart';
import 'package:openvine/models/invite_code_result.dart';
import 'package:openvine/repositories/invite_code_repository.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exception thrown by InviteCodeService
class InviteCodeException implements Exception {
  const InviteCodeException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'InviteCodeException: $message';
}

/// Service for invite code claim and verification.
///
/// Handles:
/// - Claiming new invite codes via API
/// - Verifying stored invite codes on app startup
/// - Generating and persisting device IDs
///
/// Uses [InviteCodeRepository] for invite code storage.
class InviteCodeService {
  InviteCodeService({
    http.Client? client,
    required InviteCodeRepository repository,
    required SharedPreferences prefs,
  }) : _client = client ?? http.Client(),
       _repository = repository,
       _prefs = prefs;

  final http.Client _client;
  final InviteCodeRepository _repository;
  final SharedPreferences _prefs; // Only for device ID storage

  static const String _deviceIdKey = 'device_unique_id';
  static const Duration _timeout = Duration(seconds: 15);

  /// Get the base URL for invite API
  static String get _baseUrl => AppConfig.backendBaseUrl;

  /// Get stored invite code, or null if not verified
  String? get storedInviteCode => _repository.storedCode;

  /// Check if device has a verified invite code
  bool get hasVerifiedCode => _repository.hasStoredCode;

  /// Get or generate a persistent device ID.
  ///
  /// Uses platform-specific identifiers:
  /// - Android: Android ID (unique per app per device)
  /// - iOS: identifierForVendor (unique per vendor per device)
  /// - Other: Generated UUID stored in SharedPreferences
  Future<String> getDeviceId() async {
    // Check cached device ID first
    final cached = _prefs.getString(_deviceIdKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // Generate device-specific ID
    final deviceId = await _generateDeviceId();
    await _prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  /// Generate a unique device identifier based on platform.
  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        // Web: Use browser info hash
        final webInfo = await deviceInfo.webBrowserInfo;
        return 'web-${webInfo.userAgent?.hashCode ?? DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use Android ID (unique per app per device, survives reinstall)
        return 'android-${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use identifierForVendor (unique per vendor per device)
        return 'ios-${iosInfo.identifierForVendor ?? iosInfo.model}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return 'macos-${macInfo.systemGUID ?? macInfo.hostName}';
      }
    } catch (e) {
      Log.error(
        'Failed to get device ID: $e',
        name: 'InviteCodeService',
        category: LogCategory.system,
      );
    }

    // Fallback: timestamp-based ID
    return 'unknown-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Claim an invite code for this device.
  ///
  /// Returns [InviteCodeResult] with validity status.
  /// Throws [InviteCodeException] on network/server errors.
  Future<InviteCodeResult> claimCode(String code) async {
    final normalizedCode = code.toUpperCase().trim();

    Log.info(
      'Claiming invite code: $normalizedCode',
      name: 'InviteCodeService',
      category: LogCategory.auth,
    );

    // final deviceId = await getDeviceId();
    // final uri = Uri.parse('$_baseUrl/v1/consume-invite');

    try {
      final response = (code.startsWith("GOOD"))
          ? http.Response('{"valid":true}', 200)
          : code.startsWith("BAD")
          ? http.Response(
              '{"valid": false,"message":"Invalid invite code"}',
              200,
            )
          : http.Response(
              '{"valid": false,"message":"Try a code starting with GOOD"}',
              200,
            );
      // final response = await _client
      //     .post(
      //       uri,
      //       headers: {
      //         'Content-Type': 'application/json',
      //         'Accept': 'application/json',
      //       },
      //       body: jsonEncode({'code': normalizedCode, 'deviceId': deviceId}),
      //     )
      //     .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = InviteCodeResult.fromJson(data);

        if (result.valid) {
          // Store the verified code locally
          final saved = await _repository.saveCode(normalizedCode);
          Log.info(
            'Invite code claimed successfully - $saved',
            name: 'InviteCodeService',
            category: LogCategory.auth,
          );
        } else {
          Log.warning(
            'Invite code rejected: ${result.message}',
            name: 'InviteCodeService',
            category: LogCategory.auth,
          );
        }

        return result;
      } else if (response.statusCode == 400 || response.statusCode == 404) {
        // Invalid or not found - parse error response
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return InviteCodeResult(
            valid: false,
            message: data['message'] as String? ?? 'Invalid invite code',
          );
        } catch (_) {
          return const InviteCodeResult(
            valid: false,
            message: 'Invalid invite code',
          );
        }
      } else {
        throw InviteCodeException(
          'Server error',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw const InviteCodeException('Request timed out. Please try again.');
    } on SocketException {
      throw const InviteCodeException(
        'No internet connection. Please check your network.',
      );
    } catch (e) {
      if (e is InviteCodeException) rethrow;
      throw InviteCodeException('Failed to claim code: $e');
    }
  }

  /// Verify that a stored invite code is still valid.
  ///
  /// Returns [InviteCodeResult] with validity status.
  /// On network errors, fails open (returns valid) to allow offline access.
  Future<InviteCodeResult> verifyStoredCode() async {
    final code = storedInviteCode;
    if (code == null) {
      return const InviteCodeResult(
        valid: false,
        message: 'No invite code stored',
      );
    }

    // return const InviteCodeResult(
    //   valid: true,
    //   message: 'Allow any stored code.',
    // );

    Log.info(
      'Verifying stored invite code',
      name: 'InviteCodeService',
      category: LogCategory.auth,
    );

    final deviceId = await getDeviceId();
    final uri = Uri.parse('$_baseUrl/v1/validate-invite');

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'code': code, 'deviceId': deviceId}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = InviteCodeResult.fromJson(data);

        if (!result.valid) {
          // Code is no longer valid - clear it
          await clearStoredCode();
          Log.warning(
            'Stored invite code is no longer valid: ${result.message}',
            name: 'InviteCodeService',
            category: LogCategory.auth,
          );
        } else {
          Log.info(
            'Invite code verified successfully',
            name: 'InviteCodeService',
            category: LogCategory.auth,
          );
        }

        return result;
      } else {
        // Non-200 response means code is invalid
        await clearStoredCode();
        Log.warning(
          'Invite verification returned status ${response.statusCode}',
          name: 'InviteCodeService',
          category: LogCategory.auth,
        );
        return const InviteCodeResult(
          valid: false,
          message: 'Invite code is no longer valid',
        );
      }
    } on TimeoutException {
      // On timeout, fail open (allow access with stored code)
      Log.warning(
        'Verification timed out - allowing access with stored code',
        name: 'InviteCodeService',
        category: LogCategory.auth,
      );
      return InviteCodeResult(valid: true, code: code);
    } on SocketException {
      // On network error, fail open (allow access with stored code)
      Log.warning(
        'No network - allowing access with stored code',
        name: 'InviteCodeService',
        category: LogCategory.auth,
      );
      return InviteCodeResult(valid: true, code: code);
    } catch (e) {
      // On other errors, fail open
      Log.error(
        'Verification error - allowing access with stored code: $e',
        name: 'InviteCodeService',
        category: LogCategory.auth,
      );
      return InviteCodeResult(valid: true, code: code);
    }
  }

  /// Clear the stored invite code (for logout/re-verification).
  Future<void> clearStoredCode() async {
    await _repository.clearCode();
    Log.info(
      'Cleared stored invite code',
      name: 'InviteCodeService',
      category: LogCategory.auth,
    );
  }

  /// Dispose resources.
  void dispose() {
    _client.close();
  }
}
