import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/providers/video_editor_provider.dart';

class VideoMetadataBottomBar extends ConsumerWidget {
  const VideoMetadataBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValidToPost = ref.watch(
      videoEditorProvider.select((s) => s.isValidToPost),
    );

    return Padding(
      padding: .fromLTRB(16, 16, 16, 4),
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 200),
        opacity: isValidToPost ? 1 : 0.32,
        child: Row(
          spacing: 16,
          children: [
            Expanded(child: _SaveDraftButton()),
            Expanded(child: _PostButton()),
          ],
        ),
      ),
    );
  }
}

// Save draft button (outlined)
class _SaveDraftButton extends ConsumerWidget {
  const _SaveDraftButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValidToPost = ref.watch(
      videoEditorProvider.select((s) => s.isValidToPost),
    );

    return Semantics(
      label: 'Save draft button',
      hint: isValidToPost
          ? 'Save video as draft'
          : 'Fill out the form to enable',
      button: true,
      enabled: isValidToPost,
      child: GestureDetector(
        onTap: isValidToPost
            ? ref.read(videoEditorProvider.notifier).postVideo
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF032017),
            border: .all(color: const Color(0xFF27C58B), width: 2),
            borderRadius: .circular(20),
          ),
          padding: const .symmetric(vertical: 10),
          child: Center(
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

// Post button (filled)
class _PostButton extends ConsumerWidget {
  const _PostButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValidToPost = ref.watch(
      videoEditorProvider.select((s) => s.isValidToPost),
    );

    return Semantics(
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
    );
  }
}
