// ABOUTME: Video metadata editing screen for post details, title, description, tags and expiration
// ABOUTME: Implements Figma design 1:1 with custom widget classes

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/divine_text_field.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_expiration_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_tags_input.dart';
import '../theme/vine_theme.dart';

class VideoMetadataScreen extends ConsumerStatefulWidget {
  const VideoMetadataScreen({super.key});

  @override
  ConsumerState<VideoMetadataScreen> createState() =>
      _VideoMetadataScreenState();
}

class _VideoMetadataScreenState extends ConsumerState<VideoMetadataScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF000A06),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            padding: const .all(8),
            icon: SizedBox(
              width: 32,
              height: 32,
              child: SvgPicture.asset(
                'assets/icon/CaretLeft.svg',
                width: 32,
                height: 32,
                colorFilter: const .mode(Colors.white, .srcIn),
              ),
            ),
            onPressed: () => context.pop(),
            tooltip: 'Back',
          ),
          title: Text(
            'Post details',
            style: GoogleFonts.bricolageGrotesque(
              color: VineTheme.onSurface,
              fontSize: 18,
              fontWeight: .w800,
              height: 1.33,
              letterSpacing: 0.15,
            ),
          ),
        ),
        body: LayoutBuilder(
          builder: (_, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: .min,
                      crossAxisAlignment: .stretch,
                      children: [
                        // TODO: VideoPreviewWidget(videoPath: widget.videoPath),
                        Placeholder(fallbackHeight: 200),
                        const SizedBox(height: 32),

                        DivineTextField(
                          controller: _titleController,
                          label: 'Title',
                          focusNode: _titleFocusNode,
                          textInputAction: .next,
                          onChanged: (value) => ref
                              .read(videoEditorProvider.notifier)
                              .updateMetadata(title: value),
                          onSubmitted: (_) =>
                              _descriptionFocusNode.requestFocus(),
                        ),

                        const _Divider(),

                        DivineTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          focusNode: _descriptionFocusNode,
                          keyboardType: .multiline,
                          textInputAction: .newline,
                          onChanged: (value) => ref
                              .read(videoEditorProvider.notifier)
                              .updateMetadata(description: value),
                        ),

                        const _Divider(),

                        const VideoMetadataTagsInput(),

                        const _Divider(),

                        const VideoMetadataExpirationSelector(),
                      ],
                    ),
                    VideoMetadataBottomBar(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(thickness: 0, height: 1, color: Color(0xFF001A12));
  }
}
