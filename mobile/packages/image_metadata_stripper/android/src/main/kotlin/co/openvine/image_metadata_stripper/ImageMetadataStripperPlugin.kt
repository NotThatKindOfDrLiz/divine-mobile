package co.openvine.image_metadata_stripper

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class ImageMetadataStripperPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(
        flutterPluginBinding: FlutterPlugin.FlutterPluginBinding,
    ) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "image_metadata_stripper",
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "stripImageMetadata" -> stripImageMetadata(call, result)
            else -> result.notImplemented()
        }
    }

    private fun stripImageMetadata(call: MethodCall, result: Result) {
        val inputPath = call.argument<String>("inputPath")
        val outputPath = call.argument<String>("outputPath")

        if (inputPath == null || outputPath == null) {
            result.error(
                "INVALID_ARGUMENT",
                "inputPath and outputPath are required",
                null,
            )
            return
        }

        val inputFile = File(inputPath)
        if (!inputFile.exists()) {
            result.error(
                "FILE_NOT_FOUND",
                "Input file does not exist: $inputPath",
                null,
            )
            return
        }

        executor.execute {
            try {
                val bitmap = BitmapFactory.decodeFile(inputPath)
                if (bitmap == null) {
                    mainHandler.post {
                        result.error(
                            "DECODE_FAILED",
                            "Could not decode image: $inputPath",
                            null,
                        )
                    }
                    return@execute
                }

                val format = if (inputPath.lowercase().endsWith(".png")) {
                    Bitmap.CompressFormat.PNG
                } else {
                    Bitmap.CompressFormat.JPEG
                }

                val quality = if (format == Bitmap.CompressFormat.PNG) 100 else 85

                FileOutputStream(File(outputPath)).use { out ->
                    bitmap.compress(format, quality, out)
                }
                bitmap.recycle()

                mainHandler.post {
                    result.success(null)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("STRIP_FAILED", e.message, null)
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
