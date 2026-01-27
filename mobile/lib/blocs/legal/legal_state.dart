// ABOUTME: States for legal acceptance cubit
// ABOUTME: Tracks age verification and terms acceptance with error states

part of 'legal_cubit.dart';

/// State for legal acceptance cubit
sealed class LegalState extends Equatable {
  const LegalState();

  @override
  List<Object?> get props => [];
}

/// Initial state before loading saved preferences
class LegalInitial extends LegalState {
  const LegalInitial();
}

/// State when legal form is loaded and interactive
class LegalLoaded extends LegalState {
  const LegalLoaded({
    required this.isAgeVerified,
    required this.isTermsAccepted,
    this.ageShowError = false,
    this.termsShowError = false,
  });

  /// Whether user has confirmed they are 16+
  final bool isAgeVerified;

  /// Whether user has accepted terms, privacy policy, and safety standards
  final bool isTermsAccepted;

  /// Whether to show error state on age checkbox (tried to submit unchecked)
  final bool ageShowError;

  /// Whether to show error state on terms checkbox (tried to submit unchecked)
  final bool termsShowError;

  /// Returns true if both checkboxes are checked
  bool get canSubmit => isAgeVerified && isTermsAccepted;

  LegalLoaded copyWith({
    bool? isAgeVerified,
    bool? isTermsAccepted,
    bool? ageShowError,
    bool? termsShowError,
  }) {
    return LegalLoaded(
      isAgeVerified: isAgeVerified ?? this.isAgeVerified,
      isTermsAccepted: isTermsAccepted ?? this.isTermsAccepted,
      ageShowError: ageShowError ?? this.ageShowError,
      termsShowError: termsShowError ?? this.termsShowError,
    );
  }

  @override
  List<Object?> get props => [
    isAgeVerified,
    isTermsAccepted,
    ageShowError,
    termsShowError,
  ];
}

/// State while persisting acceptance to SharedPreferences
class LegalSubmitting extends LegalState {
  const LegalSubmitting();
}

/// State after successful submission - navigate to signup
class LegalSuccess extends LegalState {
  const LegalSuccess();
}

/// State when an error occurs during submission
class LegalError extends LegalState {
  const LegalError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
