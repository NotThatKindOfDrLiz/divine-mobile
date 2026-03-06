import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/selected_audio_track.dart';
import 'package:openvine/screens/video_editor/video_local_audio_timing_screen.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockProVideoEditor extends ProVideoEditor {
  @override
  void initializeStream() {}

  @override
  Future<WaveformData> getWaveform(WaveformConfigs value) async {
    return WaveformData(
      leftChannel: Float32List(48),
      rightChannel: Float32List(48),
      sampleRate: 44100,
      duration: const Duration(seconds: 10),
      samplesPerSecond: 10,
    );
  }
}

SelectedAudioTrack _buildTrack({required Duration duration}) {
  return SelectedAudioTrack(
    id: 'audio-track-1',
    localFilePath: '/tmp/audio-track-1.m4a',
    displayTitle: 'Uploaded Clip',
    duration: duration,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ProVideoEditor.instance = _MockProVideoEditor();
  });

  testWidgets('renders short-track placement copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VideoLocalAudioTimingScreen(
          track: _buildTrack(duration: const Duration(seconds: 3)),
          originalAudioVolume: 0.2,
          videoDuration: const Duration(seconds: 6),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Move where this audio starts in your video'),
      findsOneWidget,
    );
    expect(find.text('Original video audio'), findsOneWidget);
    expect(find.text('Added audio'), findsOneWidget);
    expect(find.bySemanticsLabel('Play audio preview'), findsOneWidget);
  });

  testWidgets('renders long-track placement copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VideoLocalAudioTimingScreen(
          track: _buildTrack(duration: const Duration(seconds: 12)),
          originalAudioVolume: 0.2,
          videoDuration: const Duration(seconds: 6),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Choose which part of the audio plays with your video'),
      findsOneWidget,
    );
    expect(find.text('Uploaded Clip'), findsOneWidget);
  });

  test('confirmed result keeps track and original audio volume', () {
    final track = _buildTrack(duration: const Duration(seconds: 8));
    const originalAudioVolume = 0.35;

    final result = LocalAudioTimingConfirmed(
      track: track,
      originalAudioVolume: originalAudioVolume,
    );

    expect(result.track, track);
    expect(result.originalAudioVolume, originalAudioVolume);
  });
}
