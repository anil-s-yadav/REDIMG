import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/file_service.dart';
import '../../services/pdf_service.dart';
import '../../services/rate_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/signature_viewer_modal.dart';

/// Processing Result screen — auto-saves to Downloads/RedImage/ on load.
class ResultScreen extends StatefulWidget {
  final String filePath;
  final String fileSize;
  final String dimensions;
  final String format;
  final String originalSize;
  final String toolName;
  final String outputFormat; // 'png', 'jpeg', or 'pdf'
  final String? fileName;
  final String? previewImagePath;

  const ResultScreen({
    super.key,
    required this.filePath,
    required this.fileSize,
    required this.dimensions,
    required this.format,
    this.originalSize = '',
    this.toolName = '',
    this.outputFormat = 'png',
    this.fileName,
    this.previewImagePath,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _autoSaved = false;
  bool _saveFailed = false;
  String _savedPath = '';
  bool _isSaving = false;
  String _errorMessage = '';
  Uint8List? _pdfPreviewBytes;

  bool get _isPdf =>
      widget.filePath.toLowerCase().endsWith('.pdf') ||
      _savedPath.toLowerCase().endsWith('.pdf') ||
      _outputFormat == OutputFormat.pdf;

  OutputFormat get _outputFormat {
    switch (widget.outputFormat.toLowerCase()) {
      case 'jpeg':
      case 'jpg':
        return OutputFormat.jpeg;
      case 'pdf':
        return OutputFormat.pdf;
      default:
        return OutputFormat.png;
    }
  }

  @override
  void initState() {
    super.initState();
    _autoSave();
    if (_isPdf) {
      _loadPdfPreview();
    }
  }

  Future<void> _loadPdfPreview() async {
    if (_pdfPreviewBytes != null) return;

    final targetPath = widget.filePath.toLowerCase().endsWith('.pdf')
        ? widget.filePath
        : (_savedPath.toLowerCase().endsWith('.pdf') ? _savedPath : null);

    if (targetPath != null && File(targetPath).existsSync()) {
      try {
        final bytes = await PdfService.renderPdfPreview(targetPath);
        if (mounted) {
          setState(() {
            _pdfPreviewBytes = bytes;
          });
        }
      } catch (e) {
        debugPrint('ResultScreen: Error loading PDF preview: $e');
      }
    }
  }

  Future<void> _openFileExternally() async {
    final targetPath = _savedPath.isNotEmpty && File(_savedPath).existsSync()
        ? _savedPath
        : widget.filePath;

    if (!File(targetPath).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_isPdf ? 'PDF' : 'File'} is still saving, please wait a moment...',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final result = await FileService.openFile(targetPath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isNotEmpty
                  ? result.message
                  : 'Could not open file viewer on this device',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _autoSave() async {
    setState(() {
      _saveFailed = false;
      _autoSaved = false;
    });
    try {
      final file = File(widget.filePath);
      if (!file.existsSync()) {
        if (mounted) {
          setState(() {
            _saveFailed = true;
            _errorMessage = 'Source file not found';
          });
        }
        return;
      }

      final saved = await FileService.saveToRedImage(
        file,
        fileName: widget.fileName,
        toolName: widget.toolName,
        outputFormat: _outputFormat,
      );

      if (mounted) {
        setState(() {
          _autoSaved = true;
          _saveFailed = false;
          _savedPath = saved.path;
        });
        if (_isPdf && _pdfPreviewBytes == null) {
          _loadPdfPreview();
        }
        // Prompt user to rate the app after any successful action
        RateService.showRatePromptIfEligible(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveFailed = true;
          _autoSaved = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _saveAgain() async {
    setState(() => _isSaving = true);
    try {
      final file = File(widget.filePath);
      if (!file.existsSync()) throw Exception('Source file not found');

      final saved = await FileService.saveToRedImage(
        file,
        fileName: widget.fileName,
        toolName: widget.toolName,
        outputFormat: _outputFormat,
      );

      if (mounted) {
        setState(() {
          _savedPath = saved.path;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved as ${_outputFormat.name.toUpperCase()} to Downloads/RedImage/',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        RateService.showRatePromptIfEligible(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPdf = _isPdf;
    final isImage = !isPdf;
    final file = File(widget.filePath);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              const SizedBox(height: 6),

              // ── Success Icon ────────────────────────────────────
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: cs.primaryContainer.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: cs.onPrimaryContainer,
                  size: 30,
                ),
              ),
              const SizedBox(height: 8),

              // ── Title ───────────────────────────────────────────
              Text(
                _saveFailed ? 'Save Failed' : 'Saved Successfully',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: _saveFailed ? cs.error : cs.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),

              // ── Auto-save status ────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _autoSaved
                    ? Container(
                        key: const ValueKey('saved'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Saved to device & Downloads/RedImage/',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _saveFailed
                    ? GestureDetector(
                        onTap: _autoSave,
                        child: Container(
                          key: const ValueKey('failed'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_rounded,
                                color: cs.error,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _errorMessage.isNotEmpty
                                    ? 'Save failed: $_errorMessage — tap to retry'
                                    : 'Save failed — tap to retry',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: cs.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        key: const ValueKey('saving'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Saving…',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 10),

              // ── Preview Card ────────────────────────────────────
              PremiumCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Image or PDF preview
                    Builder(
                      builder: (context) {
                        final isSignature =
                            widget.toolName.toLowerCase().contains(
                              'signature',
                            ) ||
                            widget.filePath.toLowerCase().contains('sign');
                        final hasPreviewImage =
                            widget.previewImagePath != null &&
                            File(widget.previewImagePath!).existsSync();

                        Widget content;
                        if (isImage && file.existsSync()) {
                          if (isSignature) {
                            content = GestureDetector(
                              onTap: () {
                                final meta = SavedFileMeta(
                                  filePath: _savedPath.isNotEmpty
                                      ? _savedPath
                                      : widget.filePath,
                                  name:
                                      widget.fileName ??
                                      file.uri.pathSegments.last,
                                  toolName: widget.toolName,
                                  format: widget.format,
                                  sizeBytes: file.existsSync()
                                      ? file.lengthSync()
                                      : 0,
                                  savedAt: DateTime.now(),
                                );
                                showSignatureViewerModal(context, meta: meta);
                              },
                              child: Stack(
                                children: [
                                  Center(
                                    child: Image.file(
                                      file,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.fullscreen_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            'Tap to View',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            content = Image.file(file, fit: BoxFit.contain);
                          }
                        } else if (_pdfPreviewBytes != null) {
                          content = Center(
                            child: Image.memory(
                              _pdfPreviewBytes!,
                              fit: BoxFit.contain,
                            ),
                          );
                        } else if (hasPreviewImage) {
                          content = Center(
                            child: Image.file(
                              File(widget.previewImagePath!),
                              fit: BoxFit.contain,
                            ),
                          );
                        } else {
                          content = Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_rounded,
                                  size: 48,
                                  color: cs.primaryContainer,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'PDF Document',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return GestureDetector(
                          onTap: isSignature ? null : _openFileExternally,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: double.infinity,
                            height: 160,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                              color: isSignature
                                  ? Colors.white
                                  : cs.surfaceContainer,
                              border: isSignature
                                  ? Border.all(
                                      color: cs.outlineVariant.withValues(
                                        alpha: 0.6,
                                      ),
                                    )
                                  : null,
                            ),
                            clipBehavior: Clip.antiAlias,
                            padding: isSignature
                                ? const EdgeInsets.all(10)
                                : EdgeInsets.zero,
                            child: content,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // ── File Details ──────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'File Details',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Divider(height: 12),

                    // Stat cards
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'NEW SIZE',
                            value: widget.fileSize,
                            subValue: widget.originalSize.isNotEmpty
                                ? widget.originalSize
                                : null,
                            valueColor: cs.primaryContainer,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceSm),
                        Expanded(
                          child: _StatCard(
                            label: 'DIMENSIONS',
                            value: widget.dimensions.isNotEmpty
                                ? widget.dimensions
                                : '—',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Format
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusDefault,
                        ),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FORMAT',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _outputFormat.name.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Optimized',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Action Buttons ──────────────────────────────────
              PrimaryActionButton(
                label: 'Save Again',
                icon: Icons.save_rounded,
                height: 48,
                onPressed: _saveAgain,
                isLoading: _isSaving,
              ),
              const SizedBox(height: 8),

              // ── Share & Edit Row ────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => FileService.shareFile(
                        _savedPath.isNotEmpty ? _savedPath : widget.filePath,
                        subject: widget.toolName,
                      ),
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text(
                        'Share',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text(
                        'Edit Again',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // ── Back to Dashboard ───────────────────────────────
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 8,
                  ),
                ),
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.arrow_back_rounded, size: 15),
                label: const Text(
                  'Back to Dashboard',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat Card ────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    this.subValue,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: valueColor ?? cs.onSurface,
            ),
          ),
          if (subValue != null) ...[
            const SizedBox(height: 1),
            Text(
              subValue!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: cs.outline,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
