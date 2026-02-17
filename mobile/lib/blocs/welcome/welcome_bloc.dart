// ABOUTME: BLoC for welcome screen returning-user state
// ABOUTME: Loads known accounts list for multi-account sign-in support

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:db_client/db_client.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/utils/unified_logger.dart';

part 'welcome_event.dart';
part 'welcome_state.dart';

/// BLoC for managing the welcome screen state.
///
/// Handles:
/// - Loading known accounts from the AuthService registry + SQLite cache
/// - Selecting which account to sign back in with
/// - Removing accounts from the known list
/// - Triggering auth actions (log back in, create new account, login options)
class WelcomeBloc extends Bloc<WelcomeEvent, WelcomeState> {
  WelcomeBloc({
    required UserProfilesDao userProfilesDao,
    required AuthService authService,
  }) : _userProfilesDao = userProfilesDao,
       _authService = authService,
       super(const WelcomeState()) {
    on<WelcomeStarted>(_onStarted, transformer: droppable());
    on<WelcomeLastUserDismissed>(
      _onLastUserDismissed,
      transformer: droppable(),
    );
    on<WelcomeLogBackInRequested>(_onLogBackIn, transformer: droppable());
    on<WelcomeAccountSelected>(_onAccountSelected);
    on<WelcomeCreateAccountRequested>(
      _onCreateAccountRequested,
      transformer: droppable(),
    );
    on<WelcomeNavigationConsumed>(_onNavigationConsumed);
    on<WelcomeLoginOptionsRequested>(
      _onLoginOptionsRequested,
      transformer: droppable(),
    );
  }

  final UserProfilesDao _userProfilesDao;
  final AuthService _authService;

  Future<void> _onStarted(
    WelcomeStarted event,
    Emitter<WelcomeState> emit,
  ) async {
    // Load known accounts from the registry
    final knownAccounts = await _authService.getKnownAccounts();

    if (knownAccounts.isEmpty) {
      emit(state.copyWith(status: WelcomeStatus.loaded));
      return;
    }

    // Load cached profiles for each known account
    final accounts = <PreviousAccount>[];
    for (final known in knownAccounts) {
      UserProfile? profile;
      try {
        profile = await _userProfilesDao.getProfile(known.pubkeyHex);
      } catch (e) {
        Log.warning(
          'Failed to load cached profile for ${known.pubkeyHex}: $e',
          name: 'WelcomeBloc',
          category: LogCategory.auth,
        );
      }
      accounts.add(
        PreviousAccount(
          pubkeyHex: known.pubkeyHex,
          authSource: known.authSource,
          profile: profile,
        ),
      );
    }

    emit(
      state.copyWith(status: WelcomeStatus.loaded, previousAccounts: accounts),
    );
  }

  void _onLastUserDismissed(
    WelcomeLastUserDismissed event,
    Emitter<WelcomeState> emit,
  ) {
    emit(
      state.copyWith(
        status: WelcomeStatus.loaded,
        clearAccounts: true,
        clearSelectedPubkey: true,
      ),
    );
  }

  Future<void> _onLogBackIn(
    WelcomeLogBackInRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    final account = state.selectedAccount;
    if (account == null) return;

    emit(
      state.copyWith(
        status: WelcomeStatus.accepting,
        signingInPubkeyHex: account.pubkeyHex,
        clearError: true,
        shouldNavigateToLoginOptions: false,
        shouldNavigateToCreateAccount: false,
      ),
    );

    try {
      await _authService.signInForAccount(
        account.pubkeyHex,
        account.authSource,
      );
    } catch (e) {
      Log.error(
        'Failed to log back in as ${account.pubkeyHex}: $e',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      emit(
        state.copyWith(
          status: WelcomeStatus.error,
          error: 'Failed to continue: $e',
          clearSigningIn: true,
        ),
      );
    }
  }

  void _onAccountSelected(
    WelcomeAccountSelected event,
    Emitter<WelcomeState> emit,
  ) {
    emit(state.copyWith(selectedPubkeyHex: event.pubkeyHex));
  }

  Future<void> _onCreateAccountRequested(
    WelcomeCreateAccountRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    await _authService.acceptTerms();
    emit(state.copyWith(shouldNavigateToCreateAccount: true));
  }

  void _onNavigationConsumed(
    WelcomeNavigationConsumed event,
    Emitter<WelcomeState> emit,
  ) {
    emit(
      state.copyWith(
        shouldNavigateToLoginOptions: false,
        shouldNavigateToCreateAccount: false,
      ),
    );
  }

  Future<void> _onLoginOptionsRequested(
    WelcomeLoginOptionsRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    await _authService.acceptTerms();
    emit(state.copyWith(shouldNavigateToLoginOptions: true));
  }
}
