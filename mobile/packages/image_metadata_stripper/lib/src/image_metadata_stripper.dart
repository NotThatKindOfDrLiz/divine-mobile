import 'dart:io';

import 'package:flutter/services.dart';

/// Strips EXIF metadata (GPS, device info, timestamps) from image files
/// using native platform APIs.
///
/// On iOS, uses UIImage decode → re-encode which discards all EXIF data.
/// On Android, uses BitmapFactory decode → compress cycle which discards
/// all EXIF data from the output.
class ImageMetadataStripper {
  static const _channel = MethodChannel('image_metadata_stripper');

  /// Strips all EXIF metadata from the image at [inputPath] and writes
  /// the cleaned image to [outputPath].
  ///
  /// Throws [PlatformException] if the native call fails.
  static Future<void> stripMetadata({
    required String inputPath,
    required String outputPath,
  }) async {
    await _channel.invokeMethod<void>('stripImageMetadata', {
      'inputPath': inputPath,
      'outputPath': outputPath,
    });
  }

  /// Convenience: strips metadata in-place by writing to a temp file
  /// and replacing the original.
  static Future<File> stripMetadataInPlace(File imageFile) async {
    final tempPath = '${imageFile.path}.stripped';
    await stripMetadata(
      inputPath: imageFile.path,
      outputPath: tempPath,
    );
    final tempFile = File(tempPath);
    await tempFile.rename(imageFile.path);
    return imageFile;
  }
}
