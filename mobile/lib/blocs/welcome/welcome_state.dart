// ABOUTME: State for WelcomeBloc
// ABOUTME: Immutable state with Equatable for rebuild optimization

part of 'welcome_bloc.dart';

/// Status of welcome screen operations.
enum WelcomeStatus {
  /// Initial state, data not yet loaded.
  initial,

  /// Returning-user data loaded (or confirmed absent).
  loaded,

  /// An auth action (log back in / create account) is in progress.
  accepting,

  /// An auth action failed.
  error,
}

/// State for the welcome BLoC.
final class WelcomeState extends Equatable {
  const WelcomeState({
    this.status = WelcomeStatus.initial,
    this.lastUserPubkeyHex,
    this.lastUserProfile,
    this.error,
    this.shouldNavigateToLoginOptions = false,
    this.shouldNavigateToCreateAccount = false,
  });

  /// Current status of welcome operations.
  final WelcomeStatus status;

  /// Hex pubkey of the last logged-in user, if any.
  final String? lastUserPubkeyHex;

  /// Cached profile for the last user, if found in SQLite.
  final UserProfile? lastUserProfile;

  /// Error message from the last failed operation.
  final String? error;

  /// When true, the UI should navigate to the login options screen.
  final bool shouldNavigateToLoginOptions;

  /// When true, the UI should navigate to the create account screen.
  final bool shouldNavigateToCreateAccount;

  /// Whether a returning user was detected.
  bool get hasReturningUser => lastUserPubkeyHex != null;

  /// Whether an auth action is in progress.
  bool get isAccepting => status == WelcomeStatus.accepting;

  /// Creates a copy of this state with the given fields replaced.
  WelcomeState copyWith({
    WelcomeStatus? status,
    String? lastUserPubkeyHex,
    UserProfile? lastUserProfile,
    String? error,
    bool? shouldNavigateToLoginOptions,
    bool? shouldNavigateToCreateAccount,
    bool clearLastUser = false,
    bool clearError = false,
  }) {
    return WelcomeState(
      status: status ?? this.status,
      lastUserPubkeyHex: clearLastUser
          ? null
          : (lastUserPubkeyHex ?? this.lastUserPubkeyHex),
      lastUserProfile: clearLastUser
          ? null
          : (lastUserProfile ?? this.lastUserProfile),
      error: clearError ? null : (error ?? this.error),
      shouldNavigateToLoginOptions:
          shouldNavigateToLoginOptions ?? this.shouldNavigateToLoginOptions,
      shouldNavigateToCreateAccount:
          shouldNavigateToCreateAccount ?? this.shouldNavigateToCreateAccount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    lastUserPubkeyHex,
    lastUserProfile,
    error,
    shouldNavigateToLoginOptions,
    shouldNavigateToCreateAccount,
  ];
}
