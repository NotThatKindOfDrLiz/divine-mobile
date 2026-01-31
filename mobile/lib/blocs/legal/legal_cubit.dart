// ABOUTME: Cubit for managing legal acceptance state
// ABOUTME: Handles age verification and terms acceptance, delegates persistence to AuthService

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'legal_state.dart';

/// Cubit for managing legal acceptance flow.
///
/// Handles:
/// - Loading saved acceptance state from SharedPreferences
/// - Toggling age verification and terms acceptance
/// - Validating and delegating persistence to AuthService
class LegalCubit extends Cubit<LegalState> {
  LegalCubit({
    required SharedPreferences sharedPreferences,
    required AuthService authService,
  }) : _prefs = sharedPreferences,
       _authService = authService,
       super(const LegalInitial());

  final SharedPreferences _prefs;
  final AuthService _authService;

  // SharedPreferences keys (matching existing auth_service.dart keys)
  static const _kAgeVerifiedKey = 'age_verified_16_plus';
  static const _kTermsAcceptedKey = 'terms_accepted_at';

  /// Load saved acceptance state from SharedPreferences
  void loadSavedState() {
    final isAgeVerified = _prefs.getBool(_kAgeVerifiedKey) ?? false;
    final termsAcceptedAt = _prefs.getString(_kTermsAcceptedKey);
    final isTermsAccepted = termsAcceptedAt != null;

    Log.info(
      'Loaded legal state: age=$isAgeVerified, terms=$isTermsAccepted',
      name: 'LegalCubit',
      category: LogCategory.auth,
    );

    emit(
      LegalLoaded(
        isAgeVerified: isAgeVerified,
        isTermsAccepted: isTermsAccepted,
      ),
    );
  }

  /// Toggle age verification checkbox
  void toggleAgeVerified() {
    final current = state;
    if (current is! LegalLoaded) return;

    emit(
      current.copyWith(
        isAgeVerified: !current.isAgeVerified,
        ageShowError: false, // Clear error when toggling
      ),
    );
  }

  /// Toggle terms acceptance checkbox
  void toggleTermsAccepted() {
    final current = state;
    if (current is! LegalLoaded) return;

    emit(
      current.copyWith(
        isTermsAccepted: !current.isTermsAccepted,
        termsShowError: false, // Clear error when toggling
      ),
    );
  }

  /// Submit acceptance - validates and persists to SharedPreferences
  Future<void> submit() async {
    final current = state;
    if (current is! LegalLoaded) return;

    // Validate - show errors on unchecked items
    if (!current.canSubmit) {
      Log.info(
        'Submit blocked: age=${current.isAgeVerified}, terms=${current.isTermsAccepted}',
        name: 'LegalCubit',
        category: LogCategory.auth,
      );

      emit(
        current.copyWith(
          ageShowError: !current.isAgeVerified,
          termsShowError: !current.isTermsAccepted,
        ),
      );
      return;
    }

    // Start submitting
    emit(const LegalSubmitting());

    try {
      // Delegate persistence to AuthService (single source of truth)
      await _authService.acceptTerms();

      Log.info(
        'Legal acceptance saved successfully via AuthService',
        name: 'LegalCubit',
        category: LogCategory.auth,
      );

      emit(const LegalSuccess());
    } catch (e) {
      Log.error(
        'Failed to save legal acceptance: $e',
        name: 'LegalCubit',
        category: LogCategory.auth,
      );

      emit(LegalError(message: 'Failed to save: $e'));
    }
  }
}
