// ABOUTME: Share action button for video feed overlay.
// ABOUTME: Displays share icon with label, shows share menu bottom sheet.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/share_video_menu.dart';

/// Share action button with label for video overlay.
///
/// Shows a share icon that opens the share menu bottom sheet.
/// Video playback is automatically paused while the menu is open via
/// [showVideoPausingVineBottomSheet] and the overlay visibility provider.
class ShareActionButton extends StatelessWidget {
  const ShareActionButton({required this.video, this.onPressed, super.key});

  final VideoEvent video;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final handler = onPressed ?? () => _showShareMenu(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'share_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: 'Share video',
          child: IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            style: IconButton.styleFrom(
              highlightColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: () {
              if (onPressed == null) {
                Log.info(
                  '📤 Share button tapped for ${video.id}',
                  name: 'ShareActionButton',
                  category: LogCategory.ui,
                );
              }
              handler();
            },
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
                'assets/icon/content-controls/share.svg',
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
      ],
    );
  }

  Future<void> _showShareMenu(BuildContext context) async {
    // Video pause/resume handled by overlay visibility provider
    await context.showVideoPausingVineBottomSheet<void>(
      builder: (context) => ShareVideoMenu(video: video),
    );
  }
}
