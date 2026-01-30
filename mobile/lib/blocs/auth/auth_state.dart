// ABOUTME: States for authentication cubit
// ABOUTME: Tracks sign in/sign up form state and email verification

part of 'auth_cubit.dart';

/// State for authentication cubit
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before form is ready
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// State when auth form is displayed and interactive
class AuthFormState extends AuthState {
  const AuthFormState({
    this.email = '',
    this.password = '',
    this.isSignIn = false,
    this.emailError,
    this.passwordError,
    this.generalError,
    this.obscurePassword = true,
    this.isSubmitting = false,
  });

  /// User's email address
  final String email;

  /// User's password
  final String password;

  /// True for sign in mode, false for sign up mode
  final bool isSignIn;

  /// Error message for email field validation
  final String? emailError;

  /// Error message for password field validation
  final String? passwordError;

  /// General error message (e.g., network error, auth failure)
  final String? generalError;

  /// Whether password is obscured in the UI
  final bool obscurePassword;

  /// Whether form is currently being submitted
  final bool isSubmitting;

  /// Returns true if form has no validation errors and fields are filled
  bool get canSubmit =>
      email.isNotEmpty &&
      password.isNotEmpty &&
      emailError == null &&
      passwordError == null &&
      !isSubmitting;

  AuthFormState copyWith({
    String? email,
    String? password,
    bool? isSignIn,
    String? emailError,
    String? passwordError,
    String? generalError,
    bool? obscurePassword,
    bool? isSubmitting,
    bool clearEmailError = false,
    bool clearPasswordError = false,
    bool clearGeneralError = false,
  }) {
    return AuthFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      isSignIn: isSignIn ?? this.isSignIn,
      emailError: clearEmailError ? null : (emailError ?? this.emailError),
      passwordError:
          clearPasswordError ? null : (passwordError ?? this.passwordError),
      generalError:
          clearGeneralError ? null : (generalError ?? this.generalError),
      obscurePassword: obscurePassword ?? this.obscurePassword,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object?> get props => [
        email,
        password,
        isSignIn,
        emailError,
        passwordError,
        generalError,
        obscurePassword,
        isSubmitting,
      ];
}

/// State when email verification is required after registration
class AuthEmailVerification extends AuthState {
  const AuthEmailVerification({
    required this.email,
    required this.deviceCode,
    required this.verifier,
  });

  /// Email address that needs verification
  final String email;

  /// Device code for polling verification status
  final String deviceCode;

  /// PKCE verifier for code exchange
  final String verifier;

  @override
  List<Object?> get props => [email, deviceCode, verifier];
}

/// State after successful authentication
class AuthSuccess extends AuthState {
  const AuthSuccess();
}

/// State when an error occurs that requires user action
class AuthError extends AuthState {
  const AuthError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
