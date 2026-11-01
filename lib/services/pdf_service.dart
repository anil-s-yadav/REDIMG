import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for converting images to PDF documents.
class PdfService {
  /// Convert a list of image file paths into a single PDF.
  static Future<File?> imagesToPdf({
    required List<String> imagePaths,
    String? outputFileName,
  }) async {
    if (imagePaths.isEmpty) return null;

    final pdf = pw.Document();

    for (final imagePath in imagePaths) {
      final file = File(imagePath);
      if (!await file.exists()) continue;

      final imageBytes = await file.readAsBytes();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (context) {
            return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
          },
        ),
      );
    }

    final dir = await getTemporaryDirectory();
    final fileName =
        outputFileName ?? 'images_${DateTime.now().millisecondsSinceEpoch}';
    final outPath = path.join(dir.path, '$fileName.pdf');
    final outFile = File(outPath);
    await outFile.writeAsBytes(await pdf.save());
    return outFile;
  }

  /// Render the first page of a PDF document to image bytes for previewing.
  static Future<Uint8List?> renderPdfPreview(
    String filePath, {
    int maxWidth = 800,
  }) async {
    try {
      if (!Platform.isAndroid) return null;
      final file = File(filePath);
      if (!await file.exists()) return null;

      const channel = MethodChannel('com.redpdf.redimg/media_scanner');
      final result = await channel.invokeMethod<Uint8List>(
        'renderPdfPreview',
        {'path': filePath, 'maxWidth': maxWidth},
      );
      return result;
    } catch (e) {
      debugPrint('PdfService: Failed to render preview: $e');
      return null;
    }
  }
}
