// ABOUTME: Router-aware hashtag screen that shows grid based on URL
// ABOUTME: Caches hashtag so grid state survives pushed routes (e.g. fullscreen feed)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Router-aware hashtag screen that shows the hashtag video grid.
///
/// Caches the hashtag value so the [HashtagFeedScreen] (and its scroll
/// position) survives when a route is pushed on top (e.g. the fullscreen
/// feed). Only updates the hashtag when [pageContextProvider] emits a
/// [RouteType.hashtag] context.
class HashtagScreenRouter extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'hashtag';

  /// Base path for hashtag routes.
  static const basePath = '/hashtag';

  /// Path for this route.
  static const path = '/hashtag/:tag';

  /// Build path for a specific hashtag.
  static String pathForTag(String tag) {
    final encodedTag = Uri.encodeComponent(tag);
    return '$basePath/$encodedTag';
  }

  const HashtagScreenRouter({super.key});

  @override
  ConsumerState<HashtagScreenRouter> createState() =>
      _HashtagScreenRouterState();
}

class _HashtagScreenRouterState extends ConsumerState<HashtagScreenRouter> {
  /// Cached hashtag value, preserved across route pushes.
  String? _hashtag;

  @override
  Widget build(BuildContext context) {
    final routeCtx = ref.watch(pageContextProvider).asData?.value;

    // Only update the cached hashtag when we receive a hashtag route context.
    // This prevents the HashtagFeedScreen from being disposed when a route
    // (e.g. fullscreen video feed) is pushed on top.
    if (routeCtx != null && routeCtx.type == RouteType.hashtag) {
      final newHashtag = routeCtx.hashtag ?? 'trending';
      if (_hashtag != newHashtag) {
        _hashtag = newHashtag;
        Log.info(
          'HashtagScreenRouter: Showing grid for #$_hashtag',
          name: 'HashtagRouter',
          category: LogCategory.ui,
        );
      }
    }

    // Show the grid with the cached hashtag (survives pushed routes)
    if (_hashtag != null) {
      return HashtagFeedScreen(hashtag: _hashtag!, embedded: true);
    }

    // Only shown briefly on initial load before pageContextProvider emits
    Log.warning(
      'HashtagScreenRouter: Waiting for route context',
      name: 'HashtagRouter',
      category: LogCategory.ui,
    );
    return const Scaffold(body: Center(child: Text('Loading...')));
  }
}
