// ABOUTME: Tests for VideoSharingService social features integration
// ABOUTME: Covers NIP-17 video sharing, getShareableUsers,
// ABOUTME: and searchUsersToShareWith

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:models/models.dart';
import 'package:openvine/services/nip17_message_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_sharing_service.dart';

import 'video_sharing_service_test.mocks.dart';

// Note: SocialService mock removed - following list now handled by
// FollowRepository. These tests are mostly skipped and need updating
// to use FollowRepository.
@GenerateMocks([NIP17MessageService, UserProfileService])
void main() {
  late VideoSharingService service;
  late MockNIP17MessageService mockNip17MessageService;
  late MockUserProfileService mockUserProfileService;

  setUp(() {
    mockNip17MessageService = MockNIP17MessageService();
    mockUserProfileService = MockUserProfileService();

    service = VideoSharingService(
      nip17MessageService: mockNip17MessageService,
      userProfileService: mockUserProfileService,
    );
  });

  group('shareVideoWithUser', () {
    late VideoEvent testVideo;
    const recipientPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const messageEventId =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    setUp(() {
      final now = DateTime.now();
      testVideo = VideoEvent(
        id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        pubkey:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test video',
      );
    });

    test('calls sendPrivateMessage with correct recipient', () async {
      when(
        mockNip17MessageService.sendPrivateMessage(
          recipientPubkey: anyNamed('recipientPubkey'),
          content: anyNamed('content'),
          additionalTags: anyNamed('additionalTags'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
        ),
      );
      when(
        mockUserProfileService.fetchProfile(any),
      ).thenAnswer((_) async => null);

      await service.shareVideoWithUser(
        video: testVideo,
        recipientPubkey: recipientPubkey,
      );

      verify(
        mockNip17MessageService.sendPrivateMessage(
          recipientPubkey: recipientPubkey,
          content: anyNamed('content'),
          additionalTags: anyNamed('additionalTags'),
        ),
      ).called(1);
    });

    test('includes e tag with video event ID in additionalTags', () async {
      when(
        mockNip17MessageService.sendPrivateMessage(
          recipientPubkey: anyNamed('recipientPubkey'),
          content: anyNamed('content'),
          additionalTags: anyNamed('additionalTags'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
        ),
      );
      when(
        mockUserProfileService.fetchProfile(any),
      ).thenAnswer((_) async => null);

      await service.shareVideoWithUser(
        video: testVideo,
        recipientPubkey: recipientPubkey,
      );

      final captured =
          verify(
                mockNip17MessageService.sendPrivateMessage(
                  recipientPubkey: anyNamed('recipientPubkey'),
                  content: anyNamed('content'),
                  additionalTags: captureAnyNamed('additionalTags'),
                ),
              ).captured.single
              as List<List<String>>;

      expect(
        captured,
        containsAll([
          ['e', testVideo.id],
          ['client', 'diVine'],
        ]),
      );
    });

    test('includes a tag when addressableId is present', () async {
      final now = DateTime.now();
      final videoWithVineId = VideoEvent(
        id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        pubkey:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test video with vine ID',
        vineId: 'my-vine-id',
      );

      when(
        mockNip17MessageService.sendPrivateMessage(
          recipientPubkey: anyNamed('recipientPubkey'),
          content: anyNamed('content'),
          additionalTags: anyNamed('additionalTags'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
        ),
      );
      when(
        mockUserProfileService.fetchProfile(any),
      ).thenAnswer((_) async => null);

      await service.shareVideoWithUser(
        video: videoWithVineId,
        recipientPubkey: recipientPubkey,
      );

      final captured =
          verify(
                mockNip17MessageService.sendPrivateMessage(
                  recipientPubkey: anyNamed('recipientPubkey'),
                  content: anyNamed('content'),
                  additionalTags: captureAnyNamed('additionalTags'),
                ),
              ).captured.single
              as List<List<String>>;

      // Should contain an 'a' tag since vineId (d tag) is present
      final aTag = captured.where((tag) => tag[0] == 'a');
      expect(aTag, isNotEmpty);
    });

    test('returns failure when NIP-17 send fails', () async {
      when(
        mockNip17MessageService.sendPrivateMessage(
          recipientPubkey: anyNamed('recipientPubkey'),
          content: anyNamed('content'),
          additionalTags: anyNamed('additionalTags'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.failure('No private key available'),
      );

      final result = await service.shareVideoWithUser(
        video: testVideo,
        recipientPubkey: recipientPubkey,
      );

      expect(result.success, isFalse);
      expect(result.error, equals('No private key available'));
    });

    test('returns success and updates share history on success', () async {
      when(
        mockNip17MessageService.sendPrivateMessage(
          recipientPubkey: anyNamed('recipientPubkey'),
          content: anyNamed('content'),
          additionalTags: anyNamed('additionalTags'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          messageEventId: messageEventId,
          recipientPubkey: recipientPubkey,
        ),
      );
      when(
        mockUserProfileService.fetchProfile(any),
      ).thenAnswer((_) async => null);

      final result = await service.shareVideoWithUser(
        video: testVideo,
        recipientPubkey: recipientPubkey,
      );

      expect(result.success, isTrue);
      expect(result.messageEventId, equals(messageEventId));
      expect(service.hasSharedWithRecently(recipientPubkey), isTrue);
      expect(service.recentlySharedWith, hasLength(1));
      expect(service.recentlySharedWith.first.pubkey, equals(recipientPubkey));
    });
  });

  group('getShareableUsers', () {
    test(
      'returns recently shared users when no following list exists',
      () async {
        // Act
        final result = await service.getShareableUsers(limit: 20);

        // Assert
        expect(result, isEmpty);
      },
      // TODO(Any): Fix and re-enable these tests
      skip: true,
    );

    test('returns following list with profile data', () async {
      // Arrange
      final followingPubkeys = [
        'pubkey1' * 8, // 64 chars
        'pubkey2' * 8,
        'pubkey3' * 8,
      ];

      final profile1 = UserProfile(
        pubkey: followingPubkeys[0],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        name: 'Alice',
        displayName: 'Alice Smith',
        picture: 'https://example.com/alice.jpg',
      );

      final profile2 = UserProfile(
        pubkey: followingPubkeys[1],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event2',
        name: 'Bob',
        displayName: 'Bob Jones',
      );

      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[0]),
      ).thenReturn(profile1);
      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[1]),
      ).thenReturn(profile2);
      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[2]),
      ).thenReturn(null);

      // Act
      final result = await service.getShareableUsers(limit: 20);

      // Assert
      expect(result.length, 3);
      expect(result[0].pubkey, followingPubkeys[0]);
      expect(result[0].displayName, 'Alice Smith');
      expect(result[0].picture, 'https://example.com/alice.jpg');
      expect(result[0].isFollowing, true);

      expect(result[1].pubkey, followingPubkeys[1]);
      expect(result[1].displayName, 'Bob Jones');
      expect(result[1].isFollowing, true);

      expect(result[2].pubkey, followingPubkeys[2]);
      expect(result[2].displayName, null);
      expect(result[2].isFollowing, true);
      // TODO(Any): Fix and re-enable these tests
    }, skip: true);

    test('prioritizes recently shared users over following list', () async {
      // Arrange
      final followingPubkeys = ['pubkey1' * 8, 'pubkey2' * 8];

      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);

      // Share with one user to add to recent
      final now = DateTime.now();
      final testVideo = VideoEvent(
        id: 'video1',
        pubkey: 'author123',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test video',
      );

      when(
        mockNip17MessageService.sendPrivateMessage(
          recipientPubkey: anyNamed('recipientPubkey'),
          content: anyNamed('content'),
          additionalTags: anyNamed('additionalTags'),
        ),
      ).thenAnswer((_) async => NIP17SendResult.failure('test'));

      await service.shareVideoWithUser(
        video: testVideo,
        recipientPubkey: followingPubkeys[0],
      );

      // Act
      final result = await service.getShareableUsers(limit: 20);

      // Assert
      expect(
        result,
        isNotEmpty,
        reason: 'Should return at least one shareable user from following list',
      );
      // Recently shared should appear first
      expect(result.first.pubkey, followingPubkeys[0]);
      // TODO(Any): Fix and re-enable these tests
    }, skip: true);

    test('respects limit parameter', () async {
      // Arrange
      // ignore: unused_local_variable - test is skipped, needs updating
      final followingPubkeys = List.generate(25, (i) => 'pubkey$i' * 8);

      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);

      // Act
      final result = await service.getShareableUsers(limit: 10);

      // Assert
      expect(result.length, 10);
      // TODO(Any): Fix and re-enable these tests
    }, skip: true);
  });

  group('searchUsersToShareWith', () {
    test('returns empty list for empty query', () async {
      // Act
      final result = await service.searchUsersToShareWith('');

      // Assert
      expect(result, isEmpty);
    });

    test('searches by display name in following list', () async {
      // Arrange
      final followingPubkeys = ['pubkey1' * 8, 'pubkey2' * 8, 'pubkey3' * 8];

      final profile1 = UserProfile(
        pubkey: followingPubkeys[0],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        displayName: 'Alice Smith',
      );

      final profile2 = UserProfile(
        pubkey: followingPubkeys[1],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event2',
        displayName: 'Bob Jones',
      );

      final profile3 = UserProfile(
        pubkey: followingPubkeys[2],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event3',
        displayName: 'Alice Johnson',
      );

      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[0]),
      ).thenReturn(profile1);
      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[1]),
      ).thenReturn(profile2);
      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[2]),
      ).thenReturn(profile3);

      // Act
      final result = await service.searchUsersToShareWith('alice');

      // Assert
      expect(result.length, 2);
      expect(result[0].displayName, 'Alice Smith');
      expect(result[1].displayName, 'Alice Johnson');
      // TODO(Any): Fix and re-enable these tests
    }, skip: true);

    test('searches by name field if displayName is null', () async {
      // Arrange
      final followingPubkeys = ['pubkey1' * 8];

      final profile = UserProfile(
        pubkey: followingPubkeys[0],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        name: 'alice',
      );

      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[0]),
      ).thenReturn(profile);

      // Act
      final result = await service.searchUsersToShareWith('alice');

      // Assert
      expect(result.length, 1);
      // Implementation falls back to name when displayName is null
      // for better UX
      expect(result[0].displayName, 'alice');
      // TODO(Any): Fix and re-enable these tests
    }, skip: true);

    test('returns user by hex pubkey lookup as fallback', () async {
      // Arrange
      final hexPubkey = 'a' * 64;
      final profile = UserProfile(
        pubkey: hexPubkey,
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        displayName: 'Charlie',
      );

      when(
        mockUserProfileService.fetchProfile(hexPubkey),
      ).thenAnswer((_) async => profile);

      // Act
      final result = await service.searchUsersToShareWith(hexPubkey);

      // Assert
      expect(result.length, 1);
      expect(result[0].pubkey, hexPubkey);
      expect(result[0].displayName, 'Charlie');
      verify(mockUserProfileService.fetchProfile(hexPubkey)).called(1);
    });

    test('is case insensitive for display name search', () async {
      // Arrange
      final followingPubkeys = ['pubkey1' * 8];

      final profile = UserProfile(
        pubkey: followingPubkeys[0],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        displayName: 'Alice Smith',
      );

      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[0]),
      ).thenReturn(profile);

      // Act
      final result = await service.searchUsersToShareWith('ALICE');

      // Assert
      expect(result.length, 1);
      expect(result[0].displayName, 'Alice Smith');
      // TODO(Any): Fix and re-enable these tests
    }, skip: true);

    test('returns empty list when hex pubkey not found', () async {
      // Arrange
      final hexPubkey = 'a' * 64;

      when(
        mockUserProfileService.fetchProfile(hexPubkey),
      ).thenAnswer((_) async => null);

      // Act
      final result = await service.searchUsersToShareWith(hexPubkey);

      // Assert
      expect(result, isEmpty);
      // TODO(Any): Fix and re-enable these tests
    }, skip: true);
  });
}
