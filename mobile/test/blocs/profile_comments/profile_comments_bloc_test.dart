import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_comments/profile_comments_bloc.dart';

class _MockCommentsRepository extends Mock implements CommentsRepository {}

const _testAuthorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _testRootEventId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _testRootAuthorPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

void main() {
  group(ProfileCommentsBloc, () {
    late _MockCommentsRepository mockCommentsRepository;

    setUp(() {
      mockCommentsRepository = _MockCommentsRepository();
    });

    ProfileCommentsBloc createBloc() => ProfileCommentsBloc(
      commentsRepository: mockCommentsRepository,
      targetUserPubkey: _testAuthorPubkey,
    );

    Comment createComment({
      required String id,
      required int createdAtSeconds,
    }) => Comment(
      id: id,
      content: 'Comment $id',
      authorPubkey: _testAuthorPubkey,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000),
      rootEventId: _testRootEventId,
      rootAuthorPubkey: _testRootAuthorPubkey,
    );

    group(ProfileCommentsState, () {
      test('has correct initial state', () {
        final bloc = createBloc();
        expect(bloc.state.status, equals(ProfileCommentsStatus.initial));
        expect(bloc.state.videoReplies, isEmpty);
        expect(bloc.state.textComments, isEmpty);
        expect(bloc.state.error, isNull);
        expect(bloc.state.isLoadingMore, isFalse);
        expect(bloc.state.hasMoreContent, isTrue);
        expect(bloc.state.paginationCursor, isNull);
        expect(bloc.state.totalCount, equals(0));
        bloc.close();
      });

      test('copyWith preserves existing values', () {
        const state = ProfileCommentsState();
        final updated = state.copyWith(status: ProfileCommentsStatus.success);
        expect(updated.status, equals(ProfileCommentsStatus.success));
        expect(updated.videoReplies, isEmpty);
        expect(updated.textComments, isEmpty);
      });

      test('copyWith with clearError sets error to null', () {
        final state = const ProfileCommentsState().copyWith(
          error: 'some error',
        );
        expect(state.error, equals('some error'));

        final cleared = state.copyWith(clearError: true);
        expect(cleared.error, isNull);
      });

      test('isLoaded returns true when status is success', () {
        final state = const ProfileCommentsState().copyWith(
          status: ProfileCommentsStatus.success,
        );
        expect(state.isLoaded, isTrue);
        expect(state.isLoading, isFalse);
      });

      test('isLoading returns true when status is loading', () {
        final state = const ProfileCommentsState().copyWith(
          status: ProfileCommentsStatus.loading,
        );
        expect(state.isLoading, isTrue);
        expect(state.isLoaded, isFalse);
      });

      test('totalCount returns sum of video and text comments', () {
        final state = ProfileCommentsState(
          textComments: [
            createComment(id: 't1', createdAtSeconds: 1000),
            createComment(id: 't2', createdAtSeconds: 1001),
            createComment(id: 't3', createdAtSeconds: 1002),
          ],
        );
        expect(state.totalCount, equals(3));
      });
    });

    group('ProfileCommentsSyncRequested', () {
      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'emits [loading, success] with comments',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              createComment(id: 'c1', createdAtSeconds: 1700001000),
              createComment(id: 'c2', createdAtSeconds: 1700000500),
              createComment(id: 'c3', createdAtSeconds: 1700000000),
            ],
          );
          return createBloc();
        },
        act: (bloc) => bloc.add(const ProfileCommentsSyncRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.status,
            'status',
            ProfileCommentsStatus.loading,
          ),
          isA<ProfileCommentsState>()
              .having(
                (s) => s.status,
                'status',
                ProfileCommentsStatus.success,
              )
              .having(
                (s) => s.textComments.length,
                'textComments.length',
                3,
              )
              .having(
                (s) => s.hasMoreContent,
                'hasMoreContent',
                isFalse,
              ),
        ],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'emits [loading, success] with empty lists when no comments',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => []);
          return createBloc();
        },
        act: (bloc) => bloc.add(const ProfileCommentsSyncRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.status,
            'status',
            ProfileCommentsStatus.loading,
          ),
          isA<ProfileCommentsState>()
              .having(
                (s) => s.status,
                'status',
                ProfileCommentsStatus.success,
              )
              .having(
                (s) => s.textComments,
                'textComments',
                isEmpty,
              ),
        ],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'emits [loading, failure] on repository error',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
            ),
          ).thenThrow(
            const LoadCommentsByAuthorFailedException('Network error'),
          );
          return createBloc();
        },
        act: (bloc) => bloc.add(const ProfileCommentsSyncRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.status,
            'status',
            ProfileCommentsStatus.loading,
          ),
          isA<ProfileCommentsState>()
              .having(
                (s) => s.status,
                'status',
                ProfileCommentsStatus.failure,
              )
              .having(
                (s) => s.error,
                'error',
                equals('Failed to load comments'),
              ),
        ],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'does not re-fetch when already loading',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => []);
          return createBloc();
        },
        seed: () => const ProfileCommentsState(
          status: ProfileCommentsStatus.loading,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsSyncRequested()),
        expect: () => <ProfileCommentsState>[],
        verify: (_) {
          verifyNever(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
            ),
          );
        },
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'sets hasMoreContent to true when page is full',
        build: () {
          // Return exactly 50 comments (page size)
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => List.generate(
              50,
              (i) => createComment(
                id: 'c$i',
                createdAtSeconds: 1700000000 - i,
              ),
            ),
          );
          return createBloc();
        },
        act: (bloc) => bloc.add(const ProfileCommentsSyncRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.status,
            'status',
            ProfileCommentsStatus.loading,
          ),
          isA<ProfileCommentsState>().having(
            (s) => s.hasMoreContent,
            'hasMoreContent',
            isTrue,
          ),
        ],
      );
    });

    group('ProfileCommentsLoadMoreRequested', () {
      final seedComments = [
        createComment(id: 'c1', createdAtSeconds: 1700001000),
        createComment(id: 'c2', createdAtSeconds: 1700000500),
        createComment(id: 'c3', createdAtSeconds: 1700000000),
      ];
      final seedCursor = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'appends new comments to existing lists',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              createComment(id: 'c4', createdAtSeconds: 1699999500),
              createComment(id: 'c5', createdAtSeconds: 1699999000),
            ],
          );
          return createBloc();
        },
        seed: () => ProfileCommentsState(
          status: ProfileCommentsStatus.success,
          textComments: seedComments,
          paginationCursor: seedCursor,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<ProfileCommentsState>()
              .having(
                (s) => s.isLoadingMore,
                'isLoadingMore',
                isFalse,
              )
              .having(
                (s) => s.textComments.length,
                'textComments.length',
                5,
              ),
        ],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'deduplicates against existing comments',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              // Duplicate of existing
              createComment(id: 'c3', createdAtSeconds: 1700000000),
              // New
              createComment(id: 'c4', createdAtSeconds: 1699999000),
            ],
          );
          return createBloc();
        },
        seed: () => ProfileCommentsState(
          status: ProfileCommentsStatus.success,
          textComments: seedComments,
          paginationCursor: seedCursor,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<ProfileCommentsState>()
              .having(
                (s) => s.textComments.length,
                'textComments.length',
                4,
              )
              .having(
                (s) => s.isLoadingMore,
                'isLoadingMore',
                isFalse,
              ),
        ],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'does nothing when not in success state',
        build: createBloc,
        seed: () => const ProfileCommentsState(
          status: ProfileCommentsStatus.loading,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => <ProfileCommentsState>[],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'does nothing when already loading more',
        build: createBloc,
        seed: () => ProfileCommentsState(
          status: ProfileCommentsStatus.success,
          textComments: seedComments,
          isLoadingMore: true,
          paginationCursor: seedCursor,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => <ProfileCommentsState>[],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'does nothing when no more content',
        build: createBloc,
        seed: () => ProfileCommentsState(
          status: ProfileCommentsStatus.success,
          textComments: seedComments,
          hasMoreContent: false,
          paginationCursor: seedCursor,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => <ProfileCommentsState>[],
      );

      blocTest<ProfileCommentsBloc, ProfileCommentsState>(
        'resets isLoadingMore on error and preserves existing data',
        build: () {
          when(
            () => mockCommentsRepository.loadCommentsByAuthor(
              authorPubkey: any(named: 'authorPubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(Exception('Network error'));
          return createBloc();
        },
        seed: () => ProfileCommentsState(
          status: ProfileCommentsStatus.success,
          textComments: seedComments,
          paginationCursor: seedCursor,
        ),
        act: (bloc) => bloc.add(const ProfileCommentsLoadMoreRequested()),
        expect: () => [
          isA<ProfileCommentsState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<ProfileCommentsState>()
              .having(
                (s) => s.isLoadingMore,
                'isLoadingMore',
                isFalse,
              )
              .having(
                (s) => s.textComments.length,
                'textComments.length',
                3,
              ),
        ],
      );
    });
  });
}
