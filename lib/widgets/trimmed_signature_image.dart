import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/image_processing_service.dart';

/// Renders a signature image with its transparent / empty margins automatically trimmed,
/// ensuring the signature strokes fill the available space without excessive internal padding.
class TrimmedSignatureImage extends StatefulWidget {
  final File file;
  final BoxFit fit;
  final Widget? errorWidget;

  const TrimmedSignatureImage({
    super.key,
    required this.file,
    this.fit = BoxFit.contain,
    this.errorWidget,
  });

  @override
  State<TrimmedSignatureImage> createState() => _TrimmedSignatureImageState();
}

class _TrimmedSignatureImageState extends State<TrimmedSignatureImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TrimmedSignatureImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _load();
    }
  }

  Future<void> _load() async {
    final cached = ImageProcessingService.getCachedTrimmedBytes(
      widget.file.path,
    );
    if (cached != null) {
      if (mounted) setState(() => _bytes = cached);
      return;
    }
    final bytes = await ImageProcessingService.getTrimmedSignatureBytes(
      widget.file,
    );
    if (mounted) {
      setState(() => _bytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.file.existsSync()) {
      return widget.errorWidget ??
          const Icon(Icons.draw_rounded, size: 20, color: Colors.grey);
    }

    if (_bytes != null && _bytes!.isNotEmpty) {
      return Image.memory(
        _bytes!,
        fit: widget.fit,
        errorBuilder: (_, _, _) =>
            widget.errorWidget ??
            const Icon(Icons.draw_rounded, size: 20, color: Colors.grey),
      );
    }

    return Image.file(
      widget.file,
      fit: widget.fit,
      errorBuilder: (_, _, _) =>
          widget.errorWidget ??
          const Icon(Icons.draw_rounded, size: 20, color: Colors.grey),
    );
  }
}
