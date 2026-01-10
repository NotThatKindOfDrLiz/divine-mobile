// ABOUTME: Shared renderer for video tiles to ensure consistent visuals
import 'package:flutter/material.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/user_name.dart';

/// Renders a consistent video tile.
Widget sharedVideoTile(
  BuildContext context, {
  required VideoEvent video,
  required double aspectRatio,
  required VoidCallback onTap,
  VoidCallback? onLongPress,
  Widget? badge,
  bool showInfo = false,
  double cornerRadius = 4,
}) {
  return GestureDetector(
    onTap: onTap,
    onLongPress: onLongPress,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cornerRadius),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: video.thumbnailUrl != null
                    ? VideoThumbnailWidget(video: video)
                    : Container(color: VineTheme.cardBackground),
              ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.play_circle_filled,
              color: Colors.white70,
              size: 32,
            ),
          ),
          if (badge != null) Positioned(top: 6, right: 6, child: badge),
          if (showInfo)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                color: VineTheme.cardBackground,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserName.fromPubKey(video.pubkey, maxLines: 1),
                    Text(
                      video.title ?? video.content,
                      style: TextStyle(
                        color: VineTheme.primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
