import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/models/video_metadata/video_metadata_expiration.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/bottom_sheets/vine_bottom_sheet_drag_handle.dart';

class VideoMetadataExpirationSelector extends ConsumerWidget {
  const VideoMetadataExpirationSelector({super.key});
  void _selectExpiration(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.surfaceBackground,
      builder: (context) => const _ExpirationOptionsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentOption = ref.watch(
      videoEditorProvider.select((s) => s.expiration),
    );

    return Semantics(
      button: true,
      label: 'Select expiration time',
      child: InkWell(
        onTap: () => _selectExpiration(context),
        child: Padding(
          padding: const .all(16),
          child: Column(
            spacing: 8,
            crossAxisAlignment: .stretch,
            children: [
              Text(
                'Expiration',
                style: GoogleFonts.inter(
                  color: const Color(0xBFFFFFFF),
                  fontSize: 11,
                  fontWeight: .w600,
                  height: 1.45,
                  letterSpacing: 0.50,
                ),
              ),
              Row(
                mainAxisAlignment: .spaceBetween,
                crossAxisAlignment: .center,
                children: [
                  Flexible(
                    child: Text(
                      currentOption.description,
                      style: VineTheme.titleFont(
                        fontSize: 18,
                        color: const Color(0xF2FFFFFF),
                        letterSpacing: 0.15,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: SvgPicture.asset(
                      'assets/icon/caret_right.svg',
                      colorFilter: ColorFilter.mode(
                        VineTheme.tabIndicatorGreen,
                        .srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bottom sheet for expiration options
class _ExpirationOptionsBottomSheet extends ConsumerWidget {
  const _ExpirationOptionsBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentOption = ref.watch(
      videoEditorProvider.select((s) => s.expiration),
    );

    return Column(
      mainAxisSize: .min,
      spacing: 16,
      children: [
        const Padding(
          padding: .only(top: 8),
          child: VineBottomSheetDragHandle(),
        ),
        Text(
          'Expiration',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
            fontWeight: .w800,
            color: Colors.white,
            height: 1.33,
            letterSpacing: 0.15,
          ),
        ),
        SingleChildScrollView(
          child: Column(
            mainAxisSize: .min,
            children: VideoMetadataExpiration.values.map((option) {
              final isSelected = option == currentOption;

              return ListTile(
                selected: isSelected,
                selectedTileColor: Color(0xFF032017),
                title: Text(
                  option.description,
                  style: GoogleFonts.bricolageGrotesque(
                    color: VineTheme.onSurface,
                    fontSize: 18,
                    fontWeight: .w800,
                    height: 1.33,
                    letterSpacing: 0.15,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 24,
                        color: Color(0xFF27C58B),
                      )
                    : null,
                onTap: () {
                  ref.read(videoEditorProvider.notifier).setExpiration(option);
                  context.pop();
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
