// ABOUTME: State for NpubVerificationBloc
// ABOUTME: Immutable state with Equatable for rebuild optimization

part of 'npub_verification_bloc.dart';

/// Status of npub verification operations.
enum NpubVerificationStatus {
  /// Initial state, no verification in progress.
  initial,

  /// Verification in progress.
  verifying,

  /// Npub verified successfully.
  verified,

  /// Verification failed.
  failed,
}

/// State for the npub verification BLoC.
final class NpubVerificationState extends Equatable {
  const NpubVerificationState({
    this.status = NpubVerificationStatus.initial,
    this.skipInviteRequested = false,
    this.error,
  });

  /// Current status of verification operations.
  final NpubVerificationStatus status;

  /// Whether user has requested to skip invite code entry.
  ///
  /// This is an in-memory flag that is NOT persisted. If the user
  /// restarts the app, they will see the invite screen again.
  final bool skipInviteRequested;

  /// Error message from the last failed operation.
  final String? error;

  /// Whether verification is in progress.
  bool get isVerifying => status == NpubVerificationStatus.verifying;

  /// Whether the last verification was successful.
  bool get isVerified => status == NpubVerificationStatus.verified;

  /// Whether the last verification failed.
  bool get isFailed => status == NpubVerificationStatus.failed;

  /// Creates a copy of this state with the given fields replaced.
  NpubVerificationState copyWith({
    NpubVerificationStatus? status,
    bool? skipInviteRequested,
    String? error,
    bool clearError = false,
  }) {
    return NpubVerificationState(
      status: status ?? this.status,
      skipInviteRequested: skipInviteRequested ?? this.skipInviteRequested,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, skipInviteRequested, error];
}
