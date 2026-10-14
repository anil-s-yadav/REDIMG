package com.redpdf.resize_image_to_kb

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.redpdf.redimg/media_scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val fileName = call.argument<String>("fileName")
                        val mimeType = call.argument<String>("mimeType") ?: "image/png"
                        val subDir = call.argument<String>("subDir") ?: "RedImage"

                        if (sourcePath == null || fileName == null) {
                            result.error("INVALID_ARGUMENT", "sourcePath and fileName required", null)
                            return@setMethodCallHandler
                        }

                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                // Android 10+: Use MediaStore API (NO permissions needed).
                                // Files are automatically indexed and visible in file manager.
                                val savedPath = saveViaMediaStore(sourcePath, fileName, mimeType, subDir)
                                result.success(mapOf("path" to savedPath, "success" to true))
                            } else {
                                // Android 9 and below: Direct file I/O (needs WRITE_EXTERNAL_STORAGE).
                                val savedPath = saveDirectly(sourcePath, fileName, subDir)
                                // Trigger MediaScanner so the file appears in the file manager.
                                MediaScannerConnection.scanFile(
                                    this,
                                    arrayOf(savedPath),
                                    arrayOf(mimeType)
                                ) { _, _ -> }
                                result.success(mapOf("path" to savedPath, "success" to true))
                            }
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.message, null)
                        }
                    }

                    "scanFile" -> {
                        // Manually trigger MediaScanner for a specific file path.
                        val filePath = call.argument<String>("path")
                        val mimeType = call.argument<String>("mimeType")
                        if (filePath != null) {
                            MediaScannerConnection.scanFile(
                                this,
                                arrayOf(filePath),
                                if (mimeType != null) arrayOf(mimeType) else null
                            ) { path, uri ->
                                runOnUiThread {
                                    result.success(
                                        mapOf(
                                            "path" to (path ?: ""),
                                            "uri" to (uri?.toString() ?: "")
                                        )
                                    )
                                }
                            }
                        } else {
                            result.error("INVALID_ARGUMENT", "File path is required", null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Android 10+ (API 29+): Save via MediaStore.Downloads.
     * Requires ZERO storage permissions. Auto-indexed in file manager/gallery.
     */
    private fun saveViaMediaStore(
        sourcePath: String,
        fileName: String,
        mimeType: String,
        subDir: String
    ): String {
        val contentValues = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(
                MediaStore.Downloads.RELATIVE_PATH,
                "${Environment.DIRECTORY_DOWNLOADS}/$subDir"
            )
            put(MediaStore.Downloads.IS_PENDING, 1)
        }

        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
            ?: throw Exception("Failed to create MediaStore entry")

        resolver.openOutputStream(uri)?.use { outputStream ->
            FileInputStream(File(sourcePath)).use { inputStream ->
                inputStream.copyTo(outputStream)
            }
        } ?: throw Exception("Failed to open output stream")

        // Mark as complete — file is now visible to the system
        contentValues.clear()
        contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
        resolver.update(uri, contentValues, null, null)

        return "${Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)}/$subDir/$fileName"
    }

    /**
     * Android 9 and below: Save directly to the filesystem.
     * Requires WRITE_EXTERNAL_STORAGE permission (declared with maxSdkVersion=28).
     */
    private fun saveDirectly(sourcePath: String, fileName: String, subDir: String): String {
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            subDir
        )
        if (!dir.exists()) dir.mkdirs()

        val destFile = File(dir, fileName)
        File(sourcePath).copyTo(destFile, overwrite = true)
        return destFile.absolutePath
    }
}
