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
  });
}
