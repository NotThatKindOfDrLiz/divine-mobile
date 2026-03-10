part of 'share_action_button.dart';

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _DragIndicator extends StatelessWidget {
  const _DragIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: VineTheme.secondaryText,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ShareSheetHeader extends StatelessWidget {
  const _ShareSheetHeader({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    context.read<ProfilesBloc>().add(ProfileRequested(pubkey: video.pubkey));
    final profile = context.select<ProfilesBloc, UserProfile?>(
      (bloc) => bloc.state.profiles[video.pubkey],
    );

    final videoTitle = video.title?.isNotEmpty == true
        ? video.title!
        : video.content;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        spacing: 12,
        children: [
          UserAvatar(
            imageUrl: profile?.picture,
            name: profile?.displayName,
            size: 40,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (videoTitle.isNotEmpty)
                  Text(
                    videoTitle,
                    style: const TextStyle(
                      color: VineTheme.whiteText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                UserName.fromPubKey(
                  video.pubkey,
                  style: const TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 40,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: VideoThumbnailWidget(video: video, width: 40, height: 56),
            ),
          ),
        ],
      ),
    );
  }
}
