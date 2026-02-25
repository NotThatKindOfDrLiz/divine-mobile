// ABOUTME: State for InviteStatusBloc
// ABOUTME: Immutable state with Equatable for rebuild optimization

part of 'invite_status_bloc.dart';

/// Status of invite status operations.
enum InviteStatusStatus {
  /// Initial state, no operation in progress.
  initial,

  /// Fetching invite status from server.
  loading,

  /// Invite status fetched successfully.
  success,

  /// Invite status fetch failed.
  failure,
}

/// State for the invite status BLoC.
final class InviteStatusState extends Equatable {
  const InviteStatusState({
    this.status = InviteStatusStatus.initial,
    this.result,
    this.error,
  });

  /// Current status of invite status operations.
  final InviteStatusStatus status;

  /// The invite status result from the server.
  final InviteCodeResult? result;

  /// Error message from the last failed operation.
  final String? error;

  /// Whether an operation is in progress.
  bool get isLoading => status == InviteStatusStatus.loading;

  /// Creates a copy of this state with the given fields replaced.
  InviteStatusState copyWith({
    InviteStatusStatus? status,
    InviteCodeResult? result,
    String? error,
    bool clearError = false,
  }) {
    return InviteStatusState(
      status: status ?? this.status,
      result: result ?? this.result,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, result, error];
}
