import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, Filter;
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeFilter extends Fake implements Filter {}

void main() {
  setUpAll(() {
    registerFallbackValue(<_FakeFilter>[]);
  });

  group(CuratedListRepository, () {
    late CuratedListRepository repository;

    final now = DateTime(2025, 6, 15);

    CuratedList createList({
      required String id,
      String name = 'Test List',
      List<String> videoEventIds = const [],
      String? description,
      bool isPublic = true,
      List<String> tags = const [],
      PlayOrder playOrder = PlayOrder.chronological,
    }) {
      return CuratedList(
        id: id,
        name: name,
        videoEventIds: videoEventIds,
        createdAt: now,
        updatedAt: now,
        description: description,
        isPublic: isPublic,
        tags: tags,
        playOrder: playOrder,
      );
    }

    setUp(() {
      repository = CuratedListRepository();
    });

    tearDown(() async {
      await repository.dispose();
    });

    test('can be instantiated', () {
      expect(CuratedListRepository(), isNotNull);
    });

    group('subscribedListsStream', () {
      test('emits initial empty list', () async {
        await expectLater(
          repository.subscribedListsStream,
          emits(isEmpty),
        );
      });

      test('emits after setSubscribedLists', () async {
        final list = createList(id: 'list-a', name: 'List A');

        repository.setSubscribedLists([list]);

        await expectLater(
          repository.subscribedListsStream,
          emits(equals([list])),
        );
      });

      test('replays last value to new subscribers', () async {
        final list = createList(id: 'list-a');

        repository.setSubscribedLists([list]);

        // Subscribe after emission — BehaviorSubject replays.
        await expectLater(
          repository.subscribedListsStream,
          emits(equals([list])),
        );
      });

      test('emits unmodifiable list', () async {
        repository.setSubscribedLists([createList(id: 'list-a')]);

        final emitted = await repository.subscribedListsStream.first;

        expect(
          () => emitted.add(createList(id: 'hack')),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('dispose', () {
      test('closes stream', () async {
        await repository.dispose();

        await expectLater(
          repository.subscribedListsStream,
          emitsInOrder(<dynamic>[isEmpty, emitsDone]),
        );
      });

      test('is idempotent', () async {
        await repository.dispose();
        await repository.dispose();

        // No exception thrown.
      });

      test('setSubscribedLists after dispose does not throw', () async {
        await repository.dispose();

        // Should not throw even though stream is closed.
        expect(
          () => repository.setSubscribedLists([createList(id: 'x')]),
          returnsNormally,
        );
      });
    });

    group('getSubscribedListVideoRefs', () {
      test('returns empty map when no lists are set', () {
        expect(repository.getSubscribedListVideoRefs(), isEmpty);
      });

      test('returns video refs keyed by list ID', () {
        const eventId =
            'aabbccdd11223344aabbccdd11223344'
            'aabbccdd11223344aabbccdd11223344';
        const addressableCoord = '34236:pubkey123:my-vine';

        repository.setSubscribedLists([
          createList(
            id: 'list-a',
            videoEventIds: [eventId, addressableCoord],
          ),
          createList(
            id: 'list-b',
            videoEventIds: [addressableCoord],
          ),
        ]);

        final refs = repository.getSubscribedListVideoRefs();

        expect(refs, hasLength(2));
        expect(refs['list-a'], equals([eventId, addressableCoord]));
        expect(refs['list-b'], equals([addressableCoord]));
      });

      test('excludes lists with empty videoEventIds', () {
        repository.setSubscribedLists([
          createList(id: 'has-videos', videoEventIds: ['video-id']),
          createList(id: 'empty-list'),
        ]);

        final refs = repository.getSubscribedListVideoRefs();

        expect(refs, hasLength(1));
        expect(refs.containsKey('has-videos'), isTrue);
        expect(refs.containsKey('empty-list'), isFalse);
      });

      test('returns unmodifiable map', () {
        repository.setSubscribedLists([
          createList(id: 'list-a', videoEventIds: ['video-id']),
        ]);

        final refs = repository.getSubscribedListVideoRefs();

        expect(
          () => refs['new-key'] = [],
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('returns unmodifiable video ID lists', () {
        repository.setSubscribedLists([
          createList(id: 'list-a', videoEventIds: ['video-id']),
        ]);

        final refs = repository.getSubscribedListVideoRefs();

        expect(
          () => refs['list-a']!.add('injected'),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('getListById', () {
      test('returns null when no lists are set', () {
        expect(repository.getListById('nonexistent'), isNull);
      });

      test('returns null for unknown ID', () {
        repository.setSubscribedLists([
          createList(id: 'list-a'),
        ]);

        expect(repository.getListById('unknown'), isNull);
      });

      test('returns correct list by ID', () {
        final listA = createList(id: 'list-a', name: 'List A');
        final listB = createList(id: 'list-b', name: 'List B');
        repository.setSubscribedLists([listA, listB]);

        expect(repository.getListById('list-a'), equals(listA));
        expect(repository.getListById('list-b'), equals(listB));
      });
    });

    group('setSubscribedLists', () {
      test('replaces previous data', () {
        repository
          ..setSubscribedLists([
            createList(id: 'old-list', videoEventIds: ['old-video']),
          ])
          ..setSubscribedLists([
            createList(id: 'new-list', videoEventIds: ['new-video']),
          ]);

        expect(repository.getListById('old-list'), isNull);
        expect(repository.getListById('new-list'), isNotNull);

        final refs = repository.getSubscribedListVideoRefs();
        expect(refs, hasLength(1));
        expect(refs.containsKey('new-list'), isTrue);
      });

      test('clears all data when set with empty list', () {
        repository
          ..setSubscribedLists([
            createList(id: 'list-a', videoEventIds: ['video']),
          ])
          ..setSubscribedLists([]);

        expect(repository.getSubscribedListVideoRefs(), isEmpty);
        expect(repository.getListById('list-a'), isNull);
      });

      test('handles duplicate IDs by keeping the last one', () {
        repository.setSubscribedLists([
          createList(id: 'same-id', name: 'First'),
          createList(id: 'same-id', name: 'Second'),
        ]);

        expect(repository.getListById('same-id')?.name, equals('Second'));
      });
    });

    group('getSubscribedLists', () {
      test('returns empty list initially', () {
        expect(repository.getSubscribedLists(), isEmpty);
      });

      test('returns all subscribed lists', () {
        final listA = createList(id: 'a');
        final listB = createList(id: 'b');
        repository.setSubscribedLists([listA, listB]);

        expect(repository.getSubscribedLists(), hasLength(2));
        expect(repository.getSubscribedLists(), contains(listA));
        expect(repository.getSubscribedLists(), contains(listB));
      });

      test('returns unmodifiable list', () {
        repository.setSubscribedLists([createList(id: 'a')]);

        expect(
          () => repository.getSubscribedLists().add(createList(id: 'hack')),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('isSubscribedToList', () {
      test('returns false for unknown list', () {
        expect(repository.isSubscribedToList('unknown'), isFalse);
      });

      test('returns true for subscribed list', () {
        repository.setSubscribedLists([createList(id: 'list-a')]);

        expect(repository.isSubscribedToList('list-a'), isTrue);
      });
    });

    group('isVideoInList', () {
      test('returns false for unknown list', () {
        expect(repository.isVideoInList('unknown', 'video-1'), isFalse);
      });

      test('returns false when video is not in list', () {
        repository.setSubscribedLists([
          createList(id: 'list-a', videoEventIds: ['video-1']),
        ]);

        expect(repository.isVideoInList('list-a', 'video-2'), isFalse);
      });

      test('returns true when video is in list', () {
        repository.setSubscribedLists([
          createList(id: 'list-a', videoEventIds: ['video-1', 'video-2']),
        ]);

        expect(repository.isVideoInList('list-a', 'video-2'), isTrue);
      });
    });

    group('hasDefaultList', () {
      test('returns false when no default list exists', () {
        repository.setSubscribedLists([createList(id: 'other')]);

        expect(repository.hasDefaultList(), isFalse);
      });

      test('returns true when default list exists', () {
        repository.setSubscribedLists([
          createList(id: defaultListId),
        ]);

        expect(repository.hasDefaultList(), isTrue);
      });
    });

    group('getDefaultList', () {
      test('returns null when no default list exists', () {
        expect(repository.getDefaultList(), isNull);
      });

      test('returns the default list', () {
        final myList = createList(id: defaultListId, name: 'My List');
        repository.setSubscribedLists([myList]);

        expect(repository.getDefaultList(), equals(myList));
      });
    });

    group('searchLists', () {
      test('returns empty for blank query', () {
        repository.setSubscribedLists([createList(id: 'a', name: 'Test')]);

        expect(repository.searchLists(''), isEmpty);
        expect(repository.searchLists('   '), isEmpty);
      });

      test('matches by name case-insensitively', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'Dance Moves'),
          createList(id: 'b', name: 'Cooking Tips'),
        ]);

        final results = repository.searchLists('dance');

        expect(results, hasLength(1));
        expect(results.first.id, equals('a'));
      });

      test('matches by description', () {
        repository.setSubscribedLists([
          createList(
            id: 'a',
            name: 'Collection',
            description: 'Amazing guitar solos',
          ),
        ]);

        final results = repository.searchLists('guitar');

        expect(results, hasLength(1));
      });

      test('matches by tags', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'Playlist', tags: ['music', 'jazz']),
        ]);

        final results = repository.searchLists('jazz');

        expect(results, hasLength(1));
      });

      test('excludes private lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'Secret Dance', isPublic: false),
          createList(id: 'b', name: 'Public Dance'),
        ]);

        final results = repository.searchLists('dance');

        expect(results, hasLength(1));
        expect(results.first.id, equals('b'));
      });
    });

    group('getListsByTag', () {
      test('returns matching public lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', tags: ['music', 'dance']),
          createList(id: 'b', tags: ['cooking']),
          createList(id: 'c', tags: ['music'], isPublic: false),
        ]);

        final results = repository.getListsByTag('music');

        expect(results, hasLength(1));
        expect(results.first.id, equals('a'));
      });

      test('returns empty when no match', () {
        repository.setSubscribedLists([
          createList(id: 'a', tags: ['cooking']),
        ]);

        expect(repository.getListsByTag('music'), isEmpty);
      });
    });

    group('getAllTags', () {
      test('returns empty when no lists', () {
        expect(repository.getAllTags(), isEmpty);
      });

      test('returns unique sorted tags from public lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', tags: ['music', 'dance']),
          createList(id: 'b', tags: ['dance', 'cooking']),
          createList(id: 'c', tags: ['secret'], isPublic: false),
        ]);

        expect(
          repository.getAllTags(),
          equals(['cooking', 'dance', 'music']),
        );
      });
    });

    group('getListsContainingVideo', () {
      test('returns empty when video is in no lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', videoEventIds: ['other-video']),
        ]);

        expect(repository.getListsContainingVideo('my-video'), isEmpty);
      });

      test('returns all lists containing the video', () {
        repository.setSubscribedLists([
          createList(id: 'a', videoEventIds: ['v1', 'v2']),
          createList(id: 'b', videoEventIds: ['v2', 'v3']),
          createList(id: 'c', videoEventIds: ['v3']),
        ]);

        final results = repository.getListsContainingVideo('v2');

        expect(results, hasLength(2));
        expect(results.map((l) => l.id), containsAll(['a', 'b']));
      });
    });

    group('getOrderedVideoIds', () {
      test('returns empty for unknown list', () {
        expect(repository.getOrderedVideoIds('unknown'), isEmpty);
      });

      test('returns chronological order', () {
        repository.setSubscribedLists([
          createList(
            id: 'list',
            videoEventIds: ['v1', 'v2', 'v3'],
          ),
        ]);

        expect(
          repository.getOrderedVideoIds('list'),
          equals(['v1', 'v2', 'v3']),
        );
      });

      test('returns reverse order', () {
        repository.setSubscribedLists([
          createList(
            id: 'list',
            videoEventIds: ['v1', 'v2', 'v3'],
            playOrder: PlayOrder.reverse,
          ),
        ]);

        expect(
          repository.getOrderedVideoIds('list'),
          equals(['v3', 'v2', 'v1']),
        );
      });

      test('returns manual order as-is', () {
        repository.setSubscribedLists([
          createList(
            id: 'list',
            videoEventIds: ['v3', 'v1', 'v2'],
            playOrder: PlayOrder.manual,
          ),
        ]);

        expect(
          repository.getOrderedVideoIds('list'),
          equals(['v3', 'v1', 'v2']),
        );
      });

      test('returns shuffled order with same elements', () {
        repository.setSubscribedLists([
          createList(
            id: 'list',
            videoEventIds: ['v1', 'v2', 'v3'],
            playOrder: PlayOrder.shuffle,
          ),
        ]);

        final ordered = repository.getOrderedVideoIds('list');

        // Contains the same elements (order may vary).
        expect(ordered, unorderedEquals(['v1', 'v2', 'v3']));
      });

      test('does not mutate original list', () {
        repository
          ..setSubscribedLists([
            createList(
              id: 'list',
              videoEventIds: ['v1', 'v2', 'v3'],
              playOrder: PlayOrder.reverse,
            ),
          ])
          ..getOrderedVideoIds('list');

        // Original list is unchanged.
        final list = repository.getListById('list')!;
        expect(list.videoEventIds, equals(['v1', 'v2', 'v3']));
      });
    });

    group('getVideoListSummary', () {
      test('returns "Not in any lists" when video is nowhere', () {
        expect(
          repository.getVideoListSummary('v1'),
          equals('Not in any lists'),
        );
      });

      test('returns single list name', () {
        repository.setSubscribedLists([
          createList(
            id: 'a',
            name: 'My Favorites',
            videoEventIds: ['v1'],
          ),
        ]);

        expect(
          repository.getVideoListSummary('v1'),
          equals('In "My Favorites"'),
        );
      });

      test('returns comma-separated names for 2-3 lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'Favs', videoEventIds: ['v1']),
          createList(id: 'b', name: 'Dance', videoEventIds: ['v1']),
        ]);

        expect(
          repository.getVideoListSummary('v1'),
          equals('In "Favs", "Dance"'),
        );
      });

      test('returns count for 4+ lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'A', videoEventIds: ['v1']),
          createList(id: 'b', name: 'B', videoEventIds: ['v1']),
          createList(id: 'c', name: 'C', videoEventIds: ['v1']),
          createList(id: 'd', name: 'D', videoEventIds: ['v1']),
        ]);

        expect(
          repository.getVideoListSummary('v1'),
          equals('In 4 lists'),
        );
      });
    });

    // -----------------------------------------------------------------------
    // Discovery (relay-based)
    // -----------------------------------------------------------------------

    group('streamPublicLists', () {
      late _MockNostrClient mockNostrClient;
      late StreamController<Event> eventController;
      late CuratedListRepository discoveryRepository;

      /// Creates a kind 30005 event with the given [dTag] and [eTags].
      Event createEvent({
        required String dTag,
        List<String> eTags = const [],
        int createdAt = 1000,
        String pubkey = 'pub1',
        String? title,
      }) {
        return Event(
          pubkey,
          30005,
          [
            ['d', dTag],
            if (title != null) ['title', title],
            ...eTags.map((e) => ['e', e]),
          ],
          '',
          createdAt: createdAt,
        );
      }

      setUp(() {
        mockNostrClient = _MockNostrClient();
        eventController = StreamController<Event>();

        when(
          () => mockNostrClient.subscribe(any<List<Filter>>()),
        ).thenAnswer((_) => eventController.stream);

        discoveryRepository = CuratedListRepository(
          nostrClient: mockNostrClient,
        );
      });

      tearDown(() async {
        await eventController.close();
        await discoveryRepository.dispose();
      });

      test('throws StateError when no NostrClient is provided', () {
        final repo = CuratedListRepository();

        expect(
          repo.streamPublicLists,
          throwsA(isA<StateError>()),
        );
      });

      test('yields accumulated lists sorted by video count', () async {
        final stream = discoveryRepository.streamPublicLists();

        // List with 1 video
        eventController
          ..add(createEvent(dTag: 'list-a', eTags: ['v1']))
          // List with 3 videos — should sort first
          ..add(
            createEvent(dTag: 'list-b', eTags: ['v1', 'v2', 'v3']),
          );

        final emissions = <List<CuratedList>>[];
        final subscription = stream.listen(emissions.add);

        // Wait for events to process
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(emissions, hasLength(2));

        // First emission: just list-a
        expect(emissions[0], hasLength(1));
        expect(emissions[0].first.id, equals('list-a'));

        // Second emission: list-b first (3 videos > 1 video)
        expect(emissions[1], hasLength(2));
        expect(emissions[1].first.id, equals('list-b'));
        expect(emissions[1].last.id, equals('list-a'));

        await subscription.cancel();
      });

      test('deduplicates by d-tag, keeping newest', () async {
        final stream = discoveryRepository.streamPublicLists();

        eventController
          // Older version with 1 video
          ..add(
            createEvent(
              dTag: 'list-a',
              eTags: ['v1'],
              title: 'Old',
            ),
          )
          // Newer version with 2 videos
          ..add(
            createEvent(
              dTag: 'list-a',
              eTags: ['v1', 'v2'],
              createdAt: 2000,
              title: 'New',
            ),
          );

        final emissions = <List<CuratedList>>[];
        final subscription = stream.listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(emissions, hasLength(2));

        // Second emission should have the updated list
        expect(emissions[1], hasLength(1));
        expect(emissions[1].first.name, equals('New'));
        expect(emissions[1].first.videoEventIds, hasLength(2));

        await subscription.cancel();
      });

      test('does not replace newer with older version', () async {
        final stream = discoveryRepository.streamPublicLists();

        eventController
          // Newer version first
          ..add(
            createEvent(
              dTag: 'list-a',
              eTags: ['v1', 'v2'],
              createdAt: 2000,
              title: 'Newer',
            ),
          )
          // Older version arrives later (common with multiple relays)
          ..add(
            createEvent(
              dTag: 'list-a',
              eTags: ['v1'],
              title: 'Older',
            ),
          );

        final emissions = <List<CuratedList>>[];
        final subscription = stream.listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Only one emission — the older event should be ignored
        expect(emissions, hasLength(1));
        expect(emissions.first.first.name, equals('Newer'));

        await subscription.cancel();
      });

      test('skips lists in excludeIds', () async {
        final stream = discoveryRepository.streamPublicLists(
          excludeIds: {'list-a'},
        );

        eventController
          ..add(createEvent(dTag: 'list-a', eTags: ['v1']))
          ..add(createEvent(dTag: 'list-b', eTags: ['v2']));

        final emissions = <List<CuratedList>>[];
        final subscription = stream.listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Only list-b should appear
        expect(emissions, hasLength(1));
        expect(emissions.first, hasLength(1));
        expect(emissions.first.first.id, equals('list-b'));

        await subscription.cancel();
      });

      test('skips lists with no videos', () async {
        final stream = discoveryRepository.streamPublicLists();

        // Empty list (no e-tags)
        eventController
          ..add(createEvent(dTag: 'empty-list'))
          // List with videos
          ..add(createEvent(dTag: 'has-videos', eTags: ['v1']));

        final emissions = <List<CuratedList>>[];
        final subscription = stream.listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(emissions, hasLength(1));
        expect(emissions.first.first.id, equals('has-videos'));

        await subscription.cancel();
      });

      test('skips events that converter returns null for', () async {
        final stream = discoveryRepository.streamPublicLists();

        // Event without d-tag — converter returns null
        eventController
          ..add(
            Event('pub1', 30005, [
              ['e', 'v1'],
            ], ''),
          )
          // Valid event
          ..add(createEvent(dTag: 'valid', eTags: ['v1']));

        final emissions = <List<CuratedList>>[];
        final subscription = stream.listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(emissions, hasLength(1));
        expect(emissions.first.first.id, equals('valid'));

        await subscription.cancel();
      });
    });

    group('streamListsContainingVideo', () {
      late _MockNostrClient mockNostrClient;
      late StreamController<Event> eventController;
      late CuratedListRepository discoveryRepository;

      Event createEvent({
        required String dTag,
        List<String> eTags = const [],
        int createdAt = 1000,
        String pubkey = 'pub1',
      }) {
        return Event(
          pubkey,
          30005,
          [
            ['d', dTag],
            ...eTags.map((e) => ['e', e]),
          ],
          '',
          createdAt: createdAt,
        );
      }

      setUp(() {
        mockNostrClient = _MockNostrClient();
        eventController = StreamController<Event>();

        when(
          () => mockNostrClient.subscribe(any<List<Filter>>()),
        ).thenAnswer((_) => eventController.stream);

        discoveryRepository = CuratedListRepository(
          nostrClient: mockNostrClient,
        );
      });

      tearDown(() async {
        await eventController.close();
        await discoveryRepository.dispose();
      });

      test('throws StateError when no NostrClient is provided', () {
        final repo = CuratedListRepository();

        expect(
          () => repo.streamListsContainingVideo('video-id'),
          throwsA(isA<StateError>()),
        );
      });

      test('emits individual lists as they arrive', () async {
        final stream = discoveryRepository.streamListsContainingVideo(
          'target-video',
        );

        eventController
          ..add(createEvent(dTag: 'list-a', eTags: ['target-video']))
          ..add(createEvent(dTag: 'list-b', eTags: ['target-video']));

        final emissions = <CuratedList>[];
        final subscription = stream.listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(emissions, hasLength(2));
        expect(emissions[0].id, equals('list-a'));
        expect(emissions[1].id, equals('list-b'));

        await subscription.cancel();
      });

      test('deduplicates by d-tag, skipping older versions', () async {
        final stream = discoveryRepository.streamListsContainingVideo(
          'target-video',
        );

        eventController
          // Newer version first
          ..add(
            createEvent(
              dTag: 'list-a',
              eTags: ['target-video'],
              createdAt: 2000,
            ),
          )
          // Older duplicate
          ..add(
            createEvent(
              dTag: 'list-a',
              eTags: ['target-video'],
            ),
          );

        final emissions = <CuratedList>[];
        final subscription = stream.listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Only the first (newer) should be emitted
        expect(emissions, hasLength(1));
        expect(emissions.first.id, equals('list-a'));

        await subscription.cancel();
      });

      test('emits newer version when it arrives after older', () async {
        final stream = discoveryRepository.streamListsContainingVideo(
          'target-video',
        );

        eventController
          // Older version first
          ..add(
            createEvent(
              dTag: 'list-a',
              eTags: ['target-video'],
            ),
          )
          // Newer version later
          ..add(
            createEvent(
              dTag: 'list-a',
              eTags: ['target-video'],
              createdAt: 2000,
            ),
          );

        final emissions = <CuratedList>[];
        final subscription = stream.listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Both should be emitted (newer replaces older in seen map)
        expect(emissions, hasLength(2));

        await subscription.cancel();
      });

      test('skips events with no d-tag', () async {
        final stream = discoveryRepository.streamListsContainingVideo(
          'target-video',
        );

        eventController
          // No d-tag
          ..add(
            Event('pub1', 30005, [
              ['e', 'target-video'],
            ], ''),
          )
          // Valid event
          ..add(
            createEvent(dTag: 'valid', eTags: ['target-video']),
          );

        final emissions = <CuratedList>[];
        final subscription = stream.listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(emissions, hasLength(1));
        expect(emissions.first.id, equals('valid'));

        await subscription.cancel();
      });
    });

    group('fetchPublicLists', () {
      late _MockNostrClient mockNostrClient;
      late StreamController<Event> eventController;
      late CuratedListRepository discoveryRepository;

      Event createEvent({
        required String dTag,
        List<String> eTags = const [],
        int createdAt = 1000,
      }) {
        return Event(
          'pub1',
          30005,
          [
            ['d', dTag],
            ...eTags.map((e) => ['e', e]),
          ],
          '',
          createdAt: createdAt,
        );
      }

      setUp(() {
        mockNostrClient = _MockNostrClient();
        eventController = StreamController<Event>();

        when(
          () => mockNostrClient.subscribe(any<List<Filter>>()),
        ).thenAnswer((_) => eventController.stream);

        discoveryRepository = CuratedListRepository(
          nostrClient: mockNostrClient,
        );
      });

      tearDown(() async {
        await eventController.close();
        await discoveryRepository.dispose();
      });

      test('throws StateError when no NostrClient is provided', () async {
        final repo = CuratedListRepository();

        expect(
          repo.fetchPublicLists,
          throwsA(isA<StateError>()),
        );
      });

      test('returns last accumulated snapshot before timeout', () async {
        // Emit events quickly, then let the timeout close the stream
        eventController
          ..add(createEvent(dTag: 'a', eTags: ['v1']))
          ..add(createEvent(dTag: 'b', eTags: ['v1', 'v2']));

        final result = await discoveryRepository.fetchPublicLists(
          timeout: const Duration(milliseconds: 100),
        );

        // Should have both lists, sorted by video count
        expect(result, hasLength(2));
        expect(result.first.id, equals('b'));
        expect(result.last.id, equals('a'));
      });

      test('returns empty list when no events arrive', () async {
        final result = await discoveryRepository.fetchPublicLists(
          timeout: const Duration(milliseconds: 50),
        );

        expect(result, isEmpty);
      });
    });
  });
}
