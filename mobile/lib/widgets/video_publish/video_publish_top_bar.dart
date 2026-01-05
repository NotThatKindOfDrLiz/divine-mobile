// ABOUTME: Top navigation bar for video publish screen
// ABOUTME: Contains back button and publish button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/video_editor/video_editor_icon_button.dart';

/// Top navigation bar with back and publish buttons.
class VideoPublishTopBar extends ConsumerWidget {
  /// Creates a video publish top bar.
  const VideoPublishTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            // Back button
            VideoEditorIconButton(
              icon: Icons.arrow_back,
              onTap: context.pop,
            ),
            // Publish button
            VideoEditorIconButton(
              icon: Icons.send,
              backgroundColor: VineTheme.tabIndicatorGreen,
              onTap: () {
                // TODO(@hm21): Implement publish
              },
            ),
          ],
        ),
      ),
    );
  }
}
