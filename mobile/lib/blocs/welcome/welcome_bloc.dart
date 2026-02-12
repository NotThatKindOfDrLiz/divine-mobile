// ABOUTME: BLoC for welcome screen returning-user state
// ABOUTME: Loads cached profile for last logged-in user from SQLite

import 'package:bloc/bloc.dart';
import 'package:db_client/db_client.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'welcome_event.dart';
part 'welcome_state.dart';

/// Key used to persist the last user's hex pubkey in SharedPreferences.
const kLastUserPubkeyHexKey = 'last_user_pubkey_hex';

/// BLoC for managing the welcome screen state.
///
/// Handles:
/// - Loading returning-user data from SharedPreferences + SQLite cache
/// - Clearing the returning-user state (back button)
/// - Triggering auth actions (log back in, create new account, login options)
class WelcomeBloc extends Bloc<WelcomeEvent, WelcomeState> {
  WelcomeBloc({
    required SharedPreferences sharedPreferences,
    required UserProfilesDao userProfilesDao,
    required AuthService authService,
  }) : _prefs = sharedPreferences,
       _userProfilesDao = userProfilesDao,
       _authService = authService,
       super(const WelcomeState()) {
    on<WelcomeStarted>(_onStarted);
    on<WelcomeLastUserDismissed>(_onLastUserDismissed);
    on<WelcomeLogBackInRequested>(_onLogBackIn);
    on<WelcomeCreateNewAccountRequested>(_onCreateNewAccount);
    on<WelcomeLoginOptionsRequested>(_onLoginOptionsRequested);
  }

  final SharedPreferences _prefs;
  final UserProfilesDao _userProfilesDao;
  final AuthService _authService;

  Future<void> _onStarted(
    WelcomeStarted event,
    Emitter<WelcomeState> emit,
  ) async {
    final hex = _prefs.getString(kLastUserPubkeyHexKey);

    if (hex == null) {
      emit(state.copyWith(status: WelcomeStatus.loaded));
      return;
    }

    UserProfile? profile;
    try {
      profile = await _userProfilesDao.getProfile(hex);
    } catch (e) {
      Log.warning(
        'Failed to load cached profile for returning user: $e',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
    }

    emit(
      state.copyWith(
        status: WelcomeStatus.loaded,
        lastUserPubkeyHex: hex,
        lastUserProfile: profile,
      ),
    );
  }

  Future<void> _onLastUserDismissed(
    WelcomeLastUserDismissed event,
    Emitter<WelcomeState> emit,
  ) async {
    await _prefs.remove(kLastUserPubkeyHexKey);
    emit(state.copyWith(status: WelcomeStatus.loaded, clearLastUser: true));
  }

  Future<void> _onLogBackIn(
    WelcomeLogBackInRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    emit(
      state.copyWith(
        status: WelcomeStatus.accepting,
        clearError: true,
        shouldNavigateToLoginOptions: false,
      ),
    );

    try {
      await _authService.signInAutomatically();
    } catch (e) {
      Log.error(
        'Failed to log back in: $e',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      emit(
        state.copyWith(
          status: WelcomeStatus.error,
          error: 'Failed to continue: $e',
        ),
      );
    }
  }

  Future<void> _onCreateNewAccount(
    WelcomeCreateNewAccountRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    emit(
      state.copyWith(
        status: WelcomeStatus.accepting,
        clearError: true,
        shouldNavigateToLoginOptions: false,
      ),
    );

    try {
      await _authService.signOut(deleteKeys: true);
      await _authService.signInAutomatically();
    } catch (e) {
      Log.error(
        'Failed to create new account: $e',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      emit(
        state.copyWith(
          status: WelcomeStatus.error,
          error: 'Failed to continue: $e',
        ),
      );
    }
  }

  Future<void> _onLoginOptionsRequested(
    WelcomeLoginOptionsRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    await _authService.acceptTerms();
    emit(state.copyWith(shouldNavigateToLoginOptions: true));
  }
}
