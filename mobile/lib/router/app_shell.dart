// ABOUTME: AppShell widget providing bottom navigation and dynamic header
// ABOUTME: Header title uses Bricolage Grotesque font, camera button in bottom nav

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.child, required this.currentIndex, super.key});

  final Widget child;
  final int currentIndex;

  /// Pipeline stages (rows of the test matrix).
  static const _pipelineStages = [
    _PipelineStage(
      header: 'Render Only',
      icon: Icons.movie_creation_outlined,
    ),
    _PipelineStage(
      header: 'Render + Streamable',
      icon: Icons.stream,
      streamable: true,
    ),
    _PipelineStage(
      header: 'Render + Streamable + C2PA',
      icon: Icons.verified_outlined,
      streamable: true,
      c2pa: true,
    ),
  ];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final clip1 = RecordingClip(
    id: 'video-1',
    video: EditorVideo.asset('assets/videos/test1.mov'),
    duration: const Duration(seconds: 1),
    recordedAt: DateTime.now(),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
  );

  final clip2 = RecordingClip(
    id: 'video-2',
    video: EditorVideo.asset('assets/videos/test2.mov'),
    duration: const Duration(seconds: 4),
    recordedAt: DateTime.now(),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
  );

  final introClip = RecordingClip(
    id: 'default-intro',
    video: EditorVideo.asset('assets/videos/default_intro.mp4'),
    duration: const Duration(seconds: 3),
    recordedAt: DateTime.now(),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
  );

  /// Clip variants (columns of the test matrix).
  late final _clipVariants = [
    _ClipVariant(label: 'Example video (mp4)', clips: [introClip]),
    _ClipVariant(label: 'First video (1s)', clips: [clip1]),
    _ClipVariant(label: 'Second video (4s)', clips: [clip2]),
    _ClipVariant(label: 'Both videos (5s)', clips: [clip1, clip2]),
  ];

  Future<void> _runTest({
    required List<RecordingClip> clips,
    required bool streamable,
    required bool c2pa,
  }) async {
    final path = await VideoEditorRenderService.renderVideo(
      clips: clips,
      usePersistentStorage: true,
      streamable: streamable,
    );
    if (c2pa) {
      await NativeProofModeService.proofFile(File(path!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug'),
      ),
      body: ListView(
        children: [
          for (final stage in AppShell._pipelineStages)
            ..._buildTestSection(
              context,
              stage: stage,
            ),
        ],
      ),
    );
  }

  List<Widget> _buildTestSection(
    BuildContext context, {
    required _PipelineStage stage,
  }) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
        child: Row(
          children: [
            Icon(stage.icon, size: 18, color: VineTheme.vineGreen),
            const SizedBox(width: 8),
            Text(
              stage.header,
              style: VineTheme.titleSmallFont(color: VineTheme.vineGreen),
            ),
          ],
        ),
      ),
      for (final variant in _clipVariants)
        ListTile(
          dense: true,
          title: Text(
            variant.label,
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurface),
          ),
          trailing: const Icon(
            Icons.play_circle_outline,
            color: VineTheme.onSurfaceMuted,
            size: 20,
          ),
          onTap: () async {
            final tag = '${stage.header} — ${variant.label}';
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text('Running: $tag'),
                  duration: const Duration(seconds: 1),
                ),
              );
            try {
              await _runTest(
                clips: variant.clips,
                streamable: stage.streamable,
                c2pa: stage.c2pa,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text('Done: $tag'),
                    backgroundColor: VineTheme.vineGreen,
                  ),
                );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text('Failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
            }
          },
        ),
      const Divider(color: VineTheme.outlineVariant, height: 1),
    ];
  }
}

class _PipelineStage {
  const _PipelineStage({
    required this.header,
    required this.icon,
    this.streamable = false,
    this.c2pa = false,
  });

  final String header;
  final IconData icon;
  final bool streamable;
  final bool c2pa;
}

class _ClipVariant {
  const _ClipVariant({required this.label, required this.clips});
  final String label;
  final List<RecordingClip> clips;
}
