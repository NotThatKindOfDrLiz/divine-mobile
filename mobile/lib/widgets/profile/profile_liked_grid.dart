// ABOUTME: Grid widget displaying user's liked videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails and heart badge indicator

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/profile_liked_feed_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/video_tile_renderer.dart';

/// Grid widget displaying user's liked videos
///
/// Watches [profileLikedFeedProvider] for liked videos state.
/// Both grid and fullscreen view use the same provider for consistency.
class ProfileLikedGrid extends ConsumerWidget {
  const ProfileLikedGrid({required this.userIdHex, super.key});

  /// The hex public key of the user whose liked videos to display.
  final String userIdHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedFeedAsync = ref.watch(profileLikedFeedProvider(userIdHex));

    return likedFeedAsync.when(
      data: (feedState) {
        if (feedState.error != null) {
          return const Center(
            child: Text(
              'Error loading liked videos',
              style: TextStyle(color: VineTheme.whiteText),
            ),
          );
        }

        final likedVideos = feedState.videos;

        if (likedVideos.isEmpty) {
          return const _LikedEmptyState();
        }

        return CustomScrollView(
          slivers: [
            ComposableVideoGrid.sliver(
              videos: likedVideos,
              padding: const EdgeInsets.all(2),
              tileBuilder: (video, idx) => sharedVideoTile(
                context,
                video: video,
                aspectRatio: 1,
                onTap: () {
                  context.pushVideoFeed(
                    source: LikedVideosFeedSource(userIdHex),
                    initialIndex: idx,
                  );
                },
                badge: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
      error: (error, stack) => const Center(
        child: Text(
          'Error loading liked videos',
          style: TextStyle(color: VineTheme.whiteText),
        ),
      ),
    );
  }
}

/// Empty state shown when user has no liked videos
class _LikedEmptyState extends StatelessWidget {
  const _LikedEmptyState();

  @override
  Widget build(BuildContext context) => const CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, color: Colors.grey, size: 64),
              SizedBox(height: 16),
              Text(
                'No Liked Videos Yet',
                style: TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Videos you like will appear here',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
