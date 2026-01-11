// ABOUTME: Router-aware liked videos screen that shows grid or feed based on
// URL
// ABOUTME: Reads route context to determine grid mode vs feed mode

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/profile_liked_feed_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/profile/profile_liked_grid.dart';

/// Router-aware liked videos screen that shows grid or feed based on route
///
/// This screen handles the `/liked-videos` and `/liked-videos/:index` routes.
/// It uses [profileLikedFeedProvider] for state management.
class LikedVideosScreenRouter extends ConsumerWidget {
  const LikedVideosScreenRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeCtx = ref.watch(pageContextProvider).asData?.value;
    final nostrClient = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrClient.publicKey;

    if (routeCtx == null || routeCtx.type != RouteType.likedVideos) {
      Log.warning(
        'LikedVideosScreenRouter: Invalid route context',
        name: 'LikedVideosRouter',
        category: LogCategory.ui,
      );
      return const Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: Center(
          child: Text(
            'Invalid route',
            style: TextStyle(color: VineTheme.whiteText),
          ),
        ),
      );
    }

    final videoIndex = routeCtx.videoIndex;

    // Grid mode: no video index
    if (videoIndex == null) {
      Log.info(
        'LikedVideosScreenRouter: Showing grid',
        name: 'LikedVideosRouter',
        category: LogCategory.ui,
      );
      return Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: VineTheme.backgroundColor,
          title: const Text(
            'Liked Videos',
            style: TextStyle(color: VineTheme.whiteText),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
            onPressed: () => context.goMyProfile(),
          ),
        ),
        body: ProfileLikedGrid(userIdHex: currentUserPubkey),
      );
    }

    // Feed mode: show video at specific index using FullscreenVideoFeedScreen
    Log.info(
      'LikedVideosScreenRouter: Showing feed (index=$videoIndex)',
      name: 'LikedVideosRouter',
      category: LogCategory.ui,
    );

    // Watch the provider to get videos
    final feedState = ref.watch(profileLikedFeedProvider(currentUserPubkey));

    return feedState.when(
      data: (state) {
        if (state.videos.isEmpty) {
          return Scaffold(
            backgroundColor: VineTheme.backgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
                onPressed: () => context.pop(),
              ),
            ),
            body: const Center(
              child: Text(
                'No liked videos',
                style: TextStyle(color: VineTheme.whiteText),
              ),
            ),
          );
        }

        // Use FullscreenVideoFeedScreen for consistent behavior
        return FullscreenVideoFeedScreen(
          source: LikedVideosFeedSource(currentUserPubkey),
          initialIndex: videoIndex.clamp(0, state.videos.length - 1),
          contextTitle: 'Liked Videos',
        );
      },
      loading: () => const Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'Error loading liked videos',
            style: TextStyle(color: VineTheme.whiteText),
          ),
        ),
      ),
    );
  }
}
