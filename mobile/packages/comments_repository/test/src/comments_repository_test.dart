import 'package:comments_repository/comments_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class MockNostrClient extends Mock implements NostrClient {}

class FakeEvent extends Fake implements Event {}

/// Kind 1111 is the NIP-22 comment kind for replying to non-Kind-1 events.
const int _commentKind = EventKind.comment;

/// Kind 5 is the NIP-09 deletion request kind.
const int _deletionKind = EventKind.eventDeletion;

/// Example kind for a video event (Kind 34236 for NIP-71).
const int _testRootEventKind = EventKind.videoVertical;

void main() {
  group('CommentsRepository', () {
    late MockNostrClient mockNostrClient;
    late CommentsRepository repository;

    const testRootEventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const testRootAuthorPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const testUserPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    // NIP-22: Addressable ID format is kind:pubkey:d-tag
    const testAddressableId =
        '$_testRootEventKind:$testRootAuthorPubkey:test-video-d-tag';

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(FakeEvent());
    });

    setUp(() {
      mockNostrClient = MockNostrClient();
      when(() => mockNostrClient.publicKey).thenReturn(testUserPubkey);
      repository = CommentsRepository(nostrClient: mockNostrClient);
    });

    group('constructor', () {
      test('creates repository with nostrClient', () {
        final repo = CommentsRepository(nostrClient: mockNostrClient);
        expect(repo, isNotNull);
      });
    });

    group('loadComments', () {
      test('returns empty thread when no comments', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
        );

        expect(result.isEmpty, isTrue);
        expect(result.totalCount, equals(0));
        expect(result.comments, isEmpty);
        expect(result.rootEventId, equals(testRootEventId));
      });

      test('queries by both A-tag and E-tag for compatibility', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.length, equals(2));

        // First filter should be A-tag
        expect(filters[0].kinds, contains(_commentKind));
        expect(filters[0].uppercaseA, contains(testAddressableId));

        // Second filter should be E-tag
        expect(filters[1].kinds, contains(_commentKind));
        expect(filters[1].uppercaseE, contains(testRootEventId));
      });

      test('returns thread with single top-level comment', () async {
        final commentEvent = _createCommentEvent(
          id: 'comment1',
          content: 'Great video!',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [commentEvent]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
        );

        expect(result.isNotEmpty, isTrue);
        expect(result.totalCount, equals(1));
        expect(result.comments.length, equals(1));
        expect(result.comments.first.content, equals('Great video!'));
        expect(result.comments.first.replyToEventId, isNull);
      });

      test('returns flat list with replies in chronological order', () async {
        final rootComment = _createCommentEvent(
          id: 'comment1',
          content: 'Parent comment',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
        );

        final replyComment = _createCommentEvent(
          id: 'comment2',
          content: 'Reply to parent',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
          replyToEventId: 'comment1',
          replyToAuthorPubkey: testUserPubkey,
          createdAt: 2000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [rootComment, replyComment]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
        );

        expect(result.totalCount, equals(2));
        expect(result.comments.length, equals(2));
        // Newest first (reply is newer)
        expect(result.comments.first.content, equals('Reply to parent'));
        expect(result.comments.first.replyToEventId, equals('comment1'));
        expect(result.comments.last.content, equals('Parent comment'));
      });

      test('sorts all comments chronologically (newest first)', () async {
        final oldComment = _createCommentEvent(
          id: 'comment1',
          content: 'Old comment',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
        );

        final newComment = _createCommentEvent(
          id: 'comment2',
          content: 'New comment',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
          createdAt: 2000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [oldComment, newComment]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
        );

        expect(result.comments.first.content, 'New comment');
        expect(result.comments.last.content, 'Old comment');
      });

      test('includes replies in chronological order with parent', () async {
        final parentComment = _createCommentEvent(
          id: 'parent',
          content: 'Parent',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
        );

        final oldReply = _createCommentEvent(
          id: 'reply1',
          content: 'Old reply',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
          replyToEventId: 'parent',
          replyToAuthorPubkey: testUserPubkey,
          createdAt: 2000,
        );

        final newReply = _createCommentEvent(
          id: 'reply2',
          content: 'New reply',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
          replyToEventId: 'parent',
          replyToAuthorPubkey: testUserPubkey,
          createdAt: 3000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [parentComment, newReply, oldReply]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
        );

        expect(result.comments.length, equals(3));
        // Chronological: newest first
        expect(result.comments[0].content, 'New reply');
        expect(result.comments[1].content, 'Old reply');
        expect(result.comments[2].content, 'Parent');
      });

      test(
        'includes orphan replies in flat list with replyTo reference',
        () async {
          // Orphan replies are just included in the flat list with
          // their replyToEventId
          final orphanReply = _createCommentEvent(
            id: 'orphan',
            content: 'Orphan reply',
            pubkey: testUserPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
            rootAddressableId: testAddressableId,
            replyToEventId: 'nonexistent_parent',
            replyToAuthorPubkey: testUserPubkey,
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [orphanReply]);

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootAddressableId: testAddressableId,
          );

          // Orphan is in the flat list
          expect(result.comments.length, equals(1));
          expect(result.comments.first.content, 'Orphan reply');
          expect(result.comments.first.replyToEventId, 'nonexistent_parent');
        },
      );

      test('throws LoadCommentsFailedException on error', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootAddressableId: testAddressableId,
          ),
          throwsA(isA<LoadCommentsFailedException>()),
        );
      });

      test('respects limit parameter', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
          limit: 50,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.first.limit, equals(50));
      });

      test('passes before parameter as until filter for pagination', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final beforeTime = DateTime.fromMillisecondsSinceEpoch(2000000000);
        await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
          before: beforeTime,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        // `until` is in seconds (Nostr epoch), so divide milliseconds by 1000
        expect(filters.first.until, equals(2000000000 ~/ 1000));
      });

      test('does not include until filter when before is null', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootAddressableId: testAddressableId,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.first.until, isNull);
      });
    });

    group('postComment', () {
      test(
        'posts top-level comment with correct NIP-22 tags',
        () async {
          Event? capturedEvent;

          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            inv,
          ) async {
            return capturedEvent = inv.positionalArguments.first as Event;
          });

          await repository.postComment(
            content: 'Test comment',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
            rootAddressableId: testAddressableId,
          );

          expect(capturedEvent, isNotNull);
          expect(capturedEvent!.kind, equals(_commentKind));
          expect(capturedEvent!.content, equals('Test comment'));

          // Check NIP-22 tags
          final uppercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'A')
              .toList();
          final uppercaseETags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'E')
              .toList();
          final uppercaseKTags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'K')
              .toList();
          final uppercasePTags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'P')
              .toList();

          // Lowercase tags = parent item
          final lowercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'a')
              .toList();
          final lowercaseETags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'e')
              .toList();
          final lowercaseKTags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'k')
              .toList();
          final lowercasePTags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'p')
              .toList();

          // Root scope tags - A and E tags for queryability
          expect(uppercaseATags.length, equals(1));
          expect(uppercaseATags.first[1], equals(testAddressableId));
          expect(uppercaseETags.length, equals(1));
          expect(uppercaseETags.first[1], equals(testRootEventId));
          expect(uppercaseETags.first[3], equals(testRootAuthorPubkey));
          expect(uppercaseKTags.length, equals(1));
          expect(
            uppercaseKTags.first[1],
            equals(_testRootEventKind.toString()),
          );
          expect(uppercasePTags.length, equals(1));
          expect(uppercasePTags.first[1], equals(testRootAuthorPubkey));

          // Parent item tags (for top-level comment on addressable event)
          // Per NIP-22: include both 'a' and 'e' tags
          expect(lowercaseATags.length, equals(1));
          expect(lowercaseATags.first[1], equals(testAddressableId));
          expect(lowercaseETags.length, equals(1));
          expect(lowercaseETags.first[1], equals(testRootEventId));
          expect(lowercaseKTags.length, equals(1));
          expect(
            lowercaseKTags.first[1],
            equals(_testRootEventKind.toString()),
          );
          expect(lowercasePTags.length, equals(1));
          expect(lowercasePTags.first[1], equals(testRootAuthorPubkey));
        },
      );

      test('posts reply with correct NIP-22 tags', () async {
        Event? capturedEvent;
        const parentCommentId =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        const parentAuthorPubkey =
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          return capturedEvent = inv.positionalArguments.first as Event;
        });

        await repository.postComment(
          content: 'Reply comment',
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
          rootAddressableId: testAddressableId,
          replyToEventId: parentCommentId,
          replyToAuthorPubkey: parentAuthorPubkey,
        );

        expect(capturedEvent, isNotNull);

        // Check NIP-22 tags
        final uppercaseATags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'A')
            .toList();
        final uppercaseETags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'E')
            .toList();
        final uppercaseKTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'K')
            .toList();
        final uppercasePTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'P')
            .toList();

        // Lowercase tags = parent item (for reply, parent comment)
        final lowercaseETags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'e')
            .toList();
        final lowercaseKTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'k')
            .toList();
        final lowercasePTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'p')
            .toList();

        // Root scope tags (uppercase) - A and E tags
        expect(uppercaseATags.length, equals(1));
        expect(uppercaseATags.first[1], equals(testAddressableId));
        expect(uppercaseETags.length, equals(1));
        expect(uppercaseETags.first[1], equals(testRootEventId));
        expect(uppercaseETags.first[3], equals(testRootAuthorPubkey));
        expect(uppercaseKTags.length, equals(1));
        expect(uppercaseKTags.first[1], equals(_testRootEventKind.toString()));
        expect(uppercasePTags.length, equals(1));
        expect(uppercasePTags.first[1], equals(testRootAuthorPubkey));

        // Parent item tags (lowercase) - point to parent comment
        expect(lowercaseETags.length, equals(1));
        expect(lowercaseETags.first[1], equals(parentCommentId));
        expect(lowercaseKTags.length, equals(1));
        expect(lowercaseKTags.first[1], equals(_commentKind.toString()));
        expect(lowercasePTags.length, equals(1));
        expect(lowercasePTags.first[1], equals(parentAuthorPubkey));
      });

      test('returns created Comment', () async {
        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          return inv.positionalArguments.first as Event
            ..id = 'created_event_id';
        });

        final result = await repository.postComment(
          content: 'Test comment',
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
        );

        expect(result.content, equals('Test comment'));
        expect(result.rootEventId, equals(testRootEventId));
        expect(result.rootAuthorPubkey, equals(testRootAuthorPubkey));
        expect(result.authorPubkey, equals(testUserPubkey));
      });

      test('throws InvalidCommentContentException for empty content', () async {
        expect(
          () => repository.postComment(
            content: '',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
          ),
          throwsA(isA<InvalidCommentContentException>()),
        );
      });

      test(
        'throws InvalidCommentContentException for whitespace-only content',
        () async {
          expect(
            () => repository.postComment(
              content: '   ',
              rootEventId: testRootEventId,
              rootEventKind: _testRootEventKind,
              rootEventAuthorPubkey: testRootAuthorPubkey,
            ),
            throwsA(isA<InvalidCommentContentException>()),
          );
        },
      );

      test('trims content before posting', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          return capturedEvent = inv.positionalArguments.first as Event;
        });

        await repository.postComment(
          content: '  Trimmed content  ',
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
        );

        expect(capturedEvent!.content, equals('Trimmed content'));
      });

      test('throws PostCommentFailedException when publish fails', () async {
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => null);

        expect(
          () => repository.postComment(
            content: 'Test comment',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
          ),
          throwsA(isA<PostCommentFailedException>()),
        );
      });

      test('throws PostCommentFailedException on exception', () async {
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.postComment(
            content: 'Test comment',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
          ),
          throwsA(isA<PostCommentFailedException>()),
        );
      });
    });

    group('getCommentsCount', () {
      test('returns count of unique events from dual-query', () async {
        // Mock queryEvents to return some comment events
        final mockEvents = List.generate(
          5,
          (i) => Event(
            testUserPubkey,
            _commentKind,
            [
              ['A', testAddressableId, ''],
              ['K', _testRootEventKind.toString()],
            ],
            'Comment $i',
          ),
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => mockEvents,
        );

        final result = await repository.getCommentsCount(
          testAddressableId,
          rootEventId: testRootEventId,
        );

        expect(result, equals(5));
      });

      test('queries by both A-tag and E-tag for compatibility', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        await repository.getCommentsCount(
          testAddressableId,
          rootEventId: testRootEventId,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.length, equals(2));

        // First filter should be A-tag
        expect(filters[0].kinds, contains(_commentKind));
        expect(filters[0].uppercaseA, contains(testAddressableId));

        // Second filter should be E-tag
        expect(filters[1].kinds, contains(_commentKind));
        expect(filters[1].uppercaseE, contains(testRootEventId));
      });

      test('throws CountCommentsFailedException on error', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Query failed'));

        expect(
          () => repository.getCommentsCount(
            testAddressableId,
            rootEventId: testRootEventId,
          ),
          throwsA(isA<CountCommentsFailedException>()),
        );
      });
    });

    group('deleteComment', () {
      const testCommentId =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

      test('publishes deletion event with correct tags', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          return capturedEvent = inv.positionalArguments.first as Event;
        });

        await repository.deleteComment(commentId: testCommentId);

        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.kind, equals(_deletionKind));

        // Check NIP-09 deletion tags
        final eTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'e')
            .toList();
        final kTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'k')
            .toList();

        expect(eTags.length, equals(1));
        expect(eTags.first[1], equals(testCommentId));
        expect(kTags.length, equals(1));
        expect(kTags.first[1], equals(_commentKind.toString()));
      });

      test('publishes deletion event with reason when provided', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          return capturedEvent = inv.positionalArguments.first as Event;
        });

        await repository.deleteComment(
          commentId: testCommentId,
          reason: 'Spam content',
        );

        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.content, equals('Spam content'));
      });

      test(
        'publishes deletion event with empty content when no reason',
        () async {
          Event? capturedEvent;

          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            inv,
          ) async {
            return capturedEvent = inv.positionalArguments.first as Event;
          });

          await repository.deleteComment(commentId: testCommentId);

          expect(capturedEvent, isNotNull);
          expect(capturedEvent!.content, isEmpty);
        },
      );

      test(
        'throws DeleteCommentFailedException when publish returns null',
        () async {
          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => null);

          expect(
            () => repository.deleteComment(commentId: testCommentId),
            throwsA(isA<DeleteCommentFailedException>()),
          );
        },
      );

      test('throws DeleteCommentFailedException on exception', () async {
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.deleteComment(commentId: testCommentId),
          throwsA(isA<DeleteCommentFailedException>()),
        );
      });

      test('rethrows DeleteCommentFailedException', () async {
        when(() => mockNostrClient.publishEvent(any())).thenThrow(
          const DeleteCommentFailedException('Custom error'),
        );

        expect(
          () => repository.deleteComment(commentId: testCommentId),
          throwsA(
            isA<DeleteCommentFailedException>().having(
              (e) => e.message,
              'message',
              'Custom error',
            ),
          ),
        );
      });
    });
  });
}

/// Helper to create a NIP-22 comment event for testing.
///
/// Per NIP-22, for addressable events (kind 30000-39999):
/// - Uppercase `A` and `E` tags are used for root scope
/// - Lowercase `a` and `e` tags are used for parent item
Event _createCommentEvent({
  required String id,
  required String content,
  required String pubkey,
  required String rootEventId,
  required String rootAuthorPubkey,
  required int rootEventKind,
  String? rootAddressableId,
  String? replyToEventId,
  String? replyToAuthorPubkey,
  int createdAt = 1000,
}) {
  // NIP-22 tags:
  // Uppercase tags (A, E, K, P) = root scope
  // Lowercase tags (a, e, k, p) = parent item
  final tags = <List<String>>[
    // Root scope tags (uppercase)
    if (rootAddressableId != null) ['A', rootAddressableId, ''],
    ['E', rootEventId, '', rootAuthorPubkey],
    ['K', rootEventKind.toString()],
    ['P', rootAuthorPubkey],
    // Parent item tags (lowercase)
    if (replyToEventId != null && replyToAuthorPubkey != null) ...[
      // Replying to another comment
      ['e', replyToEventId, '', replyToAuthorPubkey],
      ['k', _commentKind.toString()],
      ['p', replyToAuthorPubkey],
    ] else ...[
      // Top-level comment - parent is the same as root
      if (rootAddressableId != null) ['a', rootAddressableId, ''],
      ['e', rootEventId, ''],
      ['k', rootEventKind.toString()],
      ['p', rootAuthorPubkey],
    ],
  ];

  return Event(pubkey, _commentKind, tags, content, createdAt: createdAt)
    ..id = id;
}
