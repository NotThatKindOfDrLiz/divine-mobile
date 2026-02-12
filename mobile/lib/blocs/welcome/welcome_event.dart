// ABOUTME: Events for WelcomeBloc
// ABOUTME: Sealed classes for type-safe event handling

part of 'welcome_bloc.dart';

/// Base class for all welcome events.
sealed class WelcomeEvent extends Equatable {
  const WelcomeEvent();
}

/// Load returning-user data from SharedPreferences and SQLite cache.
final class WelcomeStarted extends WelcomeEvent {
  const WelcomeStarted();

  @override
  List<Object?> get props => [];
}

/// Dismiss the returning-user variant and show the default welcome screen.
///
/// Clears the `last_user_pubkey_hex` from SharedPreferences.
final class WelcomeLastUserDismissed extends WelcomeEvent {
  const WelcomeLastUserDismissed();

  @override
  List<Object?> get props => [];
}

/// Request to log back in with the previous identity.
///
/// Calls [AuthService.signInAutomatically] to reload existing keys.
final class WelcomeLogBackInRequested extends WelcomeEvent {
  const WelcomeLogBackInRequested();

  @override
  List<Object?> get props => [];
}

/// Request to navigate to the create account screen (email/password sign-up).
///
/// Calls [AuthService.acceptTerms] and signals the UI to navigate.
final class WelcomeCreateAccountRequested extends WelcomeEvent {
  const WelcomeCreateAccountRequested();

  @override
  List<Object?> get props => [];
}

/// Request to create a fresh account, discarding the previous identity.
///
/// Calls [AuthService.signOut] with `deleteKeys: true`, then navigates
/// to the create account screen.
final class WelcomeCreateNewAccountRequested extends WelcomeEvent {
  const WelcomeCreateNewAccountRequested();

  @override
  List<Object?> get props => [];
}

/// Signals that a navigation flag has been consumed by the UI.
///
/// Resets [WelcomeState.shouldNavigateToLoginOptions] and
/// [WelcomeState.shouldNavigateToCreateAccount] to `false`.
final class WelcomeNavigationConsumed extends WelcomeEvent {
  const WelcomeNavigationConsumed();

  @override
  List<Object?> get props => [];
}

/// Request to navigate to login options (email/bunker/etc).
///
/// Calls [AuthService.acceptTerms] and signals the UI to navigate.
final class WelcomeLoginOptionsRequested extends WelcomeEvent {
  const WelcomeLoginOptionsRequested();

  @override
  List<Object?> get props => [];
}
