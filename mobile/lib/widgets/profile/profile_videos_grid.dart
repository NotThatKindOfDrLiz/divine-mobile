// ABOUTME: Grid widget displaying user's original videos on profile page
// ABOUTME: Watches profileOriginalsFeedProvider for consistent data with fullscreen view

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_originals_feed_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/video_tile_renderer.dart';

/// Grid widget displaying user's original videos on their profile
///
/// Watches [profileOriginalsFeedProvider] for video state.
/// Both grid and fullscreen view use the same provider for consistency.
class ProfileVideosGrid extends ConsumerWidget {
  const ProfileVideosGrid({required this.userIdHex, super.key});

  /// The hex public key of the user whose videos to display.
  final String userIdHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final originalsFeedAsync = ref.watch(
      profileOriginalsFeedProvider(userIdHex),
    );

    return originalsFeedAsync.when(
      data: (feedState) {
        if (feedState.error != null) {
          return Center(
            child: Text(
              'Error loading videos',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final originalVideos = feedState.videos;

        if (originalVideos.isEmpty) {
          return _ProfileVideosEmptyState(
            userIdHex: userIdHex,
            isOwnProfile:
                ref.read(authServiceProvider).currentPublicKeyHex == userIdHex,
            onRefresh: () => ref
                .read(profileOriginalsFeedProvider(userIdHex).notifier)
                .loadMore(),
          );
        }

        return CustomScrollView(
          slivers: [
            ComposableVideoGrid.sliver(
              videos: originalVideos,
              onVideoTap: (_, __) {},
              crossAxisCount: 3,
              thumbnailAspectRatio: 1,
              padding: const EdgeInsets.all(2),
              tileBuilder: (video, idx) => sharedVideoTile(
                context,
                video: video,
                aspectRatio: 1,
                onTap: () => context.pushVideoFeed(
                  source: ProfileOriginalsFeedSource(userIdHex),
                  initialIndex: idx,
                ),
                showInfo: false,
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
          'Error loading videos',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

/// Empty state shown when user has no videos
class _ProfileVideosEmptyState extends StatelessWidget {
  const _ProfileVideosEmptyState({
    required this.userIdHex,
    required this.isOwnProfile,
    required this.onRefresh,
  });

  final String userIdHex;
  final bool isOwnProfile;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_outlined, color: Colors.grey, size: 64),
              const SizedBox(height: 16),
              const Text(
                'No Videos Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOwnProfile
                    ? 'Share your first video to see it here'
                    : "This user hasn't shared any videos yet",
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh,
                  color: VineTheme.vineGreen,
                  size: 28,
                ),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
