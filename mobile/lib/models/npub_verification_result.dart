// ABOUTME: Model for npub verification API response
// ABOUTME: Used by NpubVerificationService to parse server responses

/// Result of an npub verification request.
///
/// Returned by the Divine Relay server when verifying that an npub
/// is associated with a valid invite code claim.
class NpubVerificationResult {
  /// Creates a new [NpubVerificationResult].
  const NpubVerificationResult({
    required this.valid,
    this.message,
  });

  /// Creates a [NpubVerificationResult] from JSON response.
  factory NpubVerificationResult.fromJson(Map<String, dynamic> json) {
    return NpubVerificationResult(
      valid: json['valid'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  /// Whether the npub is valid/verified for app access.
  final bool valid;

  /// Human-readable message from server (e.g., error reason).
  final String? message;

  /// Converts this result to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'valid': valid,
      if (message != null) 'message': message,
    };
  }

  @override
  String toString() =>
      'NpubVerificationResult(valid: $valid, message: $message)';
}
