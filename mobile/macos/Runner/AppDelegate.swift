import Cocoa
import AVFoundation
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller : FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
    NativeCameraPlugin.register(with: controller.registrar(forPlugin: "NativeCameraPlugin"))
    // CameraMacOSPlugin removed - Flutter now has native macOS camera support
    setupAudioPreparationChannel(controller: controller)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func setupAudioPreparationChannel(controller: FlutterViewController) {
    let registrar = controller.registrar(forPlugin: "OpenVineAudioPreparation")
    let channel = FlutterMethodChannel(
      name: "org.openvine/audio_preparation",
      binaryMessenger: registrar.messenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "prepareForRender":
        self?.handlePrepareAudio(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handlePrepareAudio(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let sourcePath = args["sourcePath"] as? String,
          let sourceStartOffsetMs = (args["sourceStartOffsetMs"] as? NSNumber)?.int64Value,
          let videoStartOffsetMs = (args["videoStartOffsetMs"] as? NSNumber)?.int64Value,
          let videoDurationMs = (args["videoDurationMs"] as? NSNumber)?.int64Value else {
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "sourcePath, sourceStartOffsetMs, videoStartOffsetMs, and videoDurationMs are required",
        details: nil
      ))
      return
    }

    guard videoDurationMs > 0 else {
      result(FlutterError(
        code: "INVALID_DURATION",
        message: "videoDurationMs must be greater than zero",
        details: nil
      ))
      return
    }

    guard FileManager.default.fileExists(atPath: sourcePath) else {
      result(FlutterError(
        code: "FILE_NOT_FOUND",
        message: "Audio source file does not exist: \(sourcePath)",
        details: nil
      ))
      return
    }

    prepareAudioForRender(
      sourcePath: sourcePath,
      sourceStartOffsetMs: sourceStartOffsetMs,
      videoStartOffsetMs: videoStartOffsetMs,
      videoDurationMs: videoDurationMs,
      result: result
    )
  }

  private func prepareAudioForRender(
    sourcePath: String,
    sourceStartOffsetMs: Int64,
    videoStartOffsetMs: Int64,
    videoDurationMs: Int64,
    result: @escaping FlutterResult
  ) {
    let asset = AVURLAsset(url: URL(fileURLWithPath: sourcePath))

    guard let sourceTrack = asset.tracks(withMediaType: .audio).first else {
      result(FlutterError(
        code: "NO_AUDIO_TRACK",
        message: "Selected file does not contain an audio track",
        details: nil
      ))
      return
    }

    let videoDuration = cmTime(milliseconds: videoDurationMs)
    let sourceStartTime = cmTime(milliseconds: sourceStartOffsetMs)
    let videoStartTime = cmTime(milliseconds: videoStartOffsetMs)

    guard CMTimeCompare(videoDuration, .zero) > 0 else {
      result(FlutterError(
        code: "INVALID_DURATION",
        message: "Video duration must be greater than zero",
        details: nil
      ))
      return
    }

    guard CMTimeCompare(asset.duration, sourceStartTime) > 0 else {
      result(FlutterError(
        code: "INVALID_SOURCE_OFFSET",
        message: "Source start offset is outside the selected audio file",
        details: nil
      ))
      return
    }

    guard CMTimeCompare(videoDuration, videoStartTime) > 0 else {
      result(FlutterError(
        code: "INVALID_VIDEO_OFFSET",
        message: "Video start offset is outside the final video duration",
        details: nil
      ))
      return
    }

    let availableSourceDuration = CMTimeSubtract(asset.duration, sourceStartTime)
    let remainingVideoDuration = CMTimeSubtract(videoDuration, videoStartTime)
    let clipDuration = CMTimeCompare(availableSourceDuration, remainingVideoDuration) < 0
      ? availableSourceDuration
      : remainingVideoDuration

    guard CMTimeCompare(clipDuration, .zero) > 0 else {
      result(FlutterError(
        code: "INVALID_CLIP_DURATION",
        message: "Prepared audio clip duration must be greater than zero",
        details: nil
      ))
      return
    }

    let composition = AVMutableComposition()
    composition.insertEmptyTimeRange(CMTimeRange(start: .zero, duration: videoDuration))

    guard let compositionTrack = composition.addMutableTrack(
      withMediaType: .audio,
      preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
      result(FlutterError(
        code: "TRACK_CREATION_FAILED",
        message: "Failed to create composition audio track",
        details: nil
      ))
      return
    }

    do {
      try compositionTrack.insertTimeRange(
        CMTimeRange(start: sourceStartTime, duration: clipDuration),
        of: sourceTrack,
        at: videoStartTime
      )
    } catch {
      result(FlutterError(
        code: "INSERT_FAILED",
        message: error.localizedDescription,
        details: nil
      ))
      return
    }

    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("prepared_audio_\(UUID().uuidString).m4a")
    try? FileManager.default.removeItem(at: outputURL)

    guard let exportSession = AVAssetExportSession(
      asset: composition,
      presetName: AVAssetExportPresetAppleM4A
    ) else {
      result(FlutterError(
        code: "EXPORT_SESSION_FAILED",
        message: "Failed to create audio export session",
        details: nil
      ))
      return
    }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = .m4a
    exportSession.timeRange = CMTimeRange(start: .zero, duration: videoDuration)
    exportSession.shouldOptimizeForNetworkUse = true

    exportSession.exportAsynchronously {
      DispatchQueue.main.async {
        switch exportSession.status {
        case .completed:
          result(outputURL.path)
        case .cancelled:
          result(FlutterError(
            code: "EXPORT_CANCELLED",
            message: "Audio preparation was cancelled",
            details: nil
          ))
        case .failed:
          result(FlutterError(
            code: "EXPORT_FAILED",
            message: exportSession.error?.localizedDescription ?? "Audio preparation failed",
            details: nil
          ))
        default:
          result(FlutterError(
            code: "EXPORT_INCOMPLETE",
            message: "Audio preparation finished in unexpected state: \(exportSession.status.rawValue)",
            details: nil
          ))
        }
      }
    }
  }

  private func cmTime(milliseconds: Int64) -> CMTime {
    CMTime(value: milliseconds, timescale: 1000)
  }
}
