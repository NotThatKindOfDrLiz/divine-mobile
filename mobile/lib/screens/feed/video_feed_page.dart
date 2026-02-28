import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';
import 'package:openvine/screens/feed/feed_video_overlay.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

extension on List<VideoEvent> {
  List<VideoItem> get toVideoItems {
    return map((e) => VideoItem(id: e.id, url: e.videoUrl!)).toList();
  }
}

class VideoFeedPage extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'home';

  /// Path for this route.
  static const path = '/home';

  /// Path for this route with index.
  static const pathWithIndex = '/home/:index';

  /// Build path for a specific index.
  static String pathForIndex(int index) => '/home/$index';

  const VideoFeedPage({this.initialMode = FeedMode.home, super.key});

  /// The feed mode to start with. Defaults to [FeedMode.home].
  final FeedMode initialMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosRepository = ref.watch(videosRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);

    // Show loading until NostrClient has keys
    if (followRepository == null) {
      return const BrandedLoadingScaffold();
    }

    final contentFilterService = ref.watch(contentFilterServiceProvider);
    final nostrClient = ref.watch(nostrServiceProvider);

    return BlocProvider(
      create: (_) => VideoFeedBloc(
        videosRepository: videosRepository,
        followRepository: followRepository,
        contentFilterService: contentFilterService,
        currentUserPubkey: nostrClient.publicKey,
      )..add(VideoFeedStarted(mode: initialMode)),
      child: const VideoFeedView(),
    );
  }
}

@visibleForTesting
class VideoFeedView extends ConsumerStatefulWidget {
  const VideoFeedView({super.key, @visibleForTesting this.controller});

  /// Optional external [VideoFeedController] for testing.
  ///
  /// When provided, this controller is used instead of creating one
  /// internally. This allows tests to inject a mock/fake controller
  /// and verify that overlay visibility changes call [setActive].
  @visibleForTesting
  final VideoFeedController? controller;

  @override
  ConsumerState<VideoFeedView> createState() => _VideoFeedViewState();
}

class _VideoFeedViewState extends ConsumerState<VideoFeedView>
    with WidgetsBindingObserver {
  int? lastPrefetchIndex;

  /// The controller for the pooled video feed.
  ///
  /// Created lazily when videos first become available from the BLoC,
  /// or injected via [VideoFeedView.controller] for testing.
  VideoFeedController? controller;

  /// Tracks the last set of pooled videos to detect new additions.
  List<VideoItem>? lastPooledVideos;

  /// Whether this state owns (and should dispose) the controller.
  bool get ownsController => widget.controller == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Use injected controller if provided (for testing)
    if (!ownsController) controller = widget.controller;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize controller eagerly if BLoC already has videos on first build
    handleVideoController();
  }

  @override
  void dispose() {
    if (ownsController) controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<VideoFeedBloc>().add(const VideoFeedAutoRefreshRequested());
    }
  }

  /// Handles the controller changes.
  ///
  /// Called from [didChangeDependencies] for eager setup and from
  /// [BlocListener] when videos arrive asynchronously.
  void handleVideoController([VideoFeedState? state]) {
    if (controller != null) return;

    final effectiveState = state ?? context.read<VideoFeedBloc>().state;
    if (!effectiveState.isLoaded || effectiveState.videos.isEmpty) return;

    final pooledVideos = effectiveState.videos.toVideoItems;

    controller = VideoFeedController(
      videos: pooledVideos,
      pool: PlayerPool.instance,
    );

    lastPooledVideos = pooledVideos;
  }

  /// Handles new videos from pagination by adding them to the controller.
  void handleVideosChanged(VideoFeedState state) {
    if (controller == null || lastPooledVideos == null) return;

    final pooledVideos = state.videos.toVideoItems;

    final newVideos = pooledVideos
        .where((v) => !lastPooledVideos!.any((old) => old.id == v.id))
        .toList();

    if (newVideos.isNotEmpty) controller?.addVideos(newVideos);

    lastPooledVideos = pooledVideos;
  }

  void prefetchProfiles(List<VideoEvent> videos, int index) {
    if (index == lastPrefetchIndex) return;
    lastPrefetchIndex = index;

    final safeIndex = index.clamp(0, videos.length - 1);
    final pubkeys = <String>[];

    if (safeIndex > 0) {
      pubkeys.add(videos[safeIndex - 1].pubkey);
    }

    if (safeIndex < videos.length - 1) {
      pubkeys.add(videos[safeIndex + 1].pubkey);
    }

    if (pubkeys.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(userProfileProvider.notifier)
            .prefetchProfilesImmediately(pubkeys);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pause/resume the pooled video feed when overlays (drawer, modals)
    // become visible or hidden. Without this, the home feed's
    // PooledVideoFeed continues playing because activeVideoIdProvider
    // returns null for RouteType.home (self-managed by the pool).
    ref.listen(hasVisibleOverlayProvider, (_, hasOverlay) {
      controller?.setActive(active: !hasOverlay);
    });

    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: MultiBlocListener(
        listeners: [
          // Reset controller when mode changes so a fresh one is
          // created for the new feed.
          BlocListener<VideoFeedBloc, VideoFeedState>(
            listenWhen: (previous, current) =>
                previous.mode != current.mode && current.isLoading,
            listener: (_, state) {
              if (ownsController) controller?.dispose();
              controller = null;
              lastPooledVideos = null;
              lastPrefetchIndex = null;
            },
          ),
          // Initialize controller when videos first become available
          BlocListener<VideoFeedBloc, VideoFeedState>(
            listenWhen: (previous, current) =>
                !previous.isLoaded &&
                current.isLoaded &&
                current.videos.isNotEmpty,
            listener: (_, state) => handleVideoController(state),
          ),
          // Handle new videos from pagination
          BlocListener<VideoFeedBloc, VideoFeedState>(
            listenWhen: (previous, current) =>
                previous.videos.length != current.videos.length,
            listener: (_, state) => handleVideosChanged(state),
          ),
        ],
        child: BlocBuilder<VideoFeedBloc, VideoFeedState>(
          builder: (context, state) {
            // Loading state (including initial state before first load)
            if (state.isLoading) {
              return const Center(child: BrandedLoadingIndicator(size: 80));
            }

            // Error state
            if (state.status == VideoFeedStatus.failure) {
              return _FeedErrorWidget(error: state.error);
            }

            // Empty state
            if (state.isEmpty) {
              return Stack(
                children: [
                  FeedEmptyWidget(state: state),
                  const FeedModeSwitch(),
                ],
              );
            }

            // Wrap videos for pool compatibility
            final pooledVideos = state.videos.toVideoItems;

            // Note: RefreshIndicator removed - it conflicts with PageView
            // scrolling and adds memory overhead. Use the refresh button
            // instead.
            return Stack(
              children: [
                PooledVideoFeed(
                  key: ValueKey(state.mode),
                  videos: pooledVideos,
                  controller: controller,
                  itemBuilder: (context, video, index, {required isActive}) {
                    final originalEvent = state.videos[index];
                    return _PooledVideoFeedItem(
                      video: originalEvent,
                      index: index,
                      isActive: isActive,
                      contextTitle: state.mode.name,
                    );
                  },
                  onActiveVideoChanged: (video, index) {
                    prefetchProfiles(state.videos, index);
                  },
                  onNearEnd: (index) {
                    // PooledVideoFeed fires this when the user is within
                    // nearEndThreshold (default 3) of the end, using the
                    // controller's actual video count (not the BlocBuilder's
                    // list length, which may differ due to deduplication).
                    if (state.hasMore) {
                      context.read<VideoFeedBloc>().add(
                        const VideoFeedLoadMoreRequested(),
                      );
                    }
                  },
                ),
                const FeedModeSwitch(),
                // Loading more indicator
                if (state.isLoadingMore)
                  const Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: VineTheme.vineGreen,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeedErrorWidget extends StatelessWidget {
  const _FeedErrorWidget({this.error});

  final VideoFeedError? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Failed to load videos',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error.toString(), style: const TextStyle(color: Colors.grey)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.read<VideoFeedBloc>().add(
              const VideoFeedRefreshRequested(),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class FeedEmptyWidget extends StatelessWidget {
  const FeedEmptyWidget({required this.state, super.key});

  final VideoFeedState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_outlined,
            color: Colors.grey,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _getEmptyMessage(state),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage(VideoFeedState state) {
    if (state.mode == FeedMode.home &&
        state.error == VideoFeedError.noFollowedUsers) {
      return 'No followed users.\nFollow someone to see their videos here.';
    }
    return 'No videos found for ${state.mode.name} feed.';
  }
}

/// A video feed item that uses [PooledVideoPlayer] for playback.
///
/// This widget renders video content with automatic controller management
/// from the pool, plus the full overlay UI with author info, actions, etc.
class _PooledVideoFeedItem extends ConsumerWidget {
  const _PooledVideoFeedItem({
    required this.video,
    required this.index,
    required this.isActive,
    this.contextTitle,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final String? contextTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesRepository = ref.read(likesRepositoryProvider);
    final commentsRepository = ref.read(commentsRepositoryProvider);
    final repostsRepository = ref.read(repostsRepositoryProvider);

    // Build addressable ID for reposts if video has a d-tag (vineId)
    final addressableId = video.addressableId;

    return BlocProvider<VideoInteractionsBloc>(
      create: (_) =>
          VideoInteractionsBloc(
              eventId: video.id,
              authorPubkey: video.pubkey,
              likesRepository: likesRepository,
              commentsRepository: commentsRepository,
              repostsRepository: repostsRepository,
              addressableId: addressableId,
              initialLikeCount: video.nostrLikeCount != null
                  ? video.totalLikes
                  : null,
            )
            ..add(const VideoInteractionsSubscriptionRequested())
            ..add(const VideoInteractionsFetchRequested()),
      child: _PooledVideoFeedItemContent(
        video: video,
        index: index,
        isActive: isActive,
        contextTitle: contextTitle,
      ),
    );
  }
}

class _PooledVideoFeedItemContent extends StatefulWidget {
  const _PooledVideoFeedItemContent({
    required this.video,
    required this.index,
    required this.isActive,
    this.contextTitle,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final String? contextTitle;

  @override
  State<_PooledVideoFeedItemContent> createState() =>
      _PooledVideoFeedItemContentState();
}

class _PooledVideoFeedItemContentState
    extends State<_PooledVideoFeedItemContent> {
  bool _contentWarningRevealed = false;

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    // All videos without dimensions are treated as portrait as its default
    // usecase (e.g. Reels-style vertical videos).
    final isPortrait = video.dimensions != null ? video.isPortrait : true;
    final showWarning = video.shouldShowWarning && !_contentWarningRevealed;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          PooledVideoPlayer(
            index: widget.index,
            thumbnailUrl: video.thumbnailUrl,
            enableTapToPause: widget.isActive && !showWarning,
            videoBuilder: (context, videoController, player) =>
                _FittedVideoPlayer(
                  videoController: videoController,
                  isPortrait: isPortrait,
                ),
            loadingBuilder: (context) => _VideoLoadingPlaceholder(
              thumbnailUrl: video.thumbnailUrl,
              isPortrait: isPortrait,
            ),
            overlayBuilder: (context, videoController, player) =>
                FeedVideoOverlay(
                  video: video,
                  isActive: widget.isActive,
                  player: player,
                ),
          ),
          if (showWarning)
            _FeedContentWarningOverlay(
              labels: video.warnLabels,
              thumbnailUrl: video.thumbnailUrl,
              onReveal: () => setState(() => _contentWarningRevealed = true),
            ),
        ],
      ),
    );
  }
}

class _FittedVideoPlayer extends StatelessWidget {
  const _FittedVideoPlayer({
    required this.videoController,
    this.isPortrait = true,
  });

  final VideoController videoController;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    // Portrait: fill screen (cover), Landscape: fit entirely (contain)
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    return Video(
      controller: videoController,
      fit: boxFit,
      filterQuality: FilterQuality.high,
      controls: NoVideoControls,
    );
  }
}

class _VideoLoadingPlaceholder extends StatelessWidget {
  const _VideoLoadingPlaceholder({this.thumbnailUrl, this.isPortrait = true});

  final String? thumbnailUrl;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl == null) {
      return const _LoadingIndicator();
    }

    // Portrait: fill height, crop sides (cover)
    // Landscape: fit entirely, centered (contain)
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    return SizedBox.expand(
      child: Image.network(
        thumbnailUrl!,
        fit: boxFit,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => const _LoadingIndicator(),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: VineTheme.vineGreen),
    );
  }
}

/// Content warning overlay for the new feed.
///
/// Shows a blurred thumbnail with warning text and a "View Anyway" button.
/// Uses a thumbnail image as the blur source so the overlay works even
/// before the video has loaded (BackdropFilter on a black screen = black).
class _FeedContentWarningOverlay extends StatelessWidget {
  const _FeedContentWarningOverlay({
    required this.labels,
    required this.onReveal,
    this.thumbnailUrl,
  });

  final List<String> labels;
  final VoidCallback onReveal;
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred thumbnail as background (ensures blur is always visible)
          if (thumbnailUrl != null)
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Image.network(
                thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Colors.black,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          // Dark tint + content
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFB84D),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sensitive Content',
                      style: TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels.map(_humanize).join(', '),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: onReveal,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VineTheme.whiteText,
                        side: const BorderSide(color: VineTheme.onSurfaceMuted),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('View Anyway'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _humanize(String label) {
    switch (label) {
      case 'nudity':
        return 'Nudity';
      case 'sexual':
        return 'Sexual Content';
      case 'porn':
        return 'Pornography';
      case 'graphic-media':
        return 'Graphic Media';
      case 'violence':
        return 'Violence';
      case 'self-harm':
        return 'Self-Harm';
      case 'drugs':
        return 'Drug Use';
      case 'alcohol':
        return 'Alcohol';
      case 'tobacco':
        return 'Tobacco';
      case 'gambling':
        return 'Gambling';
      case 'profanity':
        return 'Profanity';
      case 'flashing-lights':
        return 'Flashing Lights';
      case 'ai-generated':
        return 'AI-Generated';
      case 'spoiler':
        return 'Spoiler';
      case 'content-warning':
        return 'Sensitive Content';
      default:
        return 'Content Warning';
    }
  }
}
