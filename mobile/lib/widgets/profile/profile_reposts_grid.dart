// ABOUTME: Grid widget displaying user's reposted videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails and repost badge indicator

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/profile_reposts_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/video_tile_renderer.dart';

/// Grid widget displaying user's reposted videos
class ProfileRepostsGrid extends ConsumerWidget {
  const ProfileRepostsGrid({required this.userIdHex, super.key});

  final String userIdHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repostsAsync = ref.watch(profileRepostsProvider(userIdHex));

    return repostsAsync.when(
      data: (reposts) {
        if (reposts.isEmpty) {
          return const _RepostsEmptyState();
        }

        return CustomScrollView(
          slivers: [
            ComposableVideoGrid.sliver(
              videos: reposts,
              padding: const EdgeInsets.all(2),
              tileBuilder: (video, idx) => sharedVideoTile(
                context,
                video: video,
                aspectRatio: 1,
                onTap: () {
                  context.pushVideoFeed(
                    source: ProfileRepostsFeedSource(userIdHex),
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
                    Icons.repeat,
                    color: VineTheme.vineGreen,
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
      error: (error, stack) =>
          Center(child: Text('Error loading reposts: $error')),
    );
  }
}

/// Empty state shown when user has no reposts
class _RepostsEmptyState extends StatelessWidget {
  const _RepostsEmptyState();

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
              Icon(Icons.repeat, color: Colors.grey, size: 64),
              SizedBox(height: 16),
              Text(
                'No Reposts Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Videos you repost will appear here',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
