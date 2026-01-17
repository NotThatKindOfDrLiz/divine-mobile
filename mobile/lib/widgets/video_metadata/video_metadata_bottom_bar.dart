import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/providers/video_editor_provider.dart';

/// Bottom bar with "Save draft" and "Post" buttons for video metadata.
///
/// Buttons are disabled with reduced opacity when metadata is invalid.
class VideoMetadataBottomBar extends StatelessWidget {
  /// Creates a video metadata bottom bar.
  const VideoMetadataBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: .fromLTRB(16, 16, 16, 4),
      child: Row(
        spacing: 16,
        children: [
          Expanded(child: _SaveDraftButton()),
          Expanded(child: _PostButton()),
        ],
      ),
    );
  }
}

/// Outlined button to save the video as a draft.
class _SaveDraftButton extends ConsumerWidget {
  /// Creates a save draft button.
  const _SaveDraftButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Save draft button',
      hint: 'Save video as draft',
      button: true,
      child: GestureDetector(
        onTap: () => ref.read(videoEditorProvider.notifier).saveAsDraft(),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF032017),
            border: .all(color: const Color(0xFF27C58B), width: 2),
            borderRadius: .circular(20),
          ),
          padding: const .symmetric(vertical: 10),
          child: Center(
            // TODO(l10n): Replace with context.l10n when localization is added.
            child: Text(
              'Save draft',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 18,
                fontWeight: .w800,
                color: const Color(0xFF27C58B),
                height: 1.33,
                letterSpacing: 0.15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filled button to publish the video to the feed.
class _PostButton extends ConsumerWidget {
  /// Creates a post button.
  const _PostButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValidToPost = ref.watch(
      videoEditorProvider.select((s) => s.isValidToPost),
    );

    // Fade buttons when form is invalid
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isValidToPost ? 1 : 0.32,
      child: Semantics(
        // TODO(l10n): Replace with context.l10n when localization is added.
        label: 'Post button',
        hint: isValidToPost
            ? 'Publish video to feed'
            : 'Fill out the form to enable',
        button: true,
        enabled: isValidToPost,
        child: GestureDetector(
          onTap: isValidToPost
              ? ref.read(videoEditorProvider.notifier).postVideo
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF27C58B),
              borderRadius: .circular(20),
            ),
            padding: const .symmetric(vertical: 12),
            child: Center(
              // TODO(l10n): Replace with context.l10n when localization is added.
              child: Text(
                'Post',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 18,
                  fontWeight: .w800,
                  color: const Color(0xFF002C1C),
                  height: 1.33,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
