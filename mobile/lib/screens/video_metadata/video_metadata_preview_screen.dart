import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/divine_icon_button.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_bottom_bar.dart';
import 'package:video_player/video_player.dart';

class VideoMetadataPreviewScreen extends ConsumerStatefulWidget {
  const VideoMetadataPreviewScreen({super.key, required this.clip});

  final RecordingClip clip;

  @override
  ConsumerState<VideoMetadataPreviewScreen> createState() =>
      _VideoMetadataPreviewScreenState();
}

class _VideoMetadataPreviewScreenState
    extends ConsumerState<VideoMetadataPreviewScreen> {
  /// Video player controller for the clip, null until initialized.
  VideoPlayerController? _controller;

  /// Whether the video player has completed initialization and is ready to play.
  bool _isInitialized = false;
  final _isPreviewReady = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _initializePlayer();

    // Before displaying the overlay, we wait for the hero animation to finish.
    Future.delayed(Duration(milliseconds: 350), () {
      if (mounted) _isPreviewReady.value = true;
    });
  }

  /// Initializes the video player and starts playback.
  ///
  /// Checks if the video file exists, creates a [VideoPlayerController],
  /// initializes it, enables looping, and starts playback automatically.
  /// Updates [_isInitialized] when complete.
  Future<void> _initializePlayer() async {
    final file = File(await widget.clip.video.safeFilePath());
    if (!await file.exists()) {
      return;
    }

    if (mounted) _controller = VideoPlayerController.file(file);
    if (mounted) await _controller!.initialize();
    if (mounted) await _controller!.setLooping(true);
    if (mounted) await _controller!.play();

    if (mounted) {
      _isInitialized = true;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _isPreviewReady.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000A06),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: .expand,
              children: [
                _VideoPreviewContent(
                  clip: widget.clip,
                  controller: _controller,
                  isInitialized: _isInitialized,
                  isPreviewReady: _isPreviewReady,
                ),
                _CloseButton(),
              ],
            ),
          ),
          SafeArea(top: false, child: VideoMetadataBottomBar()),
        ],
      ),
    );
  }
}

class _VideoPreviewContent extends ConsumerWidget {
  const _VideoPreviewContent({
    required this.clip,
    required this.controller,
    required this.isInitialized,
    required this.isPreviewReady,
  });

  final RecordingClip clip;
  final VideoPlayerController? controller;
  final bool isInitialized;
  final ValueNotifier<bool> isPreviewReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Hero(
      tag: 'Video-metadata-clip-preview-video',
      child: Stack(
        fit: .expand,
        children: [
          _VideoPlayerWidget(
            clip: clip,
            controller: controller,
            isInitialized: isInitialized,
          ),
          _PreviewOverlay(isPreviewReady: isPreviewReady),
        ],
      ),
    );
  }
}

class _VideoPlayerWidget extends StatelessWidget {
  const _VideoPlayerWidget({
    required this.clip,
    required this.controller,
    required this.isInitialized,
  });

  final RecordingClip clip;
  final VideoPlayerController? controller;
  final bool isInitialized;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: clip.aspectRatio.value,
        child: ClipRRect(
          borderRadius: .circular(16),
          child: Stack(
            fit: .expand,
            children: [
              if (clip.thumbnailPath != null)
                Image.file(File(clip.thumbnailPath!), fit: .cover),
              AnimatedSwitcher(
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: .center,
                  fit: .expand,
                  children: <Widget>[...previousChildren, ?currentChild],
                ),
                switchInCurve: Curves.easeInOut,
                duration: Duration(milliseconds: 120),
                child: isInitialized && controller != null
                    ? FittedBox(
                        fit: .cover,
                        clipBehavior: .hardEdge,
                        child: SizedBox(
                          width: controller!.value.size.width,
                          height: controller!.value.size.height,
                          child: VideoPlayer(controller!),
                        ),
                      )
                    : SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewOverlay extends ConsumerWidget {
  const _PreviewOverlay({required this.isPreviewReady});

  final ValueNotifier<bool> isPreviewReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = ref.watch(
      videoEditorProvider.select(
        (s) => (title: s.title, description: s.description, tags: s.tags),
      ),
    );

    final publicKey = ref.watch(
      nostrServiceProvider.select((s) => s.publicKey),
    );

    return IgnorePointer(
      child: Opacity(
        opacity: 0.5,
        child: ValueListenableBuilder(
          valueListenable: isPreviewReady,
          builder: (_, isActive, _) {
            return VideoOverlayActions(
              video: VideoEvent(
                id: 'id',
                pubkey: publicKey,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                content: metadata.title,
                hashtags: metadata.tags.toList(),
                timestamp: DateTime.now(),
                originalLikes: 1,
                originalComments: 1,
                originalReposts: 1,
                isFlaggedContent: false,
              ),
              isVisible: true,
              isActive: isActive,
              isPreviewMode: true,
            );
          },
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 6,
      left: 6,
      child: SafeArea(
        child: DivineIconButton(
          backgroundColor: const Color(0x0F000000),
          // TODO(l10n): Replace with context.l10n when localization is added.
          semanticLabel: 'Close video recorder',
          iconPath: 'assets/icon/close.svg',
          onTap: () => context.pop(),
        ),
      ),
    );
  }
}
