// ABOUTME: Tests for LegalCubit
// ABOUTME: Verifies state transitions, checkbox toggling, and AuthService delegation

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/legal/legal_cubit.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late SharedPreferences prefs;
  late MockAuthService mockAuthService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockAuthService = MockAuthService();

    // Default stub for acceptTerms
    when(() => mockAuthService.acceptTerms()).thenAnswer((_) async {});
  });

  group('LegalCubit', () {
    test('initial state is LegalInitial', () {
      final cubit = LegalCubit(sharedPreferences: prefs, authService: mockAuthService);
      expect(cubit.state, const LegalInitial());
      cubit.close();
    });

    blocTest<LegalCubit, LegalState>(
      'loadSavedState emits LegalLoaded with false values when prefs are empty',
      build: () => LegalCubit(sharedPreferences: prefs, authService: mockAuthService),
      act: (cubit) => cubit.loadSavedState(),
      expect: () => [
        const LegalLoaded(
          isAgeVerified: false,
          isTermsAccepted: false,
        ),
      ],
    );

    blocTest<LegalCubit, LegalState>(
      'loadSavedState loads previously saved values',
      setUp: () async {
        await prefs.setBool('age_verified_16_plus', true);
        await prefs.setString('terms_accepted_at', '2024-01-01T00:00:00.000Z');
      },
      build: () => LegalCubit(sharedPreferences: prefs, authService: mockAuthService),
      act: (cubit) => cubit.loadSavedState(),
      expect: () => [
        const LegalLoaded(
          isAgeVerified: true,
          isTermsAccepted: true,
        ),
      ],
    );

    blocTest<LegalCubit, LegalState>(
      'toggleAgeVerified toggles age verification',
      build: () => LegalCubit(sharedPreferences: prefs, authService: mockAuthService),
      seed: () => const LegalLoaded(
        isAgeVerified: false,
        isTermsAccepted: false,
      ),
      act: (cubit) => cubit.toggleAgeVerified(),
      expect: () => [
        const LegalLoaded(
          isAgeVerified: true,
          isTermsAccepted: false,
        ),
      ],
    );

    blocTest<LegalCubit, LegalState>(
      'toggleAgeVerified clears ageShowError when toggling',
      build: () => LegalCubit(sharedPreferences: prefs, authService: mockAuthService),
      seed: () => const LegalLoaded(
        isAgeVerified: false,
        isTermsAccepted: false,
        ageShowError: true,
      ),
      act: (cubit) => cubit.toggleAgeVerified(),
      expect: () => [
        const LegalLoaded(
          isAgeVerified: true,
          isTermsAccepted: false,
          ageShowError: false,
        ),
      ],
    );

    blocTest<LegalCubit, LegalState>(
      'toggleTermsAccepted toggles terms acceptance',
      build: () => LegalCubit(sharedPreferences: prefs, authService: mockAuthService),
      seed: () => const LegalLoaded(
        isAgeVerified: false,
        isTermsAccepted: false,
      ),
      act: (cubit) => cubit.toggleTermsAccepted(),
      expect: () => [
        const LegalLoaded(
          isAgeVerified: false,
          isTermsAccepted: true,
        ),
      ],
    );

    blocTest<LegalCubit, LegalState>(
      'toggleTermsAccepted clears termsShowError when toggling',
      build: () => LegalCubit(sharedPreferences: prefs, authService: mockAuthService),
      seed: () => const LegalLoaded(
        isAgeVerified: false,
        isTermsAccepted: false,
        termsShowError: true,
      ),
      act: (cubit) => cubit.toggleTermsAccepted(),
      expect: () => [
        const LegalLoaded(
          isAgeVerified: false,
          isTermsAccepted: true,
          termsShowError: false,
        ),
      ],
    );

    group('submit', () {
      blocTest<LegalCubit, LegalState>(
        'shows error on unchecked age when submitting',
        build: () => LegalCubit(sharedPreferences: prefs, authService: mockAuthService),
        seed: () => const LegalLoaded(
          isAgeVerified: false,
          isTermsAccepted: true,
        ),
        act: (cubit) => cubit.submit(),
        expect: () => [
          const LegalLoaded(
            isAgeVerified: false,
            isTermsAccepted: true,
            ageShowError: true,
            termsShowError: false,
          ),
        ],
      );

      blocTest<LegalCubit, LegalState>(
        'shows error on unchecked terms when submitting',
        build: () => LegalCubit(sharedPreferences: prefs, authService: mockAuthService),
        seed: () => const LegalLoaded(
          isAgeVerified: true,
          isTermsAccepted: false,
        ),
        act: (cubit) => cubit.submit(),
        expect: () => [
          const LegalLoaded(
            isAgeVerified: true,
            isTermsAccepted: false,
            ageShowError: false,
            termsShowError: true,
          ),
        ],
      );

      blocTest<LegalCubit, LegalState>(
        'shows errors on both unchecked when submitting',
        build: () => LegalCubit(sharedPreferences: prefs, authService: mockAuthService),
        seed: () => const LegalLoaded(
          isAgeVerified: false,
          isTermsAccepted: false,
        ),
        act: (cubit) => cubit.submit(),
        expect: () => [
          const LegalLoaded(
            isAgeVerified: false,
            isTermsAccepted: false,
            ageShowError: true,
            termsShowError: true,
          ),
        ],
      );

      blocTest<LegalCubit, LegalState>(
        'emits LegalSubmitting then LegalSuccess when both checked',
        build: () => LegalCubit(sharedPreferences: prefs, authService: mockAuthService),
        seed: () => const LegalLoaded(
          isAgeVerified: true,
          isTermsAccepted: true,
        ),
        act: (cubit) => cubit.submit(),
        expect: () => [
          const LegalSubmitting(),
          const LegalSuccess(),
        ],
        verify: (_) {
          // Verify AuthService.acceptTerms() was called
          verify(() => mockAuthService.acceptTerms()).called(1);
        },
      );
    });
  });

  group('LegalLoaded', () {
    test('canSubmit returns false when age not verified', () {
      const state = LegalLoaded(
        isAgeVerified: false,
        isTermsAccepted: true,
      );
      expect(state.canSubmit, false);
    });

    test('canSubmit returns false when terms not accepted', () {
      const state = LegalLoaded(
        isAgeVerified: true,
        isTermsAccepted: false,
      );
      expect(state.canSubmit, false);
    });

    test('canSubmit returns true when both checked', () {
      const state = LegalLoaded(
        isAgeVerified: true,
        isTermsAccepted: true,
      );
      expect(state.canSubmit, true);
    });

    test('copyWith creates correct copy', () {
      const state = LegalLoaded(
        isAgeVerified: false,
        isTermsAccepted: false,
      );

      final updated = state.copyWith(
        isAgeVerified: true,
        termsShowError: true,
      );

      expect(updated.isAgeVerified, true);
      expect(updated.isTermsAccepted, false);
      expect(updated.ageShowError, false);
      expect(updated.termsShowError, true);
    });

    test('props includes all fields for equality', () {
      const state1 = LegalLoaded(
        isAgeVerified: true,
        isTermsAccepted: true,
        ageShowError: false,
        termsShowError: false,
      );
      const state2 = LegalLoaded(
        isAgeVerified: true,
        isTermsAccepted: true,
        ageShowError: false,
        termsShowError: false,
      );
      const state3 = LegalLoaded(
        isAgeVerified: true,
        isTermsAccepted: true,
        ageShowError: true,
        termsShowError: false,
      );

      expect(state1, state2);
      expect(state1, isNot(state3));
    });
  });
}
