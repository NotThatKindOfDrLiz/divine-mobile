// ABOUTME: Model for invite code API response
// ABOUTME: Used by InviteCodeService to parse claim/verify responses

/// Result of an invite code claim or verification request.
class InviteCodeResult {
  const InviteCodeResult({
    required this.valid,
    this.message,
    this.code,
    this.claimedAt,
  });

  factory InviteCodeResult.fromJson(Map<String, dynamic> json) {
    return InviteCodeResult(
      valid: json['valid'] as bool? ?? false,
      message: json['message'] as String?,
      code: json['code'] as String?,
      claimedAt: json['claimedAt'] != null
          ? DateTime.parse(json['claimedAt'] as String)
          : null,
    );
  }

  /// Whether the invite code is valid.
  final bool valid;

  /// Human-readable message (success or error reason).
  final String? message;

  /// The invite code that was verified (echoed back).
  final String? code;

  /// When this device claimed the code (null if not yet claimed).
  final DateTime? claimedAt;
}
