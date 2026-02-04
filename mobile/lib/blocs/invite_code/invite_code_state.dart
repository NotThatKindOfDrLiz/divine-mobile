// ABOUTME: State for InviteCodeBloc
// ABOUTME: Immutable state with Equatable for rebuild optimization

part of 'invite_code_bloc.dart';

/// Status of invite code operations.
enum InviteCodeStatus {
  /// Initial state, no operation in progress.
  initial,

  /// Claiming an invite code.
  loading,

  /// Invite code claimed successfully.
  success,

  /// Invite code claim failed.
  failure,
}

/// State for the invite code BLoC.
final class InviteCodeState extends Equatable {
  const InviteCodeState({
    this.status = InviteCodeStatus.initial,
    this.hasStoredCode = false,
    this.result,
    this.error,
  });

  /// Current status of invite code operations.
  final InviteCodeStatus status;

  /// Whether the device has a verified invite code stored locally.
  final bool hasStoredCode;

  /// Result of the last claim operation.
  final InviteCodeResult? result;

  /// Error message from the last failed operation.
  final String? error;

  /// Whether an operation is in progress.
  bool get isLoading => status == InviteCodeStatus.loading;

  /// Whether the last operation was successful.
  bool get isSuccess => status == InviteCodeStatus.success;

  /// Whether the last operation failed.
  bool get isFailure => status == InviteCodeStatus.failure;

  /// Creates a copy of this state with the given fields replaced.
  InviteCodeState copyWith({
    InviteCodeStatus? status,
    bool? hasStoredCode,
    InviteCodeResult? result,
    String? error,
    bool clearError = false,
  }) {
    return InviteCodeState(
      status: status ?? this.status,
      hasStoredCode: hasStoredCode ?? this.hasStoredCode,
      result: result ?? this.result,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        status,
        hasStoredCode,
        result,
        error,
      ];
}
