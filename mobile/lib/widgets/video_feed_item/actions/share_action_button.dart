// ABOUTME: Share action button for video feed overlay.
// ABOUTME: Displays share icon, opens simplified share bottom sheet.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:share_plus/share_plus.dart';

/// Share action button for video overlay.
///
/// Shows a share icon that opens a simplified share bottom sheet with:
/// Share with user, Add to list, Add to bookmarks, More options (native share).
class ShareActionButton extends StatelessWidget {
  const ShareActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
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
              Log.info(
                'Share button tapped for ${video.id}',
                name: 'ShareActionButton',
                category: LogCategory.ui,
              );
              context.showVideoPausingVineBottomSheet<void>(
                builder: (context) => _SimpleShareMenu(video: video),
              );
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
              child: const DivineIcon(
                icon: DivineIconName.shareFat,
                size: 32,
                color: VineTheme.whiteText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SimpleShareMenu extends ConsumerStatefulWidget {
  const _SimpleShareMenu({required this.video});

  final VideoEvent video;

  @override
  ConsumerState<_SimpleShareMenu> createState() => _SimpleShareMenuState();
}

class _SimpleShareMenuState extends ConsumerState<_SimpleShareMenu> {
  void _safePop(BuildContext ctx) {
    if (ctx.canPop()) {
      ctx.pop();
    } else {
      Navigator.of(ctx).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VineTheme.surfaceBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(color: VineTheme.cardBackground, height: 1),
            _buildMenuItems(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final profileAsync = ref.watch(
      userProfileReactiveProvider(widget.video.pubkey),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          profileAsync.when(
            data: (profile) => UserAvatar(
              imageUrl: profile?.picture,
              name: profile?.displayName,
              size: 40,
            ),
            loading: () => const UserAvatar(size: 40),
            error: (_, __) => const UserAvatar(size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserName.fromPubKey(
                  widget.video.pubkey,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _safePop(context),
            icon: const Icon(Icons.close, color: VineTheme.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Share with user
        _ShareMenuItem(
          icon: const DivineIcon(
            icon: DivineIconName.chat,
            color: VineTheme.whiteText,
          ),
          label: 'Share with user',
          onTap: _handleShareWithUser,
        ),

        // Add to list
        _ShareMenuItem(
          icon: const DivineIcon(
            icon: DivineIconName.listPlus,
            color: VineTheme.whiteText,
          ),
          label: 'Add to list',
          onTap: _handleAddToList,
        ),

        // Add to bookmarks
        _ShareMenuItem(
          icon: const DivineIcon(
            icon: DivineIconName.bookmarkSimple,
            color: VineTheme.whiteText,
          ),
          label: 'Add to bookmarks',
          onTap: _handleAddToBookmarks,
        ),

        // More options (native share)
        _ShareMenuItem(
          icon: const DivineIcon(
            icon: DivineIconName.shareFat,
            color: VineTheme.whiteText,
          ),
          label: 'More options',
          onTap: _handleMoreOptions,
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  void _handleShareWithUser() {
    // Open the full share menu which contains the Send to User dialog
    _safePop(context);
    context.showVideoPausingVineBottomSheet<void>(
      builder: (context) => ShareVideoMenu(video: widget.video),
    );
  }

  void _handleAddToList() {
    // Open the full share menu which contains list management
    _safePop(context);
    context.showVideoPausingVineBottomSheet<void>(
      builder: (context) => ShareVideoMenu(video: widget.video),
    );
  }

  Future<void> _handleAddToBookmarks() async {
    try {
      final bookmarkService = await ref.read(bookmarkServiceProvider.future);
      final success = await bookmarkService.addVideoToGlobalBookmarks(
        widget.video.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Added to bookmarks!' : 'Failed to add bookmark',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        _safePop(context);
      }
    } catch (e) {
      Log.error(
        'Failed to add bookmark: $e',
        name: 'SimpleShareMenu',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add bookmark'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleMoreOptions() async {
    try {
      final sharingService = ref.read(videoSharingServiceProvider);
      final shareText = sharingService.generateShareText(widget.video);

      await SharePlus.instance.share(ShareParams(text: shareText));
    } catch (e) {
      Log.error(
        'Failed to share externally: $e',
        name: 'SimpleShareMenu',
        category: LogCategory.ui,
      );
    }
  }
}

class _ShareMenuItem extends StatelessWidget {
  const _ShareMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
