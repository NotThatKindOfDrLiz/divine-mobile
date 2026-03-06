// ABOUTME: Model for invite code API responses
// ABOUTME: Represents validation, claiming, and status results from invite faucet

import 'package:equatable/equatable.dart';

/// Result of an invite code operation (validate or claim).
class InviteCodeResult extends Equatable {
  const InviteCodeResult({
    required this.valid,
    this.message,
    this.code,
    this.remainingUses,
  });

  /// Creates an [InviteCodeResult] from a JSON map.
  factory InviteCodeResult.fromJson(Map<String, dynamic> json) {
    return InviteCodeResult(
      valid: json['valid'] as bool? ?? false,
      message: json['message'] as String?,
      code: json['code'] as String?,
      remainingUses: json['remaining_uses'] as int?,
    );
  }

  /// Whether the invite code is valid and was accepted.
  final bool valid;

  /// Human-readable message from the server (e.g. error reason).
  final String? message;

  /// The invite code that was validated/claimed.
  final String? code;

  /// Number of remaining uses for this code (if applicable).
  final int? remainingUses;

  @override
  List<Object?> get props => [valid, message, code, remainingUses];
}
