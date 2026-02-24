// ABOUTME: State for WaitlistBloc
// ABOUTME: Immutable state with Equatable for rebuild optimization

part of 'waitlist_bloc.dart';

/// Status of waitlist operations.
enum WaitlistStatus {
  /// Initial state, no operation in progress.
  initial,

  /// Submitting email to waitlist.
  submitting,

  /// Email submitted successfully.
  success,

  /// Email submission failed.
  failure,
}

/// State for the waitlist BLoC.
final class WaitlistState extends Equatable {
  const WaitlistState({
    this.status = WaitlistStatus.initial,
    this.submittedEmail,
    this.error,
  });

  /// Current status of waitlist operations.
  final WaitlistStatus status;

  /// The email that was successfully submitted.
  final String? submittedEmail;

  /// Error message from the last failed operation.
  final String? error;

  /// Whether an operation is in progress.
  bool get isSubmitting => status == WaitlistStatus.submitting;

  /// Whether the last operation was successful.
  bool get isSuccess => status == WaitlistStatus.success;

  /// Whether the last operation failed.
  bool get isFailure => status == WaitlistStatus.failure;

  /// Creates a copy of this state with the given fields replaced.
  WaitlistState copyWith({
    WaitlistStatus? status,
    String? submittedEmail,
    String? error,
    bool clearError = false,
  }) {
    return WaitlistState(
      status: status ?? this.status,
      submittedEmail: submittedEmail ?? this.submittedEmail,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, submittedEmail, error];
}
