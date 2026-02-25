// ABOUTME: Tests for AppStateListenable
// ABOUTME: Verifies composite ChangeNotifier notifies on auth, invite, and
// ABOUTME: verification state changes

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_code/invite_code_bloc.dart';
import 'package:openvine/blocs/npub_verification/npub_verification_bloc.dart';
import 'package:openvine/repositories/invite_code_repository.dart';
import 'package:openvine/repositories/npub_verification_repository.dart';
import 'package:openvine/router/providers/app_state_listenable.dart';
import 'package:openvine/models/invite_code_result.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/invite_code_service.dart';
import 'package:openvine/services/npub_verification_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockInviteCodeRepository extends Mock implements InviteCodeRepository {}

class _MockNpubVerificationRepository extends Mock
    implements NpubVerificationRepository {}

void main() {
  group(AppStateListenable, () {
    late _MockAuthService mockAuthService;
    late InviteCodeBloc inviteCodeBloc;
    late NpubVerificationBloc npubVerificationBloc;
    late _MockInviteCodeRepository mockInviteCodeRepository;
    late _MockNpubVerificationRepository mockNpubVerificationRepository;
    late StreamController<AuthState> authStreamController;

    // Mock services for the blocs
    late _MockInviteCodeService mockInviteCodeService;
    late _MockNpubVerificationService mockNpubVerificationService;

    setUp(() {
      mockAuthService = _MockAuthService();
      mockInviteCodeRepository = _MockInviteCodeRepository();
      mockNpubVerificationRepository = _MockNpubVerificationRepository();
      mockInviteCodeService = _MockInviteCodeService();
      mockNpubVerificationService = _MockNpubVerificationService();
      authStreamController = StreamController<AuthState>.broadcast();

      when(
        () => mockAuthService.authState,
      ).thenReturn(AuthState.unauthenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => authStreamController.stream);
      when(() => mockInviteCodeRepository.hasStoredCode).thenReturn(false);
      when(
        () => mockNpubVerificationRepository.isVerified(any()),
      ).thenReturn(false);

      inviteCodeBloc = InviteCodeBloc(
        inviteCodeService: mockInviteCodeService,
        repository: mockInviteCodeRepository,
      );
      npubVerificationBloc = NpubVerificationBloc(
        verificationService: mockNpubVerificationService,
        repository: mockNpubVerificationRepository,
      );
    });

    tearDown(() async {
      authStreamController.close();
      await inviteCodeBloc.close();
      await npubVerificationBloc.close();
    });

    AppStateListenable buildListenable() => AppStateListenable(
      authService: mockAuthService,
      inviteCodeBloc: inviteCodeBloc,
      npubVerificationBloc: npubVerificationBloc,
    );

    group('auth state changes', () {
      test('notifies listeners when auth transitions '
          'from unauthenticated to authenticated', () async {
        final listenable = buildListenable();
        var notifyCount = 0;
        listenable.addListener(() => notifyCount++);

        authStreamController.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);

        expect(notifyCount, equals(1));

        listenable.dispose();
      });

      test('notifies listeners when auth transitions '
          'from authenticated to unauthenticated', () async {
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.authenticated);
        final listenable = buildListenable();
        var notifyCount = 0;
        listenable.addListener(() => notifyCount++);

        authStreamController.add(AuthState.unauthenticated);
        await Future<void>.delayed(Duration.zero);

        expect(notifyCount, equals(1));

        listenable.dispose();
      });

      test('does not notify when auth state changes '
          'but remains unauthenticated', () async {
        final listenable = buildListenable();
        var notifyCount = 0;
        listenable.addListener(() => notifyCount++);

        // awaitingTosAcceptance is still "not authenticated"
        authStreamController.add(AuthState.awaitingTosAcceptance);
        await Future<void>.delayed(Duration.zero);

        expect(notifyCount, equals(0));

        listenable.dispose();
      });
    });

    group('invite code state changes', () {
      test(
        'notifies listeners when invite code status changes to success',
        () async {
          when(() => mockInviteCodeService.claimCode(any())).thenAnswer(
            (_) async => const InviteCodeResult(valid: true, code: 'ABCD1234'),
          );

          final listenable = buildListenable();
          var notifyCount = 0;
          listenable.addListener(() => notifyCount++);

          inviteCodeBloc.add(const InviteCodeClaimRequested('ABCD1234'));
          // Wait for bloc to process loading + success
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Should only notify on success, not on loading
          expect(notifyCount, equals(1));

          listenable.dispose();
        },
      );
    });

    group('npub verification state changes', () {
      test('notifies listeners on any verification state change', () async {
        final listenable = buildListenable();
        var notifyCount = 0;
        listenable.addListener(() => notifyCount++);

        npubVerificationBloc.add(const NpubVerificationSkipInviteSet());
        await Future<void>.delayed(Duration.zero);

        expect(notifyCount, equals(1));

        listenable.dispose();
      });
    });

    group('synchronous getters', () {
      test('hasInviteCode delegates to invite code bloc', () {
        when(() => mockInviteCodeRepository.hasStoredCode).thenReturn(true);
        final listenable = buildListenable();

        expect(listenable.hasInviteCode, isTrue);

        listenable.dispose();
      });

      test('skipInviteRequested delegates to npub verification bloc', () {
        final listenable = buildListenable();

        expect(listenable.skipInviteRequested, isFalse);

        listenable.dispose();
      });

      test('isNpubVerified delegates to npub verification bloc', () {
        when(
          () => mockNpubVerificationRepository.isVerified(any()),
        ).thenReturn(false);
        final listenable = buildListenable();

        expect(listenable.isNpubVerified('npub1test'), isFalse);

        listenable.dispose();
      });

      test('isNpubVerified returns false for null npub', () {
        final listenable = buildListenable();

        expect(listenable.isNpubVerified(null), isFalse);

        listenable.dispose();
      });
    });

    group('dispose', () {
      test('cancels all subscriptions', () async {
        final listenable = buildListenable();
        var notifyCount = 0;
        listenable.addListener(() => notifyCount++);

        listenable.dispose();

        // After dispose, auth state changes should not notify
        authStreamController.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);

        expect(notifyCount, equals(0));
      });
    });
  });
}

// Mock services needed by the real blocs
class _MockInviteCodeService extends Mock implements InviteCodeService {}

class _MockNpubVerificationService extends Mock
    implements NpubVerificationService {}
