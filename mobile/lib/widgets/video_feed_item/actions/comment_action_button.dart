// ABOUTME: Comment action button for video feed overlay.
// ABOUTME: Displays comment icon with count, navigates to comments screen.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Comment action button with count display for video overlay.
///
/// Shows a comment icon that navigates to the comments screen.
/// Pauses the video before navigation and displays the comment count.
class CommentActionButton extends ConsumerWidget {
  const CommentActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interactionsBloc = context.read<VideoInteractionsBloc?>();

    if (interactionsBloc != null) {
      return BlocBuilder<VideoInteractionsBloc, VideoInteractionsState>(
        builder: (context, state) {
          final totalComments =
              state.commentCount ?? video.originalComments ?? 0;
          return _buildButton(context, ref, totalComments);
        },
      );
    }

    return _buildButton(context, ref, video.originalComments ?? 0);
  }

  Widget _buildButton(BuildContext context, WidgetRef ref, int totalComments) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'comments_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: 'View comments',
          child: IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            style: IconButton.styleFrom(
              highlightColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: () => _onPressed(context, ref, totalComments),
            icon: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: SvgPicture.asset(
                'assets/icon/content-controls/comment.svg',
                width: 32,
                height: 32,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
        if (totalComments > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              StringUtils.formatCompactNumber(totalComments),
              style: const TextStyle(
                fontFamily: 'Bricolage Grotesque',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }

  void _onPressed(
    BuildContext context,
    WidgetRef ref,
    int initialCommentCount,
  ) {
    Log.info(
      '💬 Comment button tapped for ${video.id}',
      name: 'CommentActionButton',
      category: LogCategory.ui,
    );

    // Pause video before navigating to comments
    if (video.videoUrl != null) {
      try {
        final controllerParams = VideoControllerParams(
          videoId: video.id,
          videoUrl: video.getOptimalVideoUrlForPlatform() ?? video.videoUrl!,
          cacheUrl: video.videoUrl,
          videoEvent: video,
        );
        final controller = ref.read(
          individualVideoControllerProvider(controllerParams),
        );
        if (controller.value.isInitialized && controller.value.isPlaying) {
          // Use safePause to handle disposed controller
          safePause(controller, video.id);
        }
      } catch (e) {
        // Ignore disposal errors, log others
        final errorStr = e.toString().toLowerCase();
        if (!errorStr.contains('no active player') &&
            !errorStr.contains('disposed')) {
          Log.error(
            'Failed to pause video before comments: $e',
            name: 'CommentActionButton',
            category: LogCategory.video,
          );
        }
      }
    }

    CommentsScreen.show(
      context,
      video,
      initialCommentCount: initialCommentCount,
    );
  }
}
