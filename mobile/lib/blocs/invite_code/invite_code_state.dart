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
    this.hasClaimedCode = false,
    this.result,
    this.error,
  });

  /// Current status of invite code operations.
  final InviteCodeStatus status;

  /// Whether the device has a verified invite code stored locally.
  final bool hasClaimedCode;

  /// Result of the last claim operation.
  final InviteCodeResult? result;

  /// Error message from the last failed operation.
  final String? error;

  /// Whether an operation is in progress.
  bool get isLoading => status == InviteCodeStatus.loading;

  /// Creates a copy of this state with the given fields replaced.
  InviteCodeState copyWith({
    InviteCodeStatus? status,
    bool? hasClaimedCode,
    InviteCodeResult? result,
    String? error,
    bool clearError = false,
  }) {
    return InviteCodeState(
      status: status ?? this.status,
      hasClaimedCode: hasClaimedCode ?? this.hasClaimedCode,
      result: result ?? this.result,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, hasClaimedCode, result, error];
}
