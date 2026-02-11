// ABOUTME: Service for npub verification API operations
// ABOUTME: Verifies user npubs with Divine Relay server for invite skip flow

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:openvine/config/app_config.dart';
import 'package:openvine/models/npub_verification_result.dart';
import 'package:openvine/repositories/npub_verification_repository.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Exception thrown by NpubVerificationService.
class NpubVerificationException implements Exception {
  const NpubVerificationException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'NpubVerificationException: $message';
}

/// Service for verifying npubs with the Divine Relay server.
///
/// Used when users skip invite code by signing in with existing account.
/// Server verifies the npub is associated with a valid invite code claim
/// or is otherwise authorized for access.
class NpubVerificationService {
  NpubVerificationService({
    http.Client? client,
    required NpubVerificationRepository repository,
    required Future<String> Function() getDeviceId,
  }) : _client = client ?? http.Client(),
       _repository = repository,
       _getDeviceId = getDeviceId;

  final http.Client _client;
  final NpubVerificationRepository _repository;
  final Future<String> Function() _getDeviceId;

  static const Duration _timeout = Duration(seconds: 15);

  /// Get the base URL for API.
  static String get _baseUrl => AppConfig.backendBaseUrl;

  /// Check if an npub is already verified locally.
  bool isVerified(String npub) => _repository.isVerified(npub);

  /// Verify an npub with the Divine Relay server.
  ///
  /// Returns [NpubVerificationResult] with validity status.
  /// Stores result locally if valid.
  /// Throws [NpubVerificationException] on network/server errors.
  Future<NpubVerificationResult> verifyNpub(String npub) async {
    Log.info(
      'Verifying npub with server',
      name: 'NpubVerificationService',
      category: LogCategory.auth,
    );

    final deviceId = await _getDeviceId();
    final uri = Uri.parse('$_baseUrl/v1/verify-npub');
    Log.info(
      'Verifying npub is stubbed out to always fail '
      'Ignoring $deviceId $uri $_timeout',
      name: 'NpubVerificationService',
      category: LogCategory.auth,
    );
    try {
      final response = http.Response(jsonEncode({'valid': false}), 500);
      // final response = await _client
      // .post(
      //   uri,
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'Accept': 'application/json',
      //   },
      //   body: jsonEncode({
      //     'npub': npub,
      //     'deviceId': deviceId,
      //   }),
      // )
      // .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = NpubVerificationResult.fromJson(data);

        if (result.valid) {
          // Store verification locally
          await _repository.setVerified(npub);
          Log.info(
            'Npub verified successfully',
            name: 'NpubVerificationService',
            category: LogCategory.auth,
          );
        } else {
          Log.warning(
            'Npub verification rejected: ${result.message}',
            name: 'NpubVerificationService',
            category: LogCategory.auth,
          );
        }

        return result;
      } else if (response.statusCode == 400 || response.statusCode == 404) {
        // Not found or invalid - parse error response
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return NpubVerificationResult(
            valid: false,
            message:
                data['message'] as String? ??
                'This account is not yet verified for access.',
          );
        } catch (_) {
          return const NpubVerificationResult(
            valid: false,
            message: 'This account is not yet verified for access.',
          );
        }
      } else {
        throw NpubVerificationException(
          'Server error',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw const NpubVerificationException(
        'Request timed out. Please try again.',
      );
    } on SocketException {
      throw const NpubVerificationException(
        'No internet connection. Please check your network.',
      );
    } catch (e) {
      if (e is NpubVerificationException) rethrow;
      throw NpubVerificationException('Verification failed: $e');
    }
  }

  /// Clear verification status for an npub (used on logout).
  Future<void> clearVerification(String npub) async {
    await _repository.clearVerification(npub);
    Log.info(
      'Cleared npub verification status',
      name: 'NpubVerificationService',
      category: LogCategory.auth,
    );
  }

  /// Dispose resources.
  void dispose() {
    _client.close();
  }
}
