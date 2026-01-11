// ABOUTME: Grid widget displaying user's liked videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails and heart badge indicator

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/providers/liked_videos_state_bridge.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/video_tile_renderer.dart';

/// Grid widget displaying user's liked videos
///
/// Requires [ProfileLikedVideosBloc] to be provided in the widget tree.
/// Syncs BLoC state to [likedVideosFeedStateProvider] for fullscreen navigation.
class ProfileLikedGrid extends ConsumerWidget {
  const ProfileLikedGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocConsumer<ProfileLikedVideosBloc, ProfileLikedVideosState>(
      listener: (context, state) {
        // Sync BLoC state to Riverpod bridge provider for fullscreen navigation
        final isLoading = state.status == ProfileLikedVideosStatus.initial ||
            state.status == ProfileLikedVideosStatus.syncing ||
            state.status == ProfileLikedVideosStatus.loading;

        ref.read(likedVideosFeedStateProvider.notifier).state =
            LikedVideosBridgeState(
          isLoading: isLoading,
          videos: state.videos,
        );
      },
      builder: (context, state) {
        if (state.status == ProfileLikedVideosStatus.initial ||
            state.status == ProfileLikedVideosStatus.syncing ||
            state.status == ProfileLikedVideosStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          );
        }

        if (state.status == ProfileLikedVideosStatus.failure) {
          return const Center(
            child: Text(
              'Error loading liked videos',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final likedVideos = state.videos;

        if (likedVideos.isEmpty) {
          return const _LikedEmptyState();
        }

        return CustomScrollView(
          slivers: [
            ComposableVideoGrid.sliver(
              videos: likedVideos,
              onVideoTap: (_, __) {},
              crossAxisCount: 3,
              thumbnailAspectRatio: 1,
              padding: const EdgeInsets.all(2),
              tileBuilder: (video, idx) => sharedVideoTile(
                context,
                video: video,
                aspectRatio: 1,
                onTap: () {
                  context.pushVideoFeed(
                    source: const LikedVideosFeedSource(),
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
                showInfo: false,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Empty state shown when user has no liked videos
class _LikedEmptyState extends StatelessWidget {
  const _LikedEmptyState();

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.favorite_border, color: Colors.grey, size: 64),
              SizedBox(height: 16),
              Text(
                'No Liked Videos Yet',
                style: TextStyle(
                  color: Colors.white,
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
