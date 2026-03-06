import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/models/video_editor/selected_audio_track.dart';
import 'package:openvine/screens/video_editor/video_local_audio_timing_screen.dart';
import 'package:openvine/services/video_editor/audio_track_import_service.dart';

/// Upload-first audio chip for the video editor.
///
/// This keeps the editor on the local-audio flow without affecting the
/// recorder's separate sound-picker flow.
class VideoEditorLocalAudioChip extends StatefulWidget {
  const VideoEditorLocalAudioChip({
    required this.videoDuration,
    required this.originalAudioVolume,
    required this.onTrackChanged,
    required this.onOriginalAudioVolumeChanged,
    this.selectedTrack,
    this.onSelectionStarted,
    this.onSelectionEnded,
    this.importService,
    super.key,
  });

  final SelectedAudioTrack? selectedTrack;
  final Duration videoDuration;
  final double originalAudioVolume;
  final ValueChanged<SelectedAudioTrack?> onTrackChanged;
  final ValueChanged<double> onOriginalAudioVolumeChanged;
  final VoidCallback? onSelectionStarted;
  final VoidCallback? onSelectionEnded;
  final AudioTrackImportService? importService;

  @override
  State<VideoEditorLocalAudioChip> createState() =>
      _VideoEditorLocalAudioChipState();
}

class _VideoEditorLocalAudioChipState extends State<VideoEditorLocalAudioChip> {
  late final AudioTrackImportService _importService;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _importService = widget.importService ?? AudioTrackImportService();
  }

  Future<void> _openAudioFlow() async {
    if (_isBusy) return;

    setState(() => _isBusy = true);
    widget.onSelectionStarted?.call();

    SelectedAudioTrack? importedTrack;

    try {
      var track = widget.selectedTrack;
      if (track == null) {
        importedTrack = await _importService.pickAndImport();
        track = importedTrack;
        if (track == null || !mounted) return;
      }
      final trackToEdit = track;

      final result = await Navigator.of(context).push<LocalAudioTimingResult>(
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.transparent,
          pageBuilder: (_, _, _) => VideoLocalAudioTimingScreen(
            track: trackToEdit,
            originalAudioVolume: widget.originalAudioVolume,
            videoDuration: widget.videoDuration,
          ),
        ),
      );

      if (!mounted) return;

      switch (result) {
        case LocalAudioTimingConfirmed(
          :final track,
          :final originalAudioVolume,
        ):
          widget.onTrackChanged(track);
          widget.onOriginalAudioVolumeChanged(originalAudioVolume);
        case LocalAudioTimingDeleted():
          widget.onTrackChanged(null);
        case null:
          if (importedTrack != null) {
            await _cleanupImportedTrack(importedTrack);
          }
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
      widget.onSelectionEnded?.call();
    }
  }

  Future<void> _cleanupImportedTrack(SelectedAudioTrack track) async {
    final file = File(track.localFilePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTrack = widget.selectedTrack;
    final hasSelectedTrack = selectedTrack != null;

    return InkWell(
      onTap: _openAudioFlow,
      radius: 16,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: ShapeDecoration(
          color: VineTheme.scrim15,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isBusy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (hasSelectedTrack)
              const DivineIcon(icon: .musicNotesSimple)
            else
              const Row(
                spacing: 1.5,
                children: [
                  _AudioBar(height: 7),
                  _AudioBar(height: 16),
                  _AudioBar(height: 13),
                  _AudioBar(height: 7),
                  _AudioBar(height: 10),
                ],
              ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  hasSelectedTrack ? selectedTrack.displayTitle : 'Add audio',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: hasSelectedTrack
                      ? VineTheme.labelLargeFont()
                      : VineTheme.titleMediumFont(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioBar extends StatelessWidget {
  const _AudioBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: height,
      decoration: BoxDecoration(
        color: VineTheme.whiteText,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
