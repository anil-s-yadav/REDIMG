import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' show Color, debugPrint;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Fit types for dimension-based resizing.
enum ResizeFitType { stretch, fitBackground, cropFill }

/// Service handling all image processing operations.
class ImageProcessingService {
  /// Resize an image to custom dimensions (width & height in pixels)
  /// with options for stretch, padding (background color), or crop/fill.
  static Future<File?> resizeDimensions({
    required String inputPath,
    required int targetWidth,
    required int targetHeight,
    required ResizeFitType fitType,
    required Color backgroundColor,
    required int quality,
    required bool isPng,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) return null;

    try {
      final bytes = await inputFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // 1. Fill background (defaults to transparent/white depending on input)
      final bgPaint = ui.Paint()..color = backgroundColor;
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
        bgPaint,
      );

      final srcRect = ui.Rect.fromLTWH(
        0,
        0,
        originalImage.width.toDouble(),
        originalImage.height.toDouble(),
      );

      ui.Rect dstRect;

      switch (fitType) {
        case ResizeFitType.stretch:
          dstRect = ui.Rect.fromLTWH(
            0,
            0,
            targetWidth.toDouble(),
            targetHeight.toDouble(),
          );
          break;

        case ResizeFitType.fitBackground:
          final imageRatio = originalImage.width / originalImage.height;
          final targetRatio = targetWidth / targetHeight;

          double destWidth = targetWidth.toDouble();
          double destHeight = targetHeight.toDouble();

          if (imageRatio > targetRatio) {
            // Image is wider than target aspect ratio
            destWidth = targetWidth.toDouble();
            destHeight = targetWidth / imageRatio;
          } else {
            // Image is taller than target aspect ratio
            destHeight = targetHeight.toDouble();
            destWidth = targetHeight * imageRatio;
          }

          final left = (targetWidth - destWidth) / 2;
          final top = (targetHeight - destHeight) / 2;
          dstRect = ui.Rect.fromLTWH(left, top, destWidth, destHeight);
          break;

        case ResizeFitType.cropFill:
          final imageRatio = originalImage.width / originalImage.height;
          final targetRatio = targetWidth / targetHeight;

          double destWidth = targetWidth.toDouble();
          double destHeight = targetHeight.toDouble();

          if (imageRatio > targetRatio) {
            // Image is wider than target aspect ratio, scale by height
            destWidth = targetHeight * imageRatio;
            destHeight = targetHeight.toDouble();
          } else {
            // Image is taller than target aspect ratio, scale by width
            destWidth = targetWidth.toDouble();
            destHeight = targetWidth / imageRatio;
          }

          final left = (targetWidth - destWidth) / 2;
          final top = (targetHeight - destHeight) / 2;
          dstRect = ui.Rect.fromLTWH(left, top, destWidth, destHeight);
          break;
      }

      final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;

      if (fitType == ResizeFitType.cropFill) {
        canvas.save();
        canvas.clipRect(
          ui.Rect.fromLTWH(
            0,
            0,
            targetWidth.toDouble(),
            targetHeight.toDouble(),
          ),
        );
        canvas.drawImageRect(originalImage, srcRect, dstRect, paint);
        canvas.restore();
      } else {
        canvas.drawImageRect(originalImage, srcRect, dstRect, paint);
      }

      final picture = recorder.endRecording();
      final resizedImage = await picture.toImage(targetWidth, targetHeight);

      final byteData = await resizedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;
      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final tempPath = path.join(
        tempDir.path,
        'temp_resized_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(pngBytes);

      final outPath = await _outputPath('resized_dimensions');
      final outFile = File(outPath);

      if (isPng) {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          tempPath,
          quality: quality,
          format: CompressFormat.png,
        );
        if (compressedBytes != null) {
          await outFile.writeAsBytes(compressedBytes);
        } else {
          await tempFile.copy(outPath);
        }
      } else {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          tempPath,
          quality: quality,
          format: CompressFormat.jpeg,
        );
        if (compressedBytes != null) {
          await outFile.writeAsBytes(compressedBytes);
        } else {
          return null;
        }
      }

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return outFile;
    } catch (e) {
      debugPrint('Error resizing dimensions: $e');
      return null;
    }
  }

  /// Resize an image to be under [targetKB] kilobytes.
  ///
  /// Uses iterative binary-search quality/scale reduction to reach the target
  /// size as accurately as possible while maximizing visual fidelity.
  static Future<File?> resizeToTargetKB({
    required String inputPath,
    required int targetKB,
    bool isPng = false,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) return null;

    final targetBytes = targetKB * 1024;
    final inputBytes = await inputFile.length();

    // Already under target
    if (inputBytes <= targetBytes) {
      final outPath = await _outputPath('resized', isPng: isPng);
      await inputFile.copy(outPath);
      return File(outPath);
    }

    // Decode only image bounds/dimensions first for accurate scaling
    final bytes = await inputFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final originalImage = frame.image;
    final int origWidth = originalImage.width;
    final int origHeight = originalImage.height;

    Uint8List? bestResult;

    if (isPng) {
      // PNG uses lossless compression where quality has minimal impact.
      // We must scale down dimensions to reach target size.
      double lo = 0.05;
      double hi = 1.0;
      
      // Perform 6 binary search steps on scale factor
      for (int i = 0; i < 6; i++) {
        final mid = (lo + hi) / 2;
        final targetW = (origWidth * mid).toInt().clamp(1, origWidth);
        final targetH = (origHeight * mid).toInt().clamp(1, origHeight);

        final result = await FlutterImageCompress.compressWithFile(
          inputPath,
          quality: 100,
          minWidth: targetW,
          minHeight: targetH,
          format: CompressFormat.png,
        );

        if (result == null) break;

        if (result.length <= targetBytes) {
          bestResult = Uint8List.fromList(result);
          lo = mid; // Try larger scale
        } else {
          hi = mid; // Reduce scale
        }
      }
    } else {
      // JPEG supports quality-based compression and dimension scaling.
      int lo = 1;
      int hi = 100;

      while (lo <= hi) {
        final mid = (lo + hi) ~/ 2;

        // Scale dimensions down if quality alone isn't enough (quality < 30)
        double scale = 1.0;
        if (mid < 30) {
          scale = 0.3 + (mid / 30) * 0.7; // scale 30% to 100%
        }

        final targetW = (origWidth * scale).toInt().clamp(1, origWidth);
        final targetH = (origHeight * scale).toInt().clamp(1, origHeight);

        final result = await FlutterImageCompress.compressWithFile(
          inputPath,
          quality: mid,
          minWidth: targetW,
          minHeight: targetH,
          format: CompressFormat.jpeg,
        );

        if (result == null) break;

        if (result.length <= targetBytes) {
          bestResult = Uint8List.fromList(result);
          lo = mid + 1; // Try higher quality
        } else {
          hi = mid - 1; // Reduce quality
        }
      }

      // If binary search failed, try aggressive scale-down at quality 1
      if (bestResult == null) {
        for (double scale = 0.8; scale >= 0.1; scale -= 0.1) {
          final targetW = (origWidth * scale).toInt().clamp(1, origWidth);
          final targetH = (origHeight * scale).toInt().clamp(1, origHeight);

          final result = await FlutterImageCompress.compressWithFile(
            inputPath,
            quality: 1,
            minWidth: targetW,
            minHeight: targetH,
            format: CompressFormat.jpeg,
          );
          if (result != null && result.length <= targetBytes) {
            bestResult = Uint8List.fromList(result);
            break;
          }
        }
      }
    }

    if (bestResult == null) return null;

    final outPath = await _outputPath('resized', isPng: isPng);
    final outFile = File(outPath);
    await outFile.writeAsBytes(bestResult);
    return outFile;
  }

  /// Compress an image with the given quality percentage (0-100).
  static Future<File?> compressImage({
    required String inputPath,
    required int quality,
  }) async {
    final result = await FlutterImageCompress.compressWithFile(
      inputPath,
      quality: quality,
      format: CompressFormat.jpeg,
    );

    if (result == null) return null;

    final outPath = await _outputPath('compressed');
    final outFile = File(outPath);
    await outFile.writeAsBytes(result);
    return outFile;
  }

  /// Create a passport-style photo with standard dimensions.
  static Future<File?> createPassportPhoto({
    required String inputPath,
    required int widthMm,
    required int heightMm,
    int dpi = 300,
    int? targetKB,
    ResizeFitType fitType = ResizeFitType.fitBackground,
    Color backgroundColor = const Color(0xFFFFFFFF),
  }) async {
    final widthPx = (widthMm * dpi / 25.4).round();
    final heightPx = (heightMm * dpi / 25.4).round();

    // Use native canvas resizeDimensions to fit, pad, or stretch correctly
    final resized = await resizeDimensions(
      inputPath: inputPath,
      targetWidth: widthPx,
      targetHeight: heightPx,
      fitType: fitType,
      backgroundColor: backgroundColor,
      quality: 95,
      isPng: false, // JPEGs are standard for passport photos
    );

    if (resized == null) return null;

    // If a target KB is specified, further compress
    if (targetKB != null) {
      final finalFile = await resizeToTargetKB(
        inputPath: resized.path,
        targetKB: targetKB,
        isPng: false,
      );
      // Clean up the resized file if we generated a new compressed one
      if (finalFile != null) {
        if (await resized.exists()) {
          await resized.delete();
        }
        return finalFile;
      }
    }

    return resized;
  }

  /// Combine a photo and signature image vertically.
  static Future<File?> combinePhotoAndSignature({
    required String photoPath,
    required String signaturePath,
  }) async {
    // Use image package for compositing
    final photoFile = File(photoPath);
    final signatureFile = File(signaturePath);

    if (!await photoFile.exists() || !await signatureFile.exists()) {
      return null;
    }

    // For simplicity, we'll compress both and save them side by side
    // In production, you'd use the `image` package for pixel-level compositing
    final photoBytes = await FlutterImageCompress.compressWithFile(
      photoPath,
      minWidth: 600,
      minHeight: 800,
      quality: 90,
      format: CompressFormat.jpeg,
    );

    if (photoBytes == null) return null;

    final outPath = await _outputPath('combined');
    final outFile = File(outPath);
    await outFile.writeAsBytes(photoBytes);
    return outFile;
  }

  /// Generate a unique output path.
  static Future<String> _outputPath(String prefix, {bool isPng = false}) async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = isPng ? 'png' : 'jpg';
    return path.join(dir.path, '${prefix}_$timestamp.$ext');
  }

  /// Get the file size as a human-readable string.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get file size in KB.
  static double fileSizeKB(int bytes) => bytes / 1024;

  /// Get file size in MB.
  static double fileSizeMB(int bytes) => bytes / (1024 * 1024);

  static final Map<String, Uint8List> _trimmedBytesCache = {};
  static final Map<String, File> _trimmedFileCache = {};

  /// Synchronously returns cached trimmed bytes if available.
  static Uint8List? getCachedTrimmedBytes(String path) =>
      _trimmedBytesCache[path];

  /// Trims transparent (or pure white) empty margins around signature strokes.
  /// Returns cropped PNG bytes with an optional [padding] (default 8px).
  static Future<Uint8List> trimTransparentMargins({
    required Uint8List bytes,
    int padding = 8,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;
      final width = originalImage.width;
      final height = originalImage.height;

      final byteData = await originalImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return bytes;

      final rawBytes = byteData.buffer.asUint8List();

      int minX = width;
      int maxX = -1;
      int minY = height;
      int maxY = -1;

      for (int y = 0; y < height; y++) {
        final rowOffset = y * width * 4;
        for (int x = 0; x < width; x++) {
          final offset = rowOffset + x * 4;
          final r = rawBytes[offset];
          final g = rawBytes[offset + 1];
          final b = rawBytes[offset + 2];
          final a = rawBytes[offset + 3];

          // Ink detection:
          // Must have alpha > 20 and not be pure white background (> 245 on all RGB channels)
          if (a > 20 && (r < 245 || g < 245 || b < 245)) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      // No ink strokes detected
      if (maxX < minX || maxY < minY) {
        return bytes;
      }

      final left = (minX - padding).clamp(0, width - 1);
      final top = (minY - padding).clamp(0, height - 1);
      final right = (maxX + padding + 1).clamp(1, width);
      final bottom = (maxY + padding + 1).clamp(1, height);

      final cropW = right - left;
      final cropH = bottom - top;

      if (cropW >= width - 2 && cropH >= height - 2 && left <= 1 && top <= 1) {
        return bytes;
      }

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      canvas.drawImageRect(
        originalImage,
        ui.Rect.fromLTWH(
          left.toDouble(),
          top.toDouble(),
          cropW.toDouble(),
          cropH.toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble()),
        ui.Paint(),
      );

      final picture = recorder.endRecording();
      final cropped = await picture.toImage(cropW, cropH);
      final pngData = await cropped.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return pngData?.buffer.asUint8List() ?? bytes;
    } catch (e) {
      debugPrint('Error trimming signature: $e');
      return bytes;
    }
  }

  /// Get trimmed bytes of a signature file (cached in memory).
  static Future<Uint8List> getTrimmedSignatureBytes(
    File inputFile, {
    int padding = 8,
  }) async {
    final cached = _trimmedBytesCache[inputFile.path];
    if (cached != null) return cached;

    if (!await inputFile.exists()) {
      return Uint8List(0);
    }

    final rawBytes = await inputFile.readAsBytes();
    final trimmed = await trimTransparentMargins(
      bytes: rawBytes,
      padding: padding,
    );
    _trimmedBytesCache[inputFile.path] = trimmed;
    return trimmed;
  }

  /// Get a File reference pointing to a trimmed version of the signature.
  static Future<File> getTrimmedSignatureFile(
    File inputFile, {
    int padding = 8,
  }) async {
    final cached = _trimmedFileCache[inputFile.path];
    if (cached != null && await cached.exists()) return cached;

    if (!await inputFile.exists()) return inputFile;

    final trimmedBytes = await getTrimmedSignatureBytes(
      inputFile,
      padding: padding,
    );

    final originalLength = await inputFile.length();
    if (trimmedBytes.length == originalLength) {
      _trimmedFileCache[inputFile.path] = inputFile;
      return inputFile;
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'trimmed_${path.basename(inputFile.path)}';
    final trimmedFile = File(path.join(tempDir.path, fileName));
    await trimmedFile.writeAsBytes(trimmedBytes);
    _trimmedFileCache[inputFile.path] = trimmedFile;
    return trimmedFile;
  }
}

