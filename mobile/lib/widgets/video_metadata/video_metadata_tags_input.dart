import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/divine_text_field.dart';

class VideoMetadataTagsInput extends ConsumerStatefulWidget {
  const VideoMetadataTagsInput({super.key});

  @override
  ConsumerState<VideoMetadataTagsInput> createState() =>
      _VideoMetadataTagsInputState();
}

class _VideoMetadataTagsInputState
    extends ConsumerState<VideoMetadataTagsInput> {
  static int tagLimit = 10;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTagChanges(String value, {bool isSubmitted = false}) {
    // Only process if value contains whitespace
    if ((isSubmitted && value.trim().isEmpty) ||
        (!isSubmitted && !value.contains(RegExp(r'\s')))) {
      return;
    }

    // For the case the user copy/paste multiple tags, we need to extract
    // them separate.
    final Set<String> newTags = value
        .split(RegExp(r'\s+'))
        .map((tag) => tag.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''))
        .where((tag) => tag.isNotEmpty)
        .toSet();

    final oldTags = ref.read(videoEditorProvider).tags;
    ref
        .read(videoEditorProvider.notifier)
        .updateMetadata(tags: {...oldTags, ...newTags});
    _controller.clear();
    // Keep focus to prevent keyboard from closing
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = VineTheme.bodyFont(
      color: _focusNode.hasFocus ? const Color(0xFF27C58B) : Color(0xB6FFFFFF),
      fontSize: 11,
      fontWeight: .w600,
      height: 1.45,
      letterSpacing: 0.5,
    );

    final tags = ref.watch(videoEditorProvider.select((s) => s.tags));

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      behavior: .opaque,
      child: Padding(
        padding: const .all(16),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 12,
          children: [
            if (tags.isNotEmpty)
              Row(
                crossAxisAlignment: .center,
                mainAxisAlignment: .spaceBetween,
                children: [
                  Flexible(child: Text('Tags', style: labelStyle)),
                  Text(
                    '${tags.length}/$tagLimit',
                    style: labelStyle.copyWith(color: Color(0x80FFFFFF)),
                  ),
                ],
              ),
            _TagInputLayout(
              spacing: 8,
              runSpacing: 8,
              minTextFieldWidth: 100.0,
              tagCount: tags.length,
              children: [
                ...tags.map((tag) => _TagChip(tag: tag)),
                if (tags.length < tagLimit)
                  DivineTextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    label: tags.isEmpty ? 'Tags' : null,
                    contentPadding: .zero,
                    textCapitalization: .none,
                    textInputAction: .done,
                    maxLines: 1,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9\s]'),
                      ),
                    ],
                    onChanged: _handleTagChanges,
                    onSubmitted: (value) =>
                        _handleTagChanges(value, isSubmitted: true),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends ConsumerWidget {
  const _TagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: .symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: .circular(16),
        color: Color(0xFF032017),
      ),
      child: Row(
        mainAxisSize: .min,
        crossAxisAlignment: .center,
        children: [
          Text(
            '#',
            style: VineTheme.bodyFont(
              color: const Color(0xFF27C58B),
              fontSize: 16,
              fontWeight: .w400,
              height: 1.50,
              letterSpacing: 0.15,
            ),
          ),
          SizedBox(width: 4),
          Text(
            tag,
            overflow: .ellipsis,
            style: GoogleFonts.bricolageGrotesque(
              color: VineTheme.onSurface,
              fontSize: 14,
              fontWeight: .w800,
              height: 1.43,
              letterSpacing: 0.10,
            ),
          ),
          SizedBox(width: 8),
          Semantics(
            label: 'Delete',
            hint: 'Delete Tag $tag',
            button: true,
            child: GestureDetector(
              onTap: () =>
                  ref.read(videoEditorProvider.notifier).removeTag(tag),
              child: SizedBox(
                width: 16,
                height: 16,
                child: SvgPicture.asset(
                  'assets/icon/close.svg',
                  colorFilter: const .mode(Color(0xFF818F8B), .srcIn),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A custom layout widget that wraps children like Wrap but gives the last child
/// (the text field) the remaining width in the current row.
class _TagInputLayout extends MultiChildRenderObjectWidget {
  final double spacing;
  final double runSpacing;
  final int tagCount;
  final double minTextFieldWidth;

  const _TagInputLayout({
    required this.spacing,
    required this.runSpacing,
    required this.tagCount,
    required this.minTextFieldWidth,
    required List<Widget> children,
  }) : super(children: children);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderTagInputLayout(
      spacing: spacing,
      runSpacing: runSpacing,
      tagCount: tagCount,
      minTextFieldWidth: minTextFieldWidth,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTagInputLayout renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..tagCount = tagCount
      ..minTextFieldWidth = minTextFieldWidth;
  }
}

class _TagInputLayoutParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTagInputLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TagInputLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TagInputLayoutParentData> {
  double _spacing;
  double _runSpacing;
  int _tagCount;
  double _minTextFieldWidth;

  _RenderTagInputLayout({
    required double spacing,
    required double runSpacing,
    required int tagCount,
    required double minTextFieldWidth,
  }) : _spacing = spacing,
       _runSpacing = runSpacing,
       _tagCount = tagCount,
       _minTextFieldWidth = minTextFieldWidth;

  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing != value) {
      _spacing = value;
      markNeedsLayout();
    }
  }

  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing != value) {
      _runSpacing = value;
      markNeedsLayout();
    }
  }

  int get tagCount => _tagCount;
  set tagCount(int value) {
    if (_tagCount != value) {
      _tagCount = value;
      markNeedsLayout();
    }
  }

  double get minTextFieldWidth => _minTextFieldWidth;
  set minTextFieldWidth(double value) {
    if (_minTextFieldWidth != value) {
      _minTextFieldWidth = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TagInputLayoutParentData) {
      child.parentData = _TagInputLayoutParentData();
    }
  }

  @override
  void performLayout() {
    final maxWidth = constraints.maxWidth;
    double x = 0;
    double y = 0;
    double maxHeightInRow = 0;

    // Layout all tag chips first
    RenderBox? child = firstChild;
    int index = 0;
    RenderBox? textFieldChild;

    while (child != null) {
      final parentData = child.parentData! as _TagInputLayoutParentData;

      if (index < tagCount) {
        // Layout chip with loose constraints
        child.layout(BoxConstraints(maxWidth: maxWidth), parentUsesSize: true);

        final childSize = child.size;

        // Check if chip fits in current row
        if (x + childSize.width > maxWidth && x > 0) {
          x = 0;
          y += maxHeightInRow + runSpacing;
          maxHeightInRow = 0;
        }

        parentData.offset = Offset(x, y);
        x += childSize.width + spacing;
        maxHeightInRow = childSize.height > maxHeightInRow
            ? childSize.height
            : maxHeightInRow;
      } else {
        // This is the text field - save for later
        textFieldChild = child;
      }

      child = parentData.nextSibling;
      index++;
    }

    // Now layout and position the text field
    if (textFieldChild != null) {
      final parentData =
          textFieldChild.parentData! as _TagInputLayoutParentData;
      final availableWidth = maxWidth - x;

      double textFieldX;
      double textFieldY;
      double textFieldWidth;

      if (availableWidth >= minTextFieldWidth && x > 0) {
        // Fits in current row
        textFieldX = x;
        textFieldY = y;
        textFieldWidth = availableWidth;
      } else if (x == 0) {
        // Empty row, use full width
        textFieldX = 0;
        textFieldY = y;
        textFieldWidth = maxWidth;
      } else {
        // Move to new row
        y += maxHeightInRow + runSpacing;
        maxHeightInRow = 0;
        textFieldX = 0;
        textFieldY = y;
        textFieldWidth = maxWidth;
      }

      textFieldChild.layout(
        BoxConstraints(minWidth: minTextFieldWidth, maxWidth: textFieldWidth),
        parentUsesSize: true,
      );

      parentData.offset = Offset(textFieldX, textFieldY);
      maxHeightInRow = textFieldChild.size.height > maxHeightInRow
          ? textFieldChild.size.height
          : maxHeightInRow;
    }

    // Calculate final height
    final totalHeight = y + maxHeightInRow;
    size = constraints.constrain(Size(maxWidth, totalHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
