// ABOUTME: Repository for managing curated video list subscriptions and
// ABOUTME: discovery. Provides BehaviorSubject stream for reactive BLoC
// ABOUTME: subscription, read-only query methods, and relay-based discovery
// ABOUTME: streaming for public NIP-51 kind 30005 lists.

import 'package:curated_list_repository/src/curated_list_converter.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Filter;
import 'package:rxdart/rxdart.dart';

/// Well-known d-tag for the user's default "My List".
const defaultListId = 'my_vine_list';

/// {@template curated_list_repository}
/// Repository for managing curated video list subscriptions and discovery.
///
/// Exposes a [subscribedListsStream] (BehaviorSubject) so that BLoCs can
/// reactively observe list changes, and provides read-only query methods
/// for lookups on subscribed lists.
///
/// When constructed with a [NostrClient], also provides discovery methods
/// for streaming public curated lists from Nostr relays.
/// {@endtemplate}
class CuratedListRepository {
  /// {@macro curated_list_repository}
  ///
  /// The optional [nostrClient] enables relay-based discovery methods
  /// ([streamPublicLists], [streamListsContainingVideo], [fetchPublicLists]).
  /// When `null`, only subscribed-list queries are available.
  CuratedListRepository({NostrClient? nostrClient})
    : _nostrClient = nostrClient;

  final NostrClient? _nostrClient;
  final Map<String, CuratedList> _subscribedLists = {};

  // BehaviorSubject replays last value to late subscribers, fixing race
  // condition where BLoC subscribes AFTER initial emission.
  final _subscribedListsSubject = BehaviorSubject<List<CuratedList>>.seeded(
    const [],
  );

  /// A stream of subscribed curated lists.
  ///
  /// Replays the last emitted value to new subscribers (BehaviorSubject).
  Stream<List<CuratedList>> get subscribedListsStream =>
      _subscribedListsSubject.stream;

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  /// Replaces the current subscribed lists with [lists].
  ///
  /// This is a **transitional bridge** that lets the Page layer push data
  /// from the legacy Riverpod `CuratedListService` into the repository so
  /// BLoCs can consume it via [subscribedListsStream].
  ///
  /// Each list is keyed by its [CuratedList.id].
  ///
  /// Emits the new list on [subscribedListsStream].
  // TODO(curated-list-migration): Remove once the repository owns its own
  // data loading (Phase 2 — persistence + relay sync). At that point,
  // internal CRUD methods and relay fetch will emit on the stream directly.
  void setSubscribedLists(List<CuratedList> lists) {
    _subscribedLists
      ..clear()
      ..addEntries(lists.map((list) => MapEntry(list.id, list)));
    _emitSubscribedLists();
  }

  // ---------------------------------------------------------------------------
  // Read-only queries
  // ---------------------------------------------------------------------------

  /// Returns video references from all subscribed lists, keyed by list ID.
  ///
  /// Each value is the list's [CuratedList.videoEventIds], which contains
  /// a mix of:
  /// - **Event IDs**: 64-character hex strings
  /// - **Addressable coordinates**: `kind:pubkey:d-tag` format
  ///
  /// Lists with empty [CuratedList.videoEventIds] are excluded.
  ///
  /// Returns an empty map when there are no subscribed lists.
  Map<String, List<String>> getSubscribedListVideoRefs() {
    final refs = <String, List<String>>{};
    for (final entry in _subscribedLists.entries) {
      if (entry.value.videoEventIds.isNotEmpty) {
        refs[entry.key] = List.unmodifiable(entry.value.videoEventIds);
      }
    }
    return Map.unmodifiable(refs);
  }

  /// Returns the subscribed list with the given [id], or `null` if not found.
  CuratedList? getListById(String id) => _subscribedLists[id];

  /// Returns an unmodifiable snapshot of all subscribed lists.
  List<CuratedList> getSubscribedLists() =>
      List.unmodifiable(_subscribedLists.values.toList());

  /// Whether the user is subscribed to the list with [listId].
  bool isSubscribedToList(String listId) =>
      _subscribedLists.containsKey(listId);

  /// Whether [videoEventId] is in the subscribed list with [listId].
  ///
  /// Returns `false` if the list does not exist.
  bool isVideoInList(String listId, String videoEventId) {
    final list = _subscribedLists[listId];
    return list?.videoEventIds.contains(videoEventId) ?? false;
  }

  /// Whether the user's default "My List" is among the subscribed lists.
  bool hasDefaultList() => _subscribedLists.containsKey(defaultListId);

  /// Returns the user's default "My List", or `null` if not subscribed.
  CuratedList? getDefaultList() => _subscribedLists[defaultListId];

  /// Searches subscribed public lists by [query] against name, description,
  /// and tags (case-insensitive).
  ///
  /// Returns an empty list when [query] is blank.
  List<CuratedList> searchLists(String query) {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    return _subscribedLists.values
        .where(
          (list) =>
              list.isPublic &&
              (list.name.toLowerCase().contains(lowerQuery) ||
                  (list.description?.toLowerCase().contains(lowerQuery) ??
                      false) ||
                  list.tags.any(
                    (tag) => tag.toLowerCase().contains(lowerQuery),
                  )),
        )
        .toList();
  }

  /// Returns subscribed public lists that contain the given [tag].
  List<CuratedList> getListsByTag(String tag) {
    return _subscribedLists.values
        .where(
          (list) => list.isPublic && list.tags.contains(tag.toLowerCase()),
        )
        .toList();
  }

  /// Returns all unique tags across subscribed public lists, sorted
  /// alphabetically.
  List<String> getAllTags() {
    final allTags = <String>{};
    for (final list in _subscribedLists.values) {
      if (list.isPublic) {
        allTags.addAll(list.tags);
      }
    }
    return allTags.toList()..sort();
  }

  /// Returns all subscribed lists that contain [videoEventId].
  List<CuratedList> getListsContainingVideo(String videoEventId) {
    return _subscribedLists.values
        .where((list) => list.videoEventIds.contains(videoEventId))
        .toList();
  }

  /// Returns video IDs from the list with [listId], ordered according to the
  /// list's [PlayOrder].
  ///
  /// Returns an empty list if the list does not exist.
  List<String> getOrderedVideoIds(String listId) {
    final list = _subscribedLists[listId];
    if (list == null) return [];

    return switch (list.playOrder) {
      PlayOrder.chronological => List.of(list.videoEventIds),
      PlayOrder.reverse => list.videoEventIds.reversed.toList(),
      PlayOrder.manual => List.of(list.videoEventIds),
      PlayOrder.shuffle => (List.of(list.videoEventIds)..shuffle()),
    };
  }

  /// Returns a human-readable summary of which subscribed lists contain
  /// [videoEventId].
  String getVideoListSummary(String videoEventId) {
    final listsContaining = getListsContainingVideo(videoEventId);

    if (listsContaining.isEmpty) {
      return 'Not in any lists';
    }

    if (listsContaining.length == 1) {
      return 'In "${listsContaining.first.name}"';
    }

    if (listsContaining.length <= 3) {
      final names = listsContaining.map((list) => '"${list.name}"').join(', ');
      return 'In $names';
    }

    return 'In ${listsContaining.length} lists';
  }

  // ---------------------------------------------------------------------------
  // Discovery (relay-based)
  // ---------------------------------------------------------------------------

  /// Streams public curated lists from Nostr relays for discovery.
  ///
  /// Yields an accumulated, deduplicated list each time a new valid list
  /// arrives. Lists are sorted by video count (most videos first).
  ///
  /// Deduplicates by d-tag, keeping the newest version of each list.
  /// Skips lists with no videos and lists in [excludeIds].
  ///
  /// Requires a [NostrClient] to be provided at construction time.
  ///
  /// Throws [StateError] if no [NostrClient] was provided.
  Stream<List<CuratedList>> streamPublicLists({
    DateTime? until,
    int limit = 500,
    Set<String>? excludeIds,
  }) async* {
    _requireNostrClient();

    final listsByDTag = <String, CuratedList>{};
    final skipIds = excludeIds ?? <String>{};

    final filter = Filter(
      kinds: [30005],
      until: until != null ? until.millisecondsSinceEpoch ~/ 1000 : null,
      limit: limit,
    );

    final subscription = _nostrClient!.subscribe([filter]);

    await for (final event in subscription) {
      final list = CuratedListConverter.fromEvent(event);
      if (list == null || list.videoEventIds.isEmpty) continue;
      if (skipIds.contains(list.id)) continue;

      final existing = listsByDTag[list.id];
      if (existing == null || list.updatedAt.isAfter(existing.updatedAt)) {
        listsByDTag[list.id] = list;

        final sorted = listsByDTag.values.toList()
          ..sort(
            (a, b) => b.videoEventIds.length.compareTo(a.videoEventIds.length),
          );
        yield sorted;
      }
    }
  }

  /// Streams public curated lists that contain [videoEventId].
  ///
  /// Uses Nostr `#e` filter to find kind 30005 events referencing the video.
  /// Emits individual [CuratedList] objects as they arrive from relays.
  ///
  /// Deduplicates by d-tag, skipping older versions of the same list.
  ///
  /// Requires a [NostrClient] to be provided at construction time.
  ///
  /// Throws [StateError] if no [NostrClient] was provided.
  Stream<CuratedList> streamListsContainingVideo(String videoEventId) {
    _requireNostrClient();

    final seenDTags = <String, int>{};

    final filter = Filter(
      kinds: [30005],
      e: [videoEventId],
      limit: 50,
    );

    return _nostrClient!
        .subscribe([filter])
        .map((event) {
          final dTag = CuratedListConverter.extractDTag(event);
          if (dTag == null) return null;

          final existingTime = seenDTags[dTag];
          if (existingTime != null && existingTime >= event.createdAt) {
            return null;
          }
          seenDTags[dTag] = event.createdAt;

          return CuratedListConverter.fromEvent(event);
        })
        .where((list) => list != null)
        .cast<CuratedList>();
  }

  /// Fetches public curated lists from relays with a timeout.
  ///
  /// Delegates to [streamPublicLists] and returns the last accumulated
  /// snapshot before [timeout] expires.
  ///
  /// Returns an empty list if no events arrive within the timeout.
  ///
  /// Requires a [NostrClient] to be provided at construction time.
  ///
  /// Throws [StateError] if no [NostrClient] was provided.
  Future<List<CuratedList>> fetchPublicLists({
    DateTime? until,
    int limit = 500,
    Set<String>? excludeIds,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    var latest = <CuratedList>[];

    await for (final update in streamPublicLists(
      until: until,
      limit: limit,
      excludeIds: excludeIds,
    ).timeout(timeout, onTimeout: (sink) => sink.close())) {
      latest = update;
    }

    return latest;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Releases resources held by this repository.
  ///
  /// Idempotent — safe to call multiple times.
  Future<void> dispose() async {
    if (!_subscribedListsSubject.isClosed) {
      await _subscribedListsSubject.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _emitSubscribedLists() {
    if (!_subscribedListsSubject.isClosed) {
      _subscribedListsSubject.add(
        List.unmodifiable(_subscribedLists.values.toList()),
      );
    }
  }

  void _requireNostrClient() {
    if (_nostrClient == null) {
      throw StateError(
        'NostrClient is required for discovery methods. '
        'Pass a NostrClient to the CuratedListRepository constructor.',
      );
    }
  }
}
