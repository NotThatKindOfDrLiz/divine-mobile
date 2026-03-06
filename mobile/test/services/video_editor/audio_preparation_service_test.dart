import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/selected_audio_track.dart';
import 'package:openvine/services/video_editor/audio_preparation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioPreparationService', () {
    const channel = MethodChannel('test/audio_preparation_service');
    late AudioPreparationService service;
    late Directory tempDir;
    late File sourceFile;

    setUp(() async {
      service = AudioPreparationService(channel: channel);
      tempDir = await Directory.systemTemp.createTemp(
        'audio_preparation_service_test_',
      );
      sourceFile = File('${tempDir.path}/source.m4a');
      await sourceFile.writeAsBytes([1, 2, 3]);
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns the original file when no preparation is required', () async {
      var nativeCallCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            nativeCallCount += 1;
            return null;
          });

      final preparedTrack = await service.prepareForRender(
        track: SelectedAudioTrack(
          id: 'track-1',
          localFilePath: sourceFile.path,
          displayTitle: 'Uploaded audio',
          duration: const Duration(seconds: 6),
        ),
        videoDuration: const Duration(seconds: 4),
      );

      expect(preparedTrack.path, sourceFile.path);
      expect(preparedTrack.deleteAfterUse, isFalse);
      expect(nativeCallCount, 0);
    });

    test(
      'delegates to the native layer when delayed placement is required',
      () async {
        MethodCall? capturedCall;
        final preparedFile = File('${tempDir.path}/prepared.m4a');

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              capturedCall = call;
              await preparedFile.writeAsBytes([4, 5, 6]);
              return preparedFile.path;
            });

        final preparedTrack = await service.prepareForRender(
          track: SelectedAudioTrack(
            id: 'track-2',
            localFilePath: sourceFile.path,
            displayTitle: 'Uploaded audio',
            duration: const Duration(seconds: 2),
            videoStartOffset: const Duration(seconds: 1),
          ),
          videoDuration: const Duration(seconds: 6),
        );

        expect(preparedTrack.path, preparedFile.path);
        expect(preparedTrack.deleteAfterUse, isTrue);
        expect(capturedCall?.method, 'prepareForRender');
        expect(capturedCall?.arguments, {
          'sourcePath': sourceFile.path,
          'sourceStartOffsetMs': 0,
          'videoStartOffsetMs': 1000,
          'videoDurationMs': 6000,
        });
      },
    );
  });
}
