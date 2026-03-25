import Cocoa
import FlutterMacOS

public class ImageMetadataStripperPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "image_metadata_stripper",
      binaryMessenger: registrar.messenger
    )
    let instance = ImageMetadataStripperPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "stripImageMetadata":
      stripImageMetadata(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func stripImageMetadata(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let inputPath = args["inputPath"] as? String,
          let outputPath = args["outputPath"] as? String else {
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "inputPath and outputPath are required",
        details: nil
      ))
      return
    }

    guard FileManager.default.fileExists(atPath: inputPath) else {
      result(FlutterError(
        code: "FILE_NOT_FOUND",
        message: "Input file does not exist: \(inputPath)",
        details: nil
      ))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      guard let imageData = FileManager.default.contents(atPath: inputPath),
            let nsImage = NSImage(data: imageData),
            let cgImage = nsImage.cgImage(
              forProposedRect: nil, context: nil, hints: nil
            ) else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "DECODE_FAILED",
            message: "Could not decode image: \(inputPath)",
            details: nil
          ))
        }
        return
      }

      let isPng = inputPath.lowercased().hasSuffix(".png")
      let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
      let outputData: Data?

      if isPng {
        outputData = bitmapRep.representation(
          using: .png, properties: [:]
        )
      } else {
        outputData = bitmapRep.representation(
          using: .jpeg, properties: [.compressionFactor: 0.85]
        )
      }

      guard let data = outputData else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "ENCODE_FAILED",
            message: "Could not re-encode image",
            details: nil
          ))
        }
        return
      }

      do {
        try data.write(to: URL(fileURLWithPath: outputPath))
        DispatchQueue.main.async {
          result(nil)
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "WRITE_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }
}
