import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_metadata_stripper/image_metadata_stripper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(ImageMetadataStripper, () {
    const channel = MethodChannel('image_metadata_stripper');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    group('stripMetadata', () {
      test('invokes stripImageMetadata with correct arguments', () async {
        await ImageMetadataStripper.stripMetadata(
          inputPath: '/tmp/input.jpg',
          outputPath: '/tmp/output.jpg',
        );

        expect(calls, hasLength(1));
        expect(calls.first.method, equals('stripImageMetadata'));
        expect(
          calls.first.arguments,
          equals({
            'inputPath': '/tmp/input.jpg',
            'outputPath': '/tmp/output.jpg',
          }),
        );
      });

      test('throws PlatformException on native error', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              throw PlatformException(
                code: 'FILE_NOT_FOUND',
                message: 'Input file does not exist',
              );
            });

        expect(
          () => ImageMetadataStripper.stripMetadata(
            inputPath: '/nonexistent.jpg',
            outputPath: '/tmp/output.jpg',
          ),
          throwsA(isA<PlatformException>()),
        );
      });
    });

    group('stripMetadataInPlace', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'image_metadata_stripper_unit_test_',
        );
      });

      tearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('calls stripMetadata and renames temp file back', () async {
        final imageFile = File('${tempDir.path}/photo.jpg');
        await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);

        // Mock creates the .stripped output file
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              final args = call.arguments as Map;
              final outputPath = args['outputPath'] as String;
              await File(outputPath).writeAsBytes([0xFF, 0xD8, 0xFF, 0xDB]);
              return null;
            });

        final result = await ImageMetadataStripper.stripMetadataInPlace(
          imageFile,
        );

        // Verify channel was called with correct paths
        expect(calls, hasLength(1));
        expect(
          calls.first.arguments,
          equals({
            'inputPath': imageFile.path,
            'outputPath': '${imageFile.path}.stripped',
          }),
        );

        // Verify the original file was replaced
        expect(result.path, equals(imageFile.path));
        expect(result.existsSync(), isTrue);
        expect(
          await result.readAsBytes(),
          equals([0xFF, 0xD8, 0xFF, 0xDB]),
        );

        // Verify temp file no longer exists
        expect(
          File('${imageFile.path}.stripped').existsSync(),
          isFalse,
        );
      });
    });
  });
}
