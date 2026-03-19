// ABOUTME: Rich video preview card for shared videos in DM conversations.
// ABOUTME: Fetches video metadata by event ID and renders a tappable thumbnail
// ABOUTME: with title and loop count overlay per the Figma design.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// A tappable video thumbnail card shown in DM conversations when a user
/// shares a video. Fetches the [VideoEvent] by its Nostr event ID and
/// displays a thumbnail with title and loop count overlay.
///
/// Falls back to a simple text placeholder if the video cannot be loaded.
class SharedVideoBubble extends ConsumerStatefulWidget {
  const SharedVideoBubble({
    required this.videoEventId,
    required this.timestamp,
    required this.isSent,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    super.key,
  });

  final String videoEventId;
  final String timestamp;
  final bool isSent;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  @override
  ConsumerState<SharedVideoBubble> createState() => _SharedVideoBubbleState();
}

class _SharedVideoBubbleState extends ConsumerState<SharedVideoBubble> {
  VideoEvent? _video;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    // Try cache first.
    final videoEventService = ref.read(videoEventServiceProvider);
    final cached = videoEventService.getVideoById(widget.videoEventId);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _video = cached;
          _isLoading = false;
        });
      }
      return;
    }

    // Fetch from relay.
    try {
      final nostrService = ref.read(nostrServiceProvider);
      final event = await nostrService.fetchEventById(widget.videoEventId);
      if (event != null && mounted) {
        setState(() {
          _video = VideoEvent.fromNostrEvent(event);
          _isLoading = false;
        });
        return;
      }
    } catch (_) {
      // Fall through to error state.
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: widget.isFirstInGroup ? 8 : 2,
        bottom: widget.isLastInGroup ? 8 : 2,
      ),
      child: Align(
        alignment: widget.isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isSent
                ? VineTheme.primaryAccessible
                : VineTheme.containerLow,
            borderRadius: _borderRadius,
          ),
          child: Column(
            crossAxisAlignment: widget.isSent
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (widget.isFirstInGroup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    widget.timestamp,
                    style: VineTheme.labelSmallFont(
                      color: VineTheme.onSurfaceMuted,
                    ),
                  ),
                ),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const _ThumbnailPlaceholder();
    }

    if (_hasError || _video == null) {
      return const _ErrorPlaceholder();
    }

    return _VideoCard(
      video: _video!,
      onTap: () => context.push(
        VideoDetailScreen.pathForId(widget.videoEventId),
      ),
    );
  }

  BorderRadius get _borderRadius {
    if (!widget.isLastInGroup) {
      return BorderRadius.circular(16);
    }
    return BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(widget.isSent ? 16 : 4),
      bottomRight: Radius.circular(widget.isSent ? 4 : 16),
    );
  }
}

/// Tappable video thumbnail with gradient metadata overlay.
class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.onTap});

  final VideoEvent video;
  final VoidCallback onTap;

  static const _thumbnailWidth = 248.0;
  static const _thumbnailHeight = 351.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: _thumbnailWidth,
          height: _thumbnailHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoThumbnailWidget(
                video: video,
                width: _thumbnailWidth,
                height: _thumbnailHeight,
              ),
              _MetadataOverlay(video: video),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom gradient overlay showing video title and loop count.
class _MetadataOverlay extends StatelessWidget {
  const _MetadataOverlay({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final title = video.title;
    final loops = video.originalLoops;

    if (title == null && loops == null) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x00000000),
              Color(0x3D000000), // 24% black
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              if (title != null && title.isNotEmpty)
                Text(
                  title,
                  style: VineTheme.labelMediumFont(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (loops != null)
                Text(
                  _formatLoops(loops),
                  style: VineTheme.bodySmallFont(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatLoops(int loops) {
    if (loops >= 1000000) {
      final m = loops / 1000000;
      return '${m.toStringAsFixed(m < 10 ? 1 : 0)}m loops';
    }
    if (loops >= 1000) {
      final k = loops / 1000;
      return '${k.toStringAsFixed(k < 10 ? 1 : 0)}k loops';
    }
    return '$loops loops';
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 248,
        height: 351,
        color: VineTheme.surfaceContainer,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VineTheme.onSurfaceMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 248,
        height: 160,
        color: VineTheme.surfaceContainer,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: VineTheme.onSurfaceMuted,
                size: 32,
              ),
              Text(
                'Video unavailable',
                style: VineTheme.bodySmallFont(
                  color: VineTheme.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
