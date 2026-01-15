// ABOUTME: Video metadata editing screen for post details, title, description, tags and expiration
// ABOUTME: Implements Figma design 1:1 with custom widget classes

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_expiration_selector.dart';
import '../theme/vine_theme.dart';

class VideoMetadataScreen extends StatefulWidget {
  const VideoMetadataScreen({super.key});

  @override
  State<VideoMetadataScreen> createState() => _VideoMetadataScreenState();
}

class _VideoMetadataScreenState extends State<VideoMetadataScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  String _expirationOption = 'Does not expire';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    return _titleController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000A06),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          padding: const EdgeInsets.all(8),
          icon: Container(
            width: 32,
            height: 32,
            child: SvgPicture.asset(
              'assets/icon/CaretLeft.svg',
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(Colors.white, .srcIn),
            ),
          ),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: Text(
          'Post details',
          style: TextStyle(
            color: VineTheme.onSurface,
            fontSize: 18,
            fontFamily: 'BricolageGrotesque',
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
                    children: [
                      // TODO: VideoPreviewWidget(videoPath: widget.videoPath),
                      Placeholder(fallbackHeight: 200),
                      const SizedBox(height: 32),
                      MetadataInputFields(
                        titleController: _titleController,
                        descriptionController: _descriptionController,
                        tagsController: _tagsController,
                      ),

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
    );
  }
}

// Input fields section
class MetadataInputFields extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController tagsController;

  const MetadataInputFields({
    required this.titleController,
    required this.descriptionController,
    required this.tagsController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MetadataTextField(controller: titleController, label: 'Title'),
        MetadataTextField(
          controller: descriptionController,
          label: 'Description',
        ),
        MetadataTextField(controller: tagsController, label: 'Tags'),
      ],
    );
  }
}

// Custom text field matching Figma design
class MetadataTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const MetadataTextField({
    required this.controller,
    required this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF001A12), // outline-disabled
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: controller,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 24 / 16,
            color: VineTheme.onSurface,
            letterSpacing: 0.15,
          ),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: .w400,
              height: 24 / 16,
              color: const Color(0x80FFFFFF), // rgba(255,255,255,0.5)
              letterSpacing: 0.15,
            ),
            border: .none,
            contentPadding: .zero,
            isDense: true,
          ),
        ),
      ),
    );
  }
}
