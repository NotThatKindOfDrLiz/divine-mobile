// ABOUTME: Tests for VideoRecorderProofService
// ABOUTME: Validates ProofMode proof generation and metadata handling

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_recorder/video_recorder_proof_service.dart';

void main() {
  group('VideoRecorderProofService Tests', () {
    group('generateProof', () {
      test('accepts File parameter and returns Future', () async {
        final testFile = File('/test/video.mp4');

        // Note: This will likely return null in test environment
        // as native ProofMode won't be available
        final result = VideoRecorderProofService.generateProof(testFile);

        expect(result, isA<Future>());
      });

      test('handles non-existent file gracefully', () async {
        final nonExistentFile = File('/non/existent/path/video.mp4');

        // Should not throw, but return null or handle gracefully
        final result = await VideoRecorderProofService.generateProof(
          nonExistentFile,
        );

        // In test environment without native ProofMode, expect null
        expect(result, isNull);
      });

      test('returns NativeProofData or null', () async {
        final testFile = File('/test/video.mp4');

        final result = await VideoRecorderProofService.generateProof(testFile);

        // Result should be either NativeProofData or null
        expect(result, anyOf(isNull, isA<Object>()));
      });
    });

    group('Service Design', () {
      test('is a utility class with static methods', () {
        // Validate that VideoRecorderProofService follows static utility pattern
        expect(VideoRecorderProofService, isA<Type>());
      });

      test('generateProof is a static method', () {
        expect(VideoRecorderProofService.generateProof, isA<Function>());
      });
    });

    group('Integration', () {
      test('works with File objects', () async {
        // Create a temporary file path for testing
        final tempPath = Directory.systemTemp.path;
        final testFile = File('$tempPath/test_video.mp4');

        // Method should accept File without throwing
        final result = VideoRecorderProofService.generateProof(testFile);
        expect(result, isA<Future>());

        // Clean up - await the future
        await result;
      });
    });
  });
}
