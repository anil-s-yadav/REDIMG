import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:signature/signature.dart';
import '../../services/file_service.dart';
import '../../services/image_processing_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/signature_picker_sheet.dart';

/// Signature Maker screen matching premium_signature_maker design.
class SignatureMakerScreen extends StatefulWidget {
  const SignatureMakerScreen({super.key});

  @override
  State<SignatureMakerScreen> createState() => _SignatureMakerScreenState();
}

class _SignatureMakerScreenState extends State<SignatureMakerScreen> {
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
    exportPenColor: Colors.black,
  );

  int _selectedSizeIndex = 1; // 10 KB default
  bool _isSaving = false;
  File? _uploadedSignature;
  OutputFormat _outputFormat = OutputFormat.png;

  final List<Map<String, dynamic>> _sizeOptions = [
    {'label': 'Auto', 'kb': 0},
    {'label': '10 KB', 'kb': 10},
    {'label': '20 KB', 'kb': 20},
    {'label': null, 'kb': -1}, // Custom
  ];

  final TextEditingController _customKBController = TextEditingController();

  @override
  void dispose() {
    _signatureController.dispose();
    _customKBController.dispose();
    super.dispose();
  }

  Future<void> _uploadSignature() async {
    final chosen = await showSignaturePickerSheet(context);
    if (chosen != null && mounted) {
      setState(() {
        _uploadedSignature = chosen;
        _signatureController.clear();
      });
    }
  }

  Future<void> _saveSignature() async {
    setState(() => _isSaving = true);

    try {
      File? outputFile;

      if (_uploadedSignature != null) {
        // Use uploaded signature (auto-trim transparent / white margins)
        final trimmed = await ImageProcessingService.getTrimmedSignatureFile(
          _uploadedSignature!,
        );
        final targetKB = _sizeOptions[_selectedSizeIndex]['kb'] as int;
        if (targetKB > 0) {
          outputFile = await ImageProcessingService.resizeToTargetKB(
            inputPath: trimmed.path,
            targetKB: targetKB,
            isPng: _outputFormat == OutputFormat.png,
          );
        } else {
          outputFile = trimmed;
        }
      } else if (_signatureController.isNotEmpty) {
        // Export drawn signature tightly cropped to strokes with small padding
        final defW = _signatureController.defaultWidth;
        final defH = _signatureController.defaultHeight;
        final signatureBytes = await _signatureController.toPngBytes(
          width: defW != null ? defW + 24 : null,
          height: defH != null ? defH + 24 : null,
        );

        if (signatureBytes != null) {
          final dir = await getTemporaryDirectory();
          final filePath = path.join(
            dir.path,
            'signature_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          outputFile = File(filePath);
          await outputFile.writeAsBytes(signatureBytes);

          // Resize if needed
          final targetKB = _sizeOptions[_selectedSizeIndex]['kb'] as int;
          if (targetKB > 0) {
            final resized = await ImageProcessingService.resizeToTargetKB(
              inputPath: filePath,
              targetKB: targetKB,
              isPng: _outputFormat == OutputFormat.png,
            );
            if (resized != null) outputFile = resized;
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please draw or upload a signature')),
        );
        setState(() => _isSaving = false);
        return;
      }

      if (outputFile != null) {
        final fileLength = await outputFile.length();
        int imgW = 0;
        int imgH = 0;
        try {
          final decoded = await decodeImageFromList(
            await outputFile.readAsBytes(),
          );
          imgW = decoded.width;
          imgH = decoded.height;
        } catch (_) {}

        if (mounted) {
          final fileSize = ImageProcessingService.formatFileSize(fileLength);
          context.push(
            '/result',
            extra: {
              'filePath': outputFile.path,
              'fileSize': fileSize,
              'dimensions': imgW > 0 ? '$imgW × $imgH px' : 'Auto',
              'format': 'PNG',
              'toolName': 'Signature Maker',
              'outputFormat': _outputFormat.name,
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.containerMargin,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Text(
                'Signature Maker',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),

              // ── Canvas Card ─────────────────────────────────────
              PremiumCard(
                child: Column(
                  children: [
                    // Toolbar
                    Row(
                      children: [
                        Text(
                          'Drawing\nCanvas',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        _ToolButton(
                          icon: Icons.upload_rounded,
                          label: 'Upload',
                          sublabel: 'Transparent\nPNG preferred',
                          onTap: _uploadSignature,
                          width: 100,
                        ),
                        const SizedBox(width: 12),
                        _ToolButton(
                          icon: Icons.undo_rounded,
                          label: 'Undo',
                          onTap: () => _signatureController.undo(),
                        ),
                        const SizedBox(width: 12),
                        _ToolButton(
                          icon: Icons.delete_outline_rounded,
                          label: 'Clear',
                          onTap: () {
                            _signatureController.clear();
                            setState(() => _uploadedSignature = null);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceSm),

                    // Canvas / Preview
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _uploadedSignature != null
                          ? Stack(
                              children: [
                                Center(
                                  child: Image.file(
                                    _uploadedSignature!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _uploadedSignature = null,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black38,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Signature(
                              controller: _signatureController,
                              backgroundColor: Colors.white,
                            ),
                    ),

                    // Dashed line hint
                    if (_uploadedSignature == null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _DashedLinePainter(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          size: const Size(double.infinity, 1),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spaceLg),

              // ── Export Size ─────────────────────────────────────
              Text(
                'Export Size',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Row(
                children: List.generate(_sizeOptions.length, (index) {
                  final opt = _sizeOptions[index];
                  final isCustom = opt['kb'] == -1;
                  final label = opt['label'] as String?;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index < _sizeOptions.length - 1 ? 8 : 0,
                      ),
                      child: isCustom
                          ? _CustomKBChip(
                              isSelected: _selectedSizeIndex == index,
                              controller: _customKBController,
                              onTap: () =>
                                  setState(() => _selectedSizeIndex = index),
                            )
                          : PresetChip(
                              label: label!,
                              isSelected: _selectedSizeIndex == index,
                              onTap: () =>
                                  setState(() => _selectedSizeIndex = index),
                            ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: AppTheme.spaceLg),

              // ── Output Format ────────────────────────────────────
              FormatPicker(
                selected: _outputFormat,
                onChanged: (fmt) => setState(() => _outputFormat = fmt),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // ── Save Button ─────────────────────────────────────
              PrimaryActionButton(
                label: 'Save Signature ⚡',
                icon: Icons.save_rounded,
                onPressed: _saveSignature,
                isLoading: _isSaving,
              ),
              const SizedBox(height: AppTheme.spaceXl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback? onTap;
  final double? width;

  const _ToolButton({
    required this.icon,
    required this.label,
    this.sublabel,
    this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (sublabel != null)
              Text(
                sublabel!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  fontWeight: FontWeight.w300,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomKBChip extends StatelessWidget {
  final bool isSelected;
  final TextEditingController controller;
  final VoidCallback? onTap;

  const _CustomKBChip({
    required this.isSelected,
    required this.controller,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Custom',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Text(
              'KB',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
