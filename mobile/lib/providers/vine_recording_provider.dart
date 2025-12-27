// ABOUTME: Riverpod state management for VineRecordingController
// ABOUTME: Provides reactive state updates for recording UI without ChangeNotifier

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/services/video_recorder/camera/camera_macos_service.dart';
import 'package:openvine/services/video_recorder/camera/camera_mobile_service.dart';
import 'package:openvine/services/video_recorder/camera/camera_permission_service.dart';
import 'package:riverpod/riverpod.dart' show Ref;
import 'package:openvine/services/vine_recording_controller.dart'
    show
        ExtractedSegment,
        VineRecordingController,
        VineRecordingState,
        RecordingSegment,
        MacOSCameraInterface,
        CameraPlatformInterface;
import 'package:openvine/models/vine_draft.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Timer duration options for delayed recording
enum TimerDuration {
  off,
  three,
  ten;

  IconData get icon {
    return switch (this) {
      .off => Icons.timer,
      .three => Icons.timer_3,
      .ten => Icons.timer_10,
    };
  }
}

/// Result returned from stopRecording containing video file, draft ID, and native proof
class RecordingResult {
  const RecordingResult({
    required this.videoFile,
    required this.draftId,
    this.nativeProof,
  });

  final File? videoFile;
  final String? draftId;
  final NativeProofData? nativeProof;
}

/// State class for VineRecording that captures all necessary UI state
class VineRecordingUIState {
  const VineRecordingUIState({
    required this.recordingState,
    required this.zoomLevel,
    required this.cameraSensorAspectRatio,
    required this.focusPoint,
    required this.totalRecordedDuration,
    required this.remainingDuration,
    required this.canRecord,
    required this.hasSegments,
    required this.isCameraInitialized,
    required this.canSwitchCamera,
    required this.segments,
    required this.cameraSwitchCount,
    required this.countdownValue,
    required this.aspectRatio,
    required this.flashMode,
    required this.timerDuration,
  });

  // Offset
  final Offset focusPoint;

  // Durations
  final Duration totalRecordedDuration;
  final Duration remainingDuration;

  // Booleans
  final bool canRecord;
  // From controller.hasSegments - includes virtual segments for macOS
  final bool hasSegments;
  final bool isCameraInitialized;
  final bool canSwitchCamera;

  // Double values
  final double zoomLevel;
  final double cameraSensorAspectRatio;

  // List
  final List<RecordingSegment> segments;

  // Integers
  final int countdownValue;
  // Increments each time camera switches to force UI rebuild
  final int cameraSwitchCount;

  // Custom types
  final model.AspectRatio aspectRatio;
  final FlashMode flashMode;
  final TimerDuration timerDuration;
  final VineRecordingState recordingState;

  // Convenience getters used by UI
  bool get isRecording => recordingState == .recording;
  bool get isInitialized =>
      isCameraInitialized &&
      recordingState != .processing &&
      recordingState != .error;
  bool get isError => recordingState == .error;
  Duration get recordingDuration => totalRecordedDuration;
  String? get errorMessage => isError ? 'Recording error occurred' : null;

  VineRecordingUIState copyWith({
    VineRecordingState? recordingState,
    double? zoomLevel,
    double? cameraSensorAspectRatio,
    Offset? focusPoint,
    Duration? totalRecordedDuration,
    Duration? remainingDuration,
    bool? canRecord,
    bool? hasSegments,
    bool? isCameraInitialized,
    bool? canSwitchCamera,
    List<RecordingSegment>? segments,
    int? cameraSwitchCount,
    int? countdownValue,
    model.AspectRatio? aspectRatio,
    FlashMode? flashMode,
    TimerDuration? timerDuration,
  }) {
    return VineRecordingUIState(
      recordingState: recordingState ?? this.recordingState,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      cameraSensorAspectRatio:
          cameraSensorAspectRatio ?? this.cameraSensorAspectRatio,
      focusPoint: focusPoint ?? this.focusPoint,
      totalRecordedDuration:
          totalRecordedDuration ?? this.totalRecordedDuration,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      canRecord: canRecord ?? this.canRecord,
      hasSegments: hasSegments ?? this.hasSegments,
      isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
      canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera,
      segments: segments ?? this.segments,
      cameraSwitchCount: cameraSwitchCount ?? this.cameraSwitchCount,
      countdownValue: countdownValue ?? this.countdownValue,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      flashMode: flashMode ?? this.flashMode,
      timerDuration: timerDuration ?? this.timerDuration,
    );
  }
}

/// StateNotifier that wraps VineRecordingController and provides reactive updates
class VineRecordingNotifier extends StateNotifier<VineRecordingUIState> {
  VineRecordingNotifier(this._controller, this._ref)
    : super(
        VineRecordingUIState(
          recordingState: _controller.state,
          zoomLevel: 1.0,
          cameraSensorAspectRatio: 1.0,
          focusPoint: Offset.zero,
          totalRecordedDuration: _controller.totalRecordedDuration,
          remainingDuration: _controller.remainingDuration,
          canRecord: _controller.canRecord,
          hasSegments: _controller.hasSegments,
          isCameraInitialized: _controller.isCameraInitialized,
          canSwitchCamera: _controller.canSwitchCamera,
          segments: _controller.segments,
          cameraSwitchCount: 0,
          countdownValue: 0,
          aspectRatio: _controller.aspectRatio,
          flashMode: FlashMode.auto,
          timerDuration: TimerDuration.off,
        ),
      ) {
    // Set up callback for recording progress updates
    _controller.setStateChangeCallback(updateState);

    _cameraService = !kIsWeb && Platform.isMacOS
        ? CameraMacOSService()
        : CameraMobileService();
  }

  late final CameraBaseService _cameraService;
  double _baseZoomLevel = 1.0;
  bool _isDestroyed = false;

  // Delegate methods to the controller
  Future<bool> initialize({BuildContext? context}) async {
    _isDestroyed = false;

    // Check permissions using the dedicated service
    final hasPermissions = context != null && context.mounted
        ? await CameraPermissionService.ensurePermissionsWithDialog(context)
        : await CameraPermissionService.ensurePermissions();
    if (!hasPermissions) {
      return false;
    }

    await _cameraService.initialize();
    state = state.copyWith(
      cameraSwitchCount: state.cameraSwitchCount + 1,
      countdownValue: 0,
    );
    updateState();

    return true;
  }

  void handleAppLifecycleState(AppLifecycleState appState) async {
    await _cameraService.handleAppLifecycleState(appState);

    if (appState == .resumed) {
      state = state.copyWith(cameraSwitchCount: state.cameraSwitchCount + 1);
      updateState();
    }
  }

  void destroy() async {
    _isDestroyed = true;
    _cameraService.dispose();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
    // Auto-save as draft if recording completed but not published
    // Note: We can't await in dispose(), so we use unawaited future
    // The controller cleanup will be delayed until save completes via the future chain
    /* TODO: _autoSaveDraftBeforeDispose()
        .then((_) {
          // Clear callback to prevent memory leaks
          _controller.setStateChangeCallback(null);
          _controller.dispose();
        })
        .catchError((e) {
          Log.error(
            'Error during auto-save, proceeding with cleanup: $e',
            name: 'VineRecordingProvider',
            category: LogCategory.system,
          );
          // Ensure cleanup happens even if save fails
          _controller.setStateChangeCallback(null);
          _controller.dispose();
        })
        .whenComplete(() {
          super.dispose();
        }); */
  }

  /// Toggle flash mode between off, on, and auto
  void toggleFlash() async {
    final FlashMode newMode = switch (state.flashMode) {
      .off => .torch,
      .torch => .auto,
      .auto => .off,
      _ => .off,
    };
    final success = await _cameraService.setFlashMode(newMode);
    if (!success) {
      return;
    }
    state = state.copyWith(flashMode: newMode);
  }

  void toggleAspectRatio() {
    final model.AspectRatio newRatio = state.aspectRatio == .square
        ? .vertical
        : .square;

    setAspectRatio(newRatio);
  }

  /// Set aspect ratio for recording
  void setAspectRatio(model.AspectRatio ratio) {
    _controller.setAspectRatio(ratio);
    state = state.copyWith(aspectRatio: ratio);
    updateState();
  }

  Future<void> switchCamera() async {
    final success = await _cameraService.switchCamera();

    if (!success) {
      return;
    }
    _baseZoomLevel = 1;

    // Force state update to rebuild UI with new camera preview
    // Increment camera switch count to ensure state object changes and triggers UI rebuild
    state = state.copyWith(
      cameraSwitchCount: state.cameraSwitchCount + 1,
      zoomLevel: 1,
    );
    updateState();
  }

  Future<void> setZoomLevel(double value) async {
    if (value > _cameraService.maxZoomLevel ||
        value < _cameraService.minZoomLevel) {
      return;
    }

    final success = await _cameraService.setZoomLevel(value);
    if (!success) {
      return;
    }
    state = state.copyWith(zoomLevel: value);
    updateState();
  }

  Future<void> setFocusPoint(Offset value) async {
    final success = await _cameraService.setFocusPoint(value);
    if (!success) {
      return;
    }
    state = state.copyWith(focusPoint: value);
    updateState();
  }

  Future<void> toggleRecording() async {
    switch (state.recordingState) {
      case .idle:
        startRecording();
        break;
      case .recording:
        stopRecording();
        break;
      default:
        // TODO: Handle other cases
        break;
    }
  }

  Future<void> startRecording() async {
    _baseZoomLevel = state.zoomLevel;
    state = state.copyWith(recordingState: .recording);

    // Handle timer countdown
    if (state.timerDuration != .off) {
      final seconds = state.timerDuration == .three ? 3 : 10;

      for (int i = seconds; i > 0; i--) {
        if (_isDestroyed) return; // Stop countdown if disposed
        state = state.copyWith(countdownValue: i);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (_isDestroyed) return; // Stop before starting recording if disposed
      state = state.copyWith(countdownValue: 0);
    }

    if (_isDestroyed) return; // Don't start recording if disposed
    await _cameraService.startRecording();
    updateState();
  }

  Future<void> stopRecording() async {
    if (!state.isRecording) return;

    await _cameraService.stopRecording();

    state = state.copyWith(recordingState: .idle);
    updateState();
    /* 

    final result = await _controller.finishRecording();
    updateState();
    Log.info(
      '🔍 PROOFMODE DEBUG: stopRecording() called',
      category: LogCategory.video,
    );
    Log.info(
      '🔍 Video file: ${result.$1?.path ?? "NULL"}',
      category: LogCategory.video,
    );
    Log.info(
      '🔍 Native proof: ${result.$2?.toString() ?? "NULL"}',
      category: LogCategory.video,
    );
    // Auto-create draft immediately after recording finishes
    if (result.$1 != null) {
      try {
        final draftStorage = await _ref.read(
          draftStorageServiceProvider.future,
        );

        // Serialize NativeProofData to JSON if available
        String? proofManifestJson;
        if (result.$2 != null) {
          try {
            proofManifestJson = jsonEncode(result.$2!.toJson());
            Log.info(
              '📜 Native ProofMode data attached to draft',
              category: LogCategory.video,
            );
            Log.info(
              '🔍 Proof JSON length: ${proofManifestJson.length} chars',
              category: LogCategory.video,
            );
            Log.info(
              '🔍 Proof verification level: ${result.$2!.verificationLevel}',
              category: LogCategory.video,
            );
          } catch (e) {
            Log.error(
              'Failed to serialize NativeProofData for draft: $e',
              category: LogCategory.video,
            );
          }
        } else {
          Log.warning(
            '⚠️ NO NATIVE PROOF DATA FROM RECORDING! ProofMode will not be published.',
            category: LogCategory.video,
          );
        }

        final draft = VineDraft.create(
          videoFile: result.$1!,
          title: 'Do it for the Vine!',
          description: '',
          hashtags: ['openvine', 'vine'],
          frameCount: _controller.segments.length,
          selectedApproach: 'native',
          proofManifestJson: proofManifestJson,
          aspectRatio: _controller.aspectRatio,
        );

        await draftStorage.saveDraft(draft);
        _currentDraftId =
            draft.id; // Track draft to prevent duplicate on dispose
        Log.info(
          '📹 Auto-created draft: ${draft.id}',
          category: LogCategory.video,
        );

        return RecordingResult(
          videoFile: result.$1,
          draftId: draft.id,
          nativeProof: result.$2,
        );
      } catch (e) {
        Log.error(
          '📹 Failed to auto-create draft: $e',
          category: LogCategory.video,
        );
        // Still return the video file so user can manually save
        return RecordingResult(
          videoFile: result.$1,
          draftId: null,
          nativeProof: result.$2,
        );
      }
    }

    return RecordingResult(
      videoFile: null,
      draftId: null,
      nativeProof: result.$2,
    ); */
  }

  void zoomByLongPressMove(Offset offsetFromOrigin) {
    // Calculate upward drag distance (negative Y = upward)
    final dragDistance = (-offsetFromOrigin.dy).clamp(-160.0, 400.0);

    final zoomLevel = _baseZoomLevel + (dragDistance / 80);
    setZoomLevel(zoomLevel);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseZoomLevel = state.zoomLevel;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final newZoom = (_baseZoomLevel * details.scale).clamp(
      _cameraService.minZoomLevel,
      _cameraService.maxZoomLevel,
    );

    // Only update if change is significant to avoid excessive updates
    if ((state.zoomLevel - newZoom).abs() > 0.01) {
      setZoomLevel(newZoom);
    }
  }

  /// Get the camera preview widget from the controller
  Widget? get previewWidget => _cameraService.isInitialized
      ? _cameraService.buildPreviewWidget(
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onTapDown: (details) {},
        )
      : null;

  /// Get the actual camera preview aspect ratio to prevent distortion
  /// Returns the real camera sensor aspect ratio, or defaults to 3:4 if unavailable
  double get cameraAspectRatio {
    // Default fallback for macOS/web or uninitialized cameras
    return 3.0 / 4.0;
  }

  void openVideoEditor() {
    if (!state.hasSegments) return;

    /// TODO: navigate to new video-editor
  }

  void closeVideoRecorder(BuildContext context) {
    Log.info(
      '📹 X CANCEL - navigating away from camera',
      category: LogCategory.video,
    );
    // Try to pop if possible, otherwise go home.
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      // No screen to pop to (navigated via go), go home instead.
      context.goHome();
    }
  }

  //// ----------------- DELETE FIXME:
  final VineRecordingController _controller;
  final Ref _ref;

  // Track whether video was successfully published to prevent auto-save
  bool _wasPublished = false;

  // Track the draft ID we created in stopRecording to prevent duplicate drafts
  String? _currentDraftId;

  /// Update the state based on the current controller state
  void updateState() {
    state = VineRecordingUIState(
      recordingState: state.recordingState,
      zoomLevel: state.zoomLevel,
      cameraSensorAspectRatio: _cameraService.cameraAspectRatio,
      focusPoint: state.focusPoint,
      totalRecordedDuration: _controller.totalRecordedDuration,
      remainingDuration: _controller.remainingDuration,
      canRecord: _cameraService.canRecord,
      hasSegments: _controller
          .hasSegments, // CRITICAL: Use controller's hasSegments which includes virtual segments for macOS
      isCameraInitialized: _cameraService.isInitialized,
      canSwitchCamera: _cameraService.canSwitchCamera,
      segments: _controller.segments,
      cameraSwitchCount:
          state.cameraSwitchCount, // CRITICAL: Preserve camera switch count
      countdownValue: state.countdownValue,
      aspectRatio: state.aspectRatio,
      flashMode: state.flashMode,
      timerDuration: state.timerDuration,
    );
  }

  // UI control methods

  /// Cycle timer duration
  void cycleTimer() {
    final TimerDuration newTimer = switch (state.timerDuration) {
      .off => .three,
      .three => .ten,
      .ten => .off,
    };
    state = state.copyWith(timerDuration: newTimer);
  }

  /// Update countdown value
  void updateCountdown(int value) {
    state = state.copyWith(countdownValue: value);
  }

  /// Stop the current segment without finishing the recording.
  /// This allows the user to record multiple segments before finalizing.
  Future<void> stopSegment() async {
    await _controller.stopRecording();
    updateState();
    Log.info(
      '📹 Segment stopped, total segments: ${_controller.segments.length}',
      category: LogCategory.video,
    );
  }

  Future<(File?, NativeProofData?)> finishRecording() async {
    final result = await _controller.finishRecording();
    updateState();
    return result;
  }

  /// Extract individual segment files without concatenating
  /// Returns a list of ExtractedSegment with metadata for each segment
  Future<List<ExtractedSegment>> extractSegmentFiles() async {
    final result = await _controller.extractSegmentFiles();
    updateState();
    return result;
  }

  /// Set the duration of previously recorded clips from ClipManager
  /// Call this when returning to camera to record additional segments
  void setPreviouslyRecordedDuration(Duration duration) {
    _controller.setPreviouslyRecordedDuration(duration);
    updateState();
  }

  /// Clear segments after they've been added to ClipManager
  /// This prevents duplicate processing when user navigates back
  void clearSegments() {
    _controller.clearSegments();
    updateState();
  }

  void reset() {
    _controller.reset();
    _wasPublished = false; // Reset publish flag for new recording
    _currentDraftId = null; // Clear draft ID for new recording
    updateState();
  }

  /// Mark recording as published to prevent auto-save on dispose
  void markAsPublished() {
    _wasPublished = true;
    Log.info(
      'Recording marked as published - auto-save will be skipped',
      name: 'VineRecordingProvider',
      category: LogCategory.system,
    );
  }

  /// Clean up temp files and reset for new recording
  Future<void> cleanupAndReset() async {
    try {
      // Clean up temp files first
      _controller.cleanupFiles();
      // Then reset state
      _controller.reset();
      _wasPublished = false;
      _currentDraftId = null; // Clear draft ID for new recording
      updateState();
      Log.info(
        'Cleaned up temp files and reset for new recording',
        name: 'VineRecordingProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error during cleanup and reset: $e',
        name: 'VineRecordingProvider',
        category: LogCategory.system,
      );
    }
  }

  /// Release camera resources to free memory when navigating away.
  ///
  /// Call this when moving to the video editor to release CameraX resources.
  /// The camera can be re-initialized by calling initialize() again.
  void releaseCamera() {
    _controller.releaseCamera();
    updateState();
  }

  /// Auto-save recording as draft if completed but not published
  Future<void> _autoSaveDraftBeforeDispose() async {
    /* TODO:   try {
      // Skip auto-save if video was successfully published
      if (_wasPublished) {
        Log.info(
          'Skipping auto-save - video was published',
          name: 'VineRecordingProvider',
          category: LogCategory.system,
        );
        return;
      }

      // Skip auto-save if we already created a draft in stopRecording()
      if (_currentDraftId != null) {
        Log.info(
          'Skipping auto-save - draft already created: $_currentDraftId',
          name: 'VineRecordingProvider',
          category: LogCategory.system,
        );
        return;
      }

      // Only auto-save if recording is completed
      if (_controller.state != VineRecordingState.completed) {
        return;
      }

      // Check if we have segments to save
      if (_controller.segments.isEmpty) {
        Log.debug(
          'No segments to auto-save as draft',
          name: 'VineRecordingProvider',
          category: LogCategory.system,
        );
        return;
      }

      // Get the video file path from macOS single recording mode
      if (Platform.isMacOS &&
          _controller.cameraInterface is MacOSCameraInterface) {
        final macOSInterface =
            _controller.cameraInterface as MacOSCameraInterface;
        final videoPath = macOSInterface.currentRecordingPath;

        if (videoPath != null && File(videoPath).existsSync()) {
          await _saveDraftFromPath(videoPath);
          return;
        }
      }

      // For other platforms or if macOS path not available, check segments
      final segment = _controller.segments.firstOrNull;
      if (segment?.filePath != null && File(segment!.filePath!).existsSync()) {
        await _saveDraftFromPath(segment.filePath!);
      }
    } catch (e) {
      Log.error(
        'Failed to auto-save draft on dispose: $e',
        name: 'VineRecordingProvider',
        category: LogCategory.system,
      );
      // Don't rethrow - ensure cleanup continues
    } */
  }

  /// Save draft from video file path
  Future<void> _saveDraftFromPath(String videoPath) async {
    try {
      final draftStorage = await _ref.read(draftStorageServiceProvider.future);

      // Copy video file to permanent draft location using app support directory (sandboxed)
      final appDir = await getApplicationSupportDirectory();
      final draftsDir = Directory(path.join(appDir.path, 'drafts'));
      if (!draftsDir.existsSync()) {
        draftsDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(videoPath);
      final permanentPath = path.join(
        draftsDir.path,
        'draft_$timestamp$extension',
      );

      // Copy the file to permanent location
      final sourceFile = File(videoPath);
      final permanentFile = await sourceFile.copy(permanentPath);

      Log.info(
        '📁 Copied draft video to permanent location: $permanentPath',
        name: 'VineRecordingProvider',
        category: LogCategory.system,
      );

      // Create draft with permanent file path
      final draft = VineDraft.create(
        videoFile: permanentFile,
        title:
            'Untitled Draft - ${DateTime.now().toLocal().toString().split('.')[0]}',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'auto',
        aspectRatio: _controller.aspectRatio,
      );

      await draftStorage.saveDraft(draft);

      Log.info(
        '✅ Auto-saved recording as draft: ${draft.id}',
        name: 'VineRecordingProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to save draft: $e',
        name: 'VineRecordingProvider',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  // Getters that delegate to controller
  VineRecordingController get controller => _controller;
}

/// Provider for VineRecordingController with reactive state management
final vineRecordingProvider =
    StateNotifierProvider<VineRecordingNotifier, VineRecordingUIState>((ref) {
      // Create recording controller (ProofMode handled by Guardian Project native library)
      final controller = VineRecordingController();
      final notifier = VineRecordingNotifier(controller, ref);

      ref.onDispose(() {
        notifier.dispose();
      });

      return notifier;
    });
