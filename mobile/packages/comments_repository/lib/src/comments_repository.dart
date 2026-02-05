// ABOUTME: Repository for managing comments (Kind 1111 NIP-22) on Nostr.
// ABOUTME: Provides loading, posting, and streaming of threaded comments.
// ABOUTME: Uses NostrClient for relay operations and organizes comments
// chronologically.

import 'dart:developer' as developer;

import 'package:comments_repository/src/exceptions.dart';
import 'package:comments_repository/src/models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Kind 1111 is the NIP-22 comment kind for replying to non-Kind-1 events.
const int _commentKind = EventKind.comment;

/// Kind 5 is the NIP-09 deletion request kind.
const int _deletionKind = EventKind.eventDeletion;

/// Default limit for comment queries.
const _defaultLimit = 100;

/// Repository for managing comments (Kind 1111 NIP-22) on Nostr events.
///
/// This repository provides a unified interface for:
/// - Loading comments with thread structure
/// - Watching real-time comment streams
/// - Posting new comments and replies
/// - Counting comments on events
///
/// Comments use NIP-22 threading with uppercase/lowercase tags:
/// - Uppercase tags (`A`, `K`, `P`): Point to the root scope (e.g., video)
/// - Lowercase tags (`a`, `e`, `k`, `p`): Point to the parent item
///   (for replies)
///
/// For addressable events (kind 30000-39999 like videos), NIP-22 specifies
/// using `A` tag for root scope, not `E` tag. This ensures comments persist
/// across video edits (same address, different event IDs).
class CommentsRepository {
  /// Creates a new comments repository.
  ///
  /// Parameters:
  /// - [nostrClient]: Client for Nostr relay communication (handles signing)
  CommentsRepository({
    required NostrClient nostrClient,
  }) : _nostrClient = nostrClient;

  final NostrClient _nostrClient;

  /// Loads comments for a root event and returns them in a flat list.
  ///
  /// This is a one-shot query that returns all comments organized
  /// chronologically (newest first) with reply relationships maintained
  /// through each Comment's replyToEventId field.
  ///
  /// Parameters:
  /// - [rootEventId]: The ID of the event to load comments for
  /// - [rootEventKind]: The kind of the root event (e.g., 34236 for videos)
  /// - [rootAddressableId]: Required for addressable events (kind 30000-39999).
  ///   Format: `kind:pubkey:d-tag`. Per NIP-22, comments on addressable events
  ///   are queried by A-tag to ensure comments persist across video edits.
  /// - [limit]: Maximum number of comments to fetch (default: 100)
  /// - [before]: Cursor for pagination - fetch comments created
  ///   before this time.
  ///   Note: Nostr `until` filter is inclusive, so subtract 1 second from the
  ///   oldest loaded comment's timestamp when paginating.
  ///
  /// Returns a [CommentThread] containing:
  /// - All comments in chronological order
  /// - Comment cache for quick lookup by ID
  /// - Total comment count
  ///
  /// Throws [LoadCommentsFailedException] if the query fails.
  Future<CommentThread> loadComments({
    required String rootEventId,
    required int rootEventKind,
    required String rootAddressableId,
    int limit = _defaultLimit,
    DateTime? before,
  }) async {
    try {
      final untilTimestamp = before != null
          ? before.millisecondsSinceEpoch ~/ 1000
          : null;

      // NIP-22: Query by BOTH A-tag and E-tag to catch all comments.
      // - A-tag: For NIP-22 compliant clients (addressable events)
      // - E-tag: For older clients or those using event ID references
      // Results are deduplicated by event ID when building the thread.
      final filterByA = Filter(
        kinds: const [_commentKind],
        uppercaseA: [rootAddressableId],
        limit: limit,
        until: untilTimestamp,
      );

      final filterByE = Filter(
        kinds: const [_commentKind],
        uppercaseE: [rootEventId],
        limit: limit,
        until: untilTimestamp,
      );

      // Query with both filters - Nostr returns events matching ANY filter
      final events = await _nostrClient.queryEvents([filterByA, filterByE]);

      developer.log(
        '💬 CommentsRepository.loadComments: '
        'A-tag=$rootAddressableId, E-tag=$rootEventId '
        'returned ${events.length} comments (deduplicated)',
        name: 'CommentsRepository',
      );

      return _buildThreadFromEvents(events, rootEventId, rootEventKind);
    } on Exception catch (e) {
      throw LoadCommentsFailedException('Failed to load comments: $e');
    }
  }

  /// Posts a new comment using NIP-22 format.
  ///
  /// Creates a Kind 1111 event with proper NIP-22 threading tags
  /// and broadcasts it to relays.
  ///
  /// Parameters:
  /// - [content]: The comment text
  /// - [rootEventId]: The ID of the root event (e.g., video)
  /// - [rootEventKind]: The kind of the root event (e.g., 34236)
  /// - [rootEventAuthorPubkey]: Public key of the root event author
  /// - [rootAddressableId]: Optional addressable identifier for the root event
  ///   (format: `kind:pubkey:d-tag`). When provided, includes both E and A tags
  ///   to ensure the comment can be found by clients querying either way.
  /// - [replyToEventId]: ID of parent comment (for nested replies)
  /// - [replyToAuthorPubkey]: Public key of parent comment author
  ///
  /// Returns the created [Comment] with its event ID.
  ///
  /// Throws [InvalidCommentContentException] if content is empty.
  /// Throws [PostCommentFailedException] if broadcasting fails.
  Future<Comment> postComment({
    required String content,
    required String rootEventId,
    required int rootEventKind,
    required String rootEventAuthorPubkey,
    String? rootAddressableId,
    String? replyToEventId,
    String? replyToAuthorPubkey,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw const InvalidCommentContentException('Comment cannot be empty');
    }

    // Build tags for NIP-22 threading
    // Uppercase tags point to root scope, lowercase to parent item
    //
    // Per NIP-22 spec: For addressable events (kind 30000-39999), use A tag
    // as the primary root scope identifier. This matches the blog post example
    // in the spec which uses A tag for kind 30023.
    final tags = <List<String>>[
      // Root scope tags (uppercase) - A tag is primary for addressable events
      if (rootAddressableId != null && rootAddressableId.isNotEmpty)
        ['A', rootAddressableId, ''],
      ['K', rootEventKind.toString()],
      ['P', rootEventAuthorPubkey],
      // Parent item tags (lowercase)
      if (replyToEventId != null && replyToAuthorPubkey != null) ...[
        // Replying to another comment
        ['e', replyToEventId, '', replyToAuthorPubkey],
        ['k', _commentKind.toString()],
        ['p', replyToAuthorPubkey],
      ] else ...[
        // Top-level comment - parent is the same as root
        // Per NIP-22: "when the parent event is replaceable or addressable,
        // also include an `e` tag referencing its id"
        if (rootAddressableId != null && rootAddressableId.isNotEmpty)
          ['a', rootAddressableId, ''],
        ['e', rootEventId, ''],
        ['k', rootEventKind.toString()],
        ['p', rootEventAuthorPubkey],
      ],
    ];

    // Create the event
    final event = Event(
      _nostrClient.publicKey,
      _commentKind,
      tags,
      trimmedContent,
    );

    try {
      // Broadcast the event (NostrClient handles signing)
      final sentEvent = await _nostrClient.publishEvent(event);

      if (sentEvent == null) {
        throw const PostCommentFailedException('Failed to publish comment');
      }

      return Comment(
        id: sentEvent.id,
        content: trimmedContent,
        authorPubkey: sentEvent.pubkey,
        createdAt: event.createdAtDateTime,
        rootEventId: rootEventId,
        rootAuthorPubkey: rootEventAuthorPubkey,
        replyToEventId: replyToEventId,
        replyToAuthorPubkey: replyToAuthorPubkey,
      );
    } on CommentsRepositoryException {
      rethrow;
    } on Exception catch (e) {
      throw PostCommentFailedException('Failed to post comment: $e');
    }
  }

  /// Gets the comment count for an addressable event.
  ///
  /// Queries by both A-tag and E-tag to catch all comments regardless of
  /// how they were tagged by different clients. Uses a lightweight REQ query
  /// instead of NIP-45 COUNT for consistent results across relays.
  ///
  /// Parameters:
  /// - [rootAddressableId]: The addressable ID of the event to count comments
  ///   for. Format: `kind:pubkey:d-tag`.
  /// - [rootEventId]: The event ID to also query by E-tag.
  ///
  /// Returns the number of unique comments on the event.
  ///
  /// Throws [CountCommentsFailedException] if counting fails.
  Future<int> getCommentsCount(
    String rootAddressableId, {
    required String rootEventId,
  }) async {
    try {
      // Query by BOTH A-tag and E-tag to catch all comments.
      // Using REQ query instead of NIP-45 COUNT for consistency,
      // as COUNT support varies across relays.
      final filterByA = Filter(
        kinds: const [_commentKind],
        uppercaseA: [rootAddressableId],
      );

      final filterByE = Filter(
        kinds: const [_commentKind],
        uppercaseE: [rootEventId],
      );

      final events = await _nostrClient.queryEvents([filterByA, filterByE]);

      // Events are deduplicated by ID, so length is the unique count
      developer.log(
        '💬 CommentsRepository.getCommentsCount: '
        'A-tag=$rootAddressableId, E-tag=$rootEventId '
        'returned ${events.length} unique comments',
        name: 'CommentsRepository',
      );

      return events.length;
    } on Exception catch (e) {
      throw CountCommentsFailedException('Failed to count comments: $e');
    }
  }

  /// Deletes a comment by publishing a NIP-09 deletion request.
  ///
  /// Creates a Kind 5 event with an `e` tag referencing the comment
  /// and a `k` tag specifying the comment kind (1111).
  ///
  /// Parameters:
  /// - [commentId]: The ID of the comment event to delete
  /// - [reason]: Optional reason for the deletion
  ///
  /// Throws [DeleteCommentFailedException] if broadcasting fails.
  Future<void> deleteComment({
    required String commentId,
    String? reason,
  }) async {
    try {
      // NIP-09: Build deletion request tags
      final tags = <List<String>>[
        ['e', commentId],
        ['k', _commentKind.toString()],
      ];

      final event = Event(
        _nostrClient.publicKey,
        _deletionKind,
        tags,
        reason ?? '',
      );

      final sentEvent = await _nostrClient.publishEvent(event);
      if (sentEvent == null) {
        throw const DeleteCommentFailedException(
          'Failed to publish deletion request',
        );
      }
    } on CommentsRepositoryException {
      rethrow;
    } on Exception catch (e) {
      throw DeleteCommentFailedException('Failed to delete comment: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Converts a Nostr event to a Comment model using NIP-22 format.
  Comment? _eventToComment(Event event, String rootEventId, int rootEventKind) {
    try {
      String? parsedRootEventId;
      String? parsedRootAddressableId;
      String? replyToEventId;
      String? rootAuthorPubkey;
      String? replyToAuthorPubkey;
      String? parentKind;

      // Parse NIP-22 tags to determine comment relationships
      // Uppercase tags (A, E, K, P) = root scope
      // Lowercase tags (a, e, k, p) = parent item
      for (final rawTag in event.tags) {
        final tag = rawTag as List<dynamic>;
        if (tag.length < 2) continue;

        final tagType = tag[0] as String;
        final tagValue = tag[1] as String;

        switch (tagType) {
          case 'A':
            // Root addressable ID (uppercase = root scope)
            parsedRootAddressableId = tagValue;
          case 'E':
            // Root event ID (uppercase = root scope for non-addressable events)
            parsedRootEventId = tagValue;
            if (tag.length >= 4) {
              rootAuthorPubkey = tag[3] as String;
            }
          case 'P':
            // Root author pubkey (uppercase = root scope)
            rootAuthorPubkey ??= tagValue;
          case 'e':
            // Parent event ID (lowercase = parent item)
            replyToEventId = tagValue;
            if (tag.length >= 4) {
              replyToAuthorPubkey = tag[3] as String;
            }
          case 'k':
            // Parent kind (lowercase = parent item)
            parentKind = tagValue;
          case 'p':
            // Parent author pubkey (lowercase = parent item)
            replyToAuthorPubkey ??= tagValue;
        }
      }

      // Determine if this is a top-level comment or a reply
      // If parent kind equals root kind, it's a top-level comment
      final isTopLevel =
          parentKind == rootEventKind.toString() ||
          replyToEventId == parsedRootEventId;

      // For addressable events, extract pubkey from the A tag if available
      // A tag format: kind:pubkey:d-tag
      if (rootAuthorPubkey == null && parsedRootAddressableId != null) {
        final parts = parsedRootAddressableId.split(':');
        if (parts.length >= 2) {
          rootAuthorPubkey = parts[1];
        }
      }

      return Comment(
        id: event.id,
        content: event.content,
        authorPubkey: event.pubkey,
        createdAt: event.createdAtDateTime,
        rootEventId: parsedRootEventId ?? rootEventId,
        // For top-level comments, replyToEventId should be null
        replyToEventId: isTopLevel ? null : replyToEventId,
        rootAuthorPubkey: rootAuthorPubkey ?? '',
        replyToAuthorPubkey: isTopLevel ? null : replyToAuthorPubkey,
      );
    } on Exception {
      return null;
    }
  }

  /// Builds a CommentThread from a list of Nostr events.
  CommentThread _buildThreadFromEvents(
    List<Event> events,
    String rootEventId,
    int rootEventKind,
  ) {
    final commentMap = <String, Comment>{};

    for (final event in events) {
      final comment = _eventToComment(event, rootEventId, rootEventKind);
      if (comment != null) {
        commentMap[comment.id] = comment;
      }
    }

    return _buildThreadFromComments(commentMap, rootEventId);
  }

  /// Builds a CommentThread from a map of comments.
  ///
  /// Organizes comments into a flat list sorted chronologically (newest first).
  /// Reply relationships are maintained through each Comment's
  /// replyToEventId field.
  CommentThread _buildThreadFromComments(
    Map<String, Comment> commentMap,
    String rootEventId,
  ) {
    if (commentMap.isEmpty) {
      return CommentThread.empty(rootEventId);
    }

    // Simple chronological sort: newest first
    final sortedComments = commentMap.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return CommentThread(
      rootEventId: rootEventId,
      comments: sortedComments,
      totalCount: commentMap.length,
      commentCache: Map<String, Comment>.unmodifiable(commentMap),
    );
  }
}
