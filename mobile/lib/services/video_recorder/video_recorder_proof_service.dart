// ABOUTME: Service for generating ProofMode verification data for recorded videos
// ABOUTME: Handles native ProofMode integration and metadata extraction

import 'dart:io';

import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for generating ProofMode proofs for video recordings
class VideoRecorderProofService {
  /// Generate native ProofMode proof for a video file.
  ///
  /// Returns [NativeProofData] if proof generation succeeds, null otherwise.
  /// Handles platform availability checks and graceful fallback if ProofMode
  /// is not supported.
  static Future<NativeProofData?> generateProof(File videoFile) async {
    try {
      // Check if native ProofMode is available on this platform
      final isAvailable = await NativeProofModeService.isAvailable();
      if (!isAvailable) {
        Log.info(
          '🔐 Native ProofMode not available on this platform',
          name: 'VideoRecorderProofService',
          category: .video,
        );
        return null;
      }

      Log.info(
        '🔐 Generating native ProofMode proof for: ${videoFile.path}',
        name: 'VideoRecorderProofService',
        category: .video,
      );

      // Generate proof using native library
      final proofHash = await NativeProofModeService.generateProof(
        videoFile.path,
      );
      if (proofHash == null) {
        Log.warning(
          '🔐 Native proof generation returned null',
          name: 'VideoRecorderProofService',
          category: .video,
        );
        return null;
      }

      Log.info(
        '🔐 Native proof hash: $proofHash',
        name: 'VideoRecorderProofService',
        category: .video,
      );

      // Read proof metadata from native library
      final metadata = await NativeProofModeService.readProofMetadata(
        proofHash,
      );
      if (metadata == null) {
        Log.warning(
          '🔐 Could not read native proof metadata',
          name: 'VideoRecorderProofService',
          category: .video,
        );
        return null;
      }

      Log.info(
        '🔐 Native proof metadata fields: ${metadata.keys.join(", ")}',
        name: 'VideoRecorderProofService',
        category: .video,
      );

      // Create NativeProofData from metadata
      final proofData = NativeProofData.fromMetadata(metadata);
      Log.info(
        '🔐 Native proof data created: ${proofData.verificationLevel}',
        name: 'VideoRecorderProofService',
        category: .video,
      );

      return proofData;
    } catch (e) {
      Log.error(
        '🔐 Native proof generation failed: $e',
        name: 'VideoRecorderProofService',
        category: .video,
      );
      return null;
    }
  }
}
