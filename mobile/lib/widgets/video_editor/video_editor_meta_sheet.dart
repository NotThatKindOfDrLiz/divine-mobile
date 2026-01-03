// ABOUTME: Bottom sheet widget for editing video metadata.
// ABOUTME: Provides input fields for title, description, and topics.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet widget for editing video metadata.
///
/// Displays form fields for video title, description, and topics with
/// Material 3 styling and rounded top corners.
class VideoEditorMetaSheet extends ConsumerStatefulWidget {
  /// Creates a video metadata editing sheet.
  const VideoEditorMetaSheet({super.key});

  @override
  ConsumerState<VideoEditorMetaSheet> createState() =>
      _VideoEditorMetaSheetState();
}

class _VideoEditorMetaSheetState extends ConsumerState<VideoEditorMetaSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _topicsController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _topicsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top bar with title and more button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Untitled video',
                      style: TextStyle(
                        fontFamily: 'BricolageGrotesque',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        height: 24 / 18,
                        letterSpacing: 0.15,
                        color: Colors.white,
                        fontVariations: [
                          FontVariation('opsz', 14),
                          FontVariation('wdth', 100),
                        ],
                      ),
                    ),
                    Text(
                      '5.73s',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        height: 20 / 14,
                        letterSpacing: 0.25,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(1, 1),
                      blurRadius: 1,
                    ),
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(0.4, 0.4),
                      blurRadius: 0.6,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.more_horiz,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Title field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildInputField(
            label: 'Title',
            placeholder: 'Add a title...',
            controller: _titleController,
          ),
        ),

        const SizedBox(height: 16),

        // Description field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildInputField(
            label: 'Description',
            placeholder: 'Add a Description...',
            controller: _descriptionController,
          ),
        ),

        const SizedBox(height: 16),

        // Topics field with add button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Topics',
                  placeholder: 'Add a Topic...',
                  controller: _topicsController,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(1, 1),
                      blurRadius: 1,
                    ),
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(0.4, 0.4),
                      blurRadius: 0.6,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  /// Builds an input field with label and placeholder styling.
  Widget _buildInputField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF070708),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'BricolageGrotesque',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: 0.1,
              color: Colors.white.withOpacity(0.5),
              fontVariations: const [
                FontVariation('opsz', 14),
                FontVariation('wdth', 100),
              ],
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 18,
              height: 24 / 18,
              letterSpacing: 0.15,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 18,
                height: 24 / 18,
                letterSpacing: 0.15,
                color: Colors.white.withOpacity(0.25),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
