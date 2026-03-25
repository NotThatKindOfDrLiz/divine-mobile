import Cocoa
import FlutterMacOS
import ImageIO
import UniformTypeIdentifiers

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
            let imageSource = CGImageSourceCreateWithData(
              imageData as CFData, nil
            ),
            let srcImage = CGImageSourceCreateImageAtIndex(
              imageSource, 0, nil
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

      // Draw into a fresh bitmap context to sever all metadata links
      let width = srcImage.width
      let height = srcImage.height
      let colorSpace = srcImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
      guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "DECODE_FAILED",
            message: "Could not create bitmap context",
            details: nil
          ))
        }
        return
      }
      ctx.draw(srcImage, in: CGRect(x: 0, y: 0, width: width, height: height))
      guard let cleanImage = ctx.makeImage() else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "DECODE_FAILED",
            message: "Could not create clean image from context",
            details: nil
          ))
        }
        return
      }

      let isPng = inputPath.lowercased().hasSuffix(".png")
      let utType: CFString = isPng ? kUTTypePNG : kUTTypeJPEG
      let outputURL = URL(fileURLWithPath: outputPath)

      guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL, utType, 1, nil
      ) else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "ENCODE_FAILED",
            message: "Could not create image destination",
            details: nil
          ))
        }
        return
      }

      var properties: [CFString: Any] = [:]
      if !isPng {
        properties[kCGImageDestinationLossyCompressionQuality] = 0.85
      }
      CGImageDestinationAddImage(
        destination, cleanImage, properties as CFDictionary
      )

      guard CGImageDestinationFinalize(destination) else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "ENCODE_FAILED",
            message: "Could not re-encode image",
            details: nil
          ))
        }
        return
      }

      DispatchQueue.main.async {
        result(nil)
      }
    }
  }
}
