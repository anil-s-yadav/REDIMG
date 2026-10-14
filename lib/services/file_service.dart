import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';

/// Supported output formats for image processing.
enum OutputFormat { png, jpeg, pdf }

/// Metadata for a saved file, persisted via SharedPreferences.
class SavedFileMeta {
  final String filePath;
  final String name;
  final String toolName;
  final String format;
  final int sizeBytes;
  final DateTime savedAt;

  SavedFileMeta({
    required this.filePath,
    required this.name,
    required this.toolName,
    required this.format,
    required this.sizeBytes,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'name': name,
    'toolName': toolName,
    'format': format,
    'sizeBytes': sizeBytes,
    'savedAt': savedAt.toIso8601String(),
  };

  factory SavedFileMeta.fromJson(Map<String, dynamic> json) => SavedFileMeta(
    filePath: json['filePath'] as String,
    name: json['name'] as String,
    toolName: json['toolName'] as String? ?? '',
    format: json['format'] as String? ?? '',
    sizeBytes: json['sizeBytes'] as int? ?? 0,
    savedAt:
        DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
  );

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(savedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${savedAt.day}/${savedAt.month}/${savedAt.year}';
  }

  /// Category based on format extension, file name, and tool name.
  String get category {
    final ext = path.extension(filePath).toLowerCase();
    if (ext == '.pdf') return 'pdf';
    final lowerName = name.toLowerCase();
    final lowerTool = toolName.toLowerCase();
    if (lowerTool.contains('combine') || lowerName.contains('combine')) {
      return 'image';
    }
    if (lowerName.contains('sign') ||
        lowerName.contains('sig') ||
        lowerTool.contains('signature')) {
      return 'signature';
    }
    return 'image';
  }
}

/// Service for saving, tracking, and sharing files.
///
/// **Saving strategy (Play Store safe — no dangerous permissions on Android 10+):**
///
/// 1. Files are always saved to the app's private documents directory first.
///    This works on ALL Android versions without any permissions.
///
/// 2. A copy is also placed in `Downloads/RedImage/` for file manager visibility:
///    - Android 10+ (API 29+): via **MediaStore API** — zero permissions needed,
///      files are auto-indexed and immediately visible in the system file manager.
///    - Android 9 and below: via direct file I/O + **MediaScanner** — needs only
///      `WRITE_EXTERNAL_STORAGE` (declared with `maxSdkVersion="28"`).
///
/// 3. SharedPreferences tracks the **internal** path for the "My Files" screen,
///    ensuring reliable access regardless of Android version or permissions.
class FileService {
  static const _prefsKey = 'saved_files_v1';

  /// Platform channel for native file operations (MediaStore, MediaScanner).
  static const _channel = MethodChannel('com.redpdf.redimg/media_scanner');

  /// App's private RedImage directory — always accessible, no permissions needed.
  static Future<Directory> get _outputDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(appDir.path, 'RedImage'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Determine MIME type from file extension.
  static String _getMimeType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      case '.bmp':
        return 'image/bmp';
      default:
        return 'application/octet-stream';
    }
  }

  /// Storage permissions are not needed because:
  /// - Photo picking uses system Photo Picker (no permissions)
  /// - File saving uses MediaStore API on Android 10+ (no permissions)
  static Future<bool> _ensureStoragePermission() async {
    return true;
  }

  /// Copy a saved file to the public Downloads/RedImage/ folder so it
  /// appears in the user's system file manager.
  ///
  /// Uses MediaStore on Android 10+ (no permissions), and direct I/O +
  /// MediaScanner on Android 9 and below (WRITE_EXTERNAL_STORAGE needed).
  ///
  /// If this fails, the internal copy is still saved — this is best-effort.
  static Future<void> _copyToPublicDownloads(File file, String fileName) async {
    if (!Platform.isAndroid) return;

    try {
      // On Android < 10, request WRITE_EXTERNAL_STORAGE first
      await _ensureStoragePermission();

      await _channel.invokeMethod('saveToDownloads', {
        'sourcePath': file.path,
        'fileName': fileName,
        'mimeType': _getMimeType(fileName),
        'subDir': 'RedImage',
      });
    } catch (e) {
      // Best-effort: internal copy is still saved regardless.
      // This can fail on Android 9 if user denies storage permission,
      // but the file is still accessible within the app.
    }
  }

  /// Save a processed file to the app's private storage AND make it
  /// visible in the device's file manager (Downloads/RedImage/).
  ///
  /// If [outputFormat] is provided, the image will be converted to that format
  /// before saving (PNG, JPEG, or PDF).
  static String _formatTimestamp(DateTime dt) {
    final yyyy = dt.year.toString();
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$yyyy$mm${dd}_$hh$min$ss';
  }

  /// Save a processed file to the app's private storage AND make it
  /// visible in the device's file manager (Downloads/RedImage/).
  ///
  /// If [outputFormat] is provided, the image will be converted to that format
  /// before saving (PNG, JPEG, or PDF).
  static Future<File> saveToRedImage(
    File file, {
    String? fileName,
    String toolName = '',
    OutputFormat? outputFormat,
  }) async {
    final dir = await _outputDir;

    // Determine target extension
    String ext;
    if (outputFormat != null) {
      switch (outputFormat) {
        case OutputFormat.png:
          ext = '.png';
        case OutputFormat.jpeg:
          ext = '.jpg';
        case OutputFormat.pdf:
          ext = '.pdf';
      }
    } else {
      ext = path.extension(file.path);
      if (ext.isEmpty) ext = '.png';
    }

    String destName;
    if (fileName != null && fileName.trim().isNotEmpty) {
      final base = path.basenameWithoutExtension(fileName.trim());
      destName = '$base$ext';
    } else {
      final now = DateTime.now();
      destName = 'REDIMG_${_formatTimestamp(now)}$ext';
    }

    var destPath = path.join(dir.path, destName);
    var finalFile = File(destPath);

    // If file already exists, we append a timestamp suffix to prevent overwriting
    if (await finalFile.exists()) {
      final base = path.basenameWithoutExtension(destName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      destName = '${base}_$timestamp$ext';
      destPath = path.join(dir.path, destName);
      finalFile = File(destPath);
    }

    File savedFile;

    // Convert format if needed
    final sourceExt = path.extension(file.path).toLowerCase();
    final isSourceImage = [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.bmp',
    ].contains(sourceExt);

    if (outputFormat == OutputFormat.pdf && isSourceImage) {
      // Convert image → PDF
      savedFile = await _imageToPdf(file, destPath);
    } else if (outputFormat == OutputFormat.png &&
        sourceExt != '.png' &&
        isSourceImage) {
      // Convert → PNG
      final result = await FlutterImageCompress.compressWithFile(
        file.path,
        quality: 100,
        format: CompressFormat.png,
      );
      savedFile = File(destPath);
      if (result != null) {
        await savedFile.writeAsBytes(result);
      } else {
        savedFile = await file.copy(destPath);
      }
    } else if (outputFormat == OutputFormat.jpeg &&
        sourceExt != '.jpg' &&
        sourceExt != '.jpeg' &&
        isSourceImage) {
      // Convert → JPEG
      final result = await FlutterImageCompress.compressWithFile(
        file.path,
        quality: 95,
        format: CompressFormat.jpeg,
      );
      savedFile = File(destPath);
      if (result != null) {
        await savedFile.writeAsBytes(result);
      } else {
        savedFile = await file.copy(destPath);
      }
    } else {
      // No conversion needed, just copy
      savedFile = await file.copy(destPath);
    }

    // Copy to public Downloads/RedImage/ for file manager visibility.
    // This is best-effort — the internal copy above is the reliable one.
    await _copyToPublicDownloads(savedFile, destName);

    // Record in SharedPreferences (using the internal path for reliability)
    final meta = SavedFileMeta(
      filePath: savedFile.path,
      name: destName,
      toolName: toolName,
      format: ext.replaceFirst('.', '').toUpperCase(),
      sizeBytes: await savedFile.length(),
      savedAt: DateTime.now(),
    );
    await _addRecord(meta);

    return savedFile;
  }

  /// Convert an image file to a single-page PDF.
  static Future<File> _imageToPdf(File imageFile, String destPath) async {
    final pdf = pw.Document();
    final imageBytes = await imageFile.readAsBytes();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (context) =>
            pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );

    final outFile = File(destPath);
    await outFile.writeAsBytes(await pdf.save());
    return outFile;
  }

  /// Get all saved file records from SharedPreferences.
  static Future<List<SavedFileMeta>> getSavedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_prefsKey) ?? [];
    final files = <SavedFileMeta>[];

    for (final jsonStr in jsonList) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final meta = SavedFileMeta.fromJson(map);
        // Only include files that still exist on disk
        if (File(meta.filePath).existsSync()) {
          files.add(meta);
        }
      } catch (_) {
        // Skip corrupted entries
      }
    }

    // Sort newest first
    files.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return files;
  }

  /// Get all saved signature files.
  static Future<List<SavedFileMeta>> getSavedSignatures() async {
    final allFiles = await getSavedFiles();
    final signatures = allFiles.where((f) => f.category == 'signature').toList();
    final existingPaths = signatures.map((s) => s.filePath).toSet();

    try {
      final dir = await _outputDir;
      if (await dir.exists()) {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File && !existingPaths.contains(entity.path)) {
            final fileName = path.basename(entity.path).toLowerCase();
            final ext = path.extension(entity.path).toLowerCase();
            if (['.png', '.jpg', '.jpeg', '.webp'].contains(ext) &&
                (fileName.contains('sign') || fileName.contains('sig')) &&
                !fileName.contains('combine')) {
              final stat = entity.statSync();
              signatures.add(SavedFileMeta(
                filePath: entity.path,
                name: path.basename(entity.path),
                toolName: 'Signature Maker',
                format: ext.replaceFirst('.', '').toUpperCase(),
                sizeBytes: stat.size,
                savedAt: stat.modified,
              ));
            }
          }
        }
      }
    } catch (_) {}

    signatures.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return signatures;
  }

  /// Add a file record to SharedPreferences.
  static Future<void> _addRecord(SavedFileMeta meta) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_prefsKey) ?? [];
    jsonList.add(jsonEncode(meta.toJson()));
    await prefs.setStringList(_prefsKey, jsonList);
  }

  /// Remove a file record from SharedPreferences and delete from disk.
  static Future<void> deleteFile(String filePath) async {
    // Delete from disk
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }

    // Remove from prefs
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_prefsKey) ?? [];
    jsonList.removeWhere((jsonStr) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return map['filePath'] == filePath;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_prefsKey, jsonList);
  }

  /// Share a file using the system share sheet.
  static Future<void> shareFile(String filePath, {String? subject}) async {
    await Share.shareXFiles([XFile(filePath)], subject: subject);
  }

  /// Get file info (size, name, etc.)
  static Future<Map<String, dynamic>> getFileInfo(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return {};

    final stat = await file.stat();
    return {
      'name': path.basename(filePath),
      'extension': path.extension(filePath).replaceFirst('.', '').toUpperCase(),
      'size': stat.size,
      'modified': stat.modified,
    };
  }

  /// Open a file in an external application.
  static Future<OpenResult> openFile(String filePath) async {
    return await OpenFilex.open(filePath);
  }
}
