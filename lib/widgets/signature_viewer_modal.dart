import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/file_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Background simulation modes for viewing transparent signatures.
enum SignatureViewBackground {
  paperWhite,
  checkerboard,
  warmPaper,
  dark,
}

/// Shows an interactive, full-featured in-app viewer for saved signatures.
///
/// Solves the common problem where external gallery viewers (like Google Photos)
/// render transparent black PNGs on a pitch-black background, making them invisible.
Future<void> showSignatureViewerModal(
  BuildContext context, {
  required SavedFileMeta meta,
  VoidCallback? onDelete,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SignatureViewerModalContent(
      meta: meta,
      onDelete: onDelete,
    ),
  );
}

class _SignatureViewerModalContent extends StatefulWidget {
  final SavedFileMeta meta;
  final VoidCallback? onDelete;

  const _SignatureViewerModalContent({
    required this.meta,
    this.onDelete,
  });

  @override
  State<_SignatureViewerModalContent> createState() =>
      _SignatureViewerModalContentState();
}

class _SignatureViewerModalContentState
    extends State<_SignatureViewerModalContent> {
  SignatureViewBackground _bgMode = SignatureViewBackground.paperWhite;
  Size? _imageDimensions;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  Future<void> _loadImageDimensions() async {
    final file = File(widget.meta.filePath);
    if (!await file.exists()) return;
    try {
      final bytes = await file.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      if (mounted) {
        setState(() {
          _imageDimensions = Size(
            decoded.width.toDouble(),
            decoded.height.toDouble(),
          );
        });
      }
    } catch (_) {}
  }

  Color get _canvasColor {
    switch (_bgMode) {
      case SignatureViewBackground.paperWhite:
        return Colors.white;
      case SignatureViewBackground.warmPaper:
        return const Color(0xFFFAF7F0);
      case SignatureViewBackground.dark:
        return const Color(0xFF1E1E1E);
      case SignatureViewBackground.checkerboard:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final file = File(widget.meta.filePath);
    final sheetHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 25,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Drag Handle ─────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.containerMargin,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.meta.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.tertiary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Transparent ${widget.meta.format}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.tertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pinch to zoom • Toggle background to test visibility',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),

          // ── Main Content ────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.containerMargin),
              children: [
                // ── Interactive Signature Canvas ─────────────────────
                Container(
                  height: 240,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // Background layer
                      if (_bgMode == SignatureViewBackground.checkerboard)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CheckerboardPainter(
                              squareSize: 12,
                              color1: Colors.white,
                              color2: const Color(0xFFE5E7EB),
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Container(color: _canvasColor),
                        ),

                      // Interactive Signature image
                      Positioned.fill(
                        child: file.existsSync()
                            ? InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 4.0,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Image.file(
                                      file,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image_rounded,
                                            size: 40,
                                            color: cs.error,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Failed to load signature image',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: cs.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  'File not found on disk',
                                  style: TextStyle(color: cs.error),
                                ),
                              ),
                      ),

                      // Zoom hint overlay in corner
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.zoom_in_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Pinch to zoom',
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
                ),
                const SizedBox(height: AppTheme.spaceMd),

                // ── Background Selector Pills ────────────────────────
                Row(
                  children: [
                    Text(
                      'Preview on:',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _BgChoiceChip(
                              label: '📄 White Paper',
                              isSelected: _bgMode ==
                                  SignatureViewBackground.paperWhite,
                              onTap: () => setState(() =>
                                  _bgMode = SignatureViewBackground.paperWhite),
                            ),
                            const SizedBox(width: 6),
                            _BgChoiceChip(
                              label: '🏁 Transparent Grid',
                              isSelected: _bgMode ==
                                  SignatureViewBackground.checkerboard,
                              onTap: () => setState(() => _bgMode =
                                  SignatureViewBackground.checkerboard),
                            ),
                            const SizedBox(width: 6),
                            _BgChoiceChip(
                              label: '📜 Cream Paper',
                              isSelected:
                                  _bgMode == SignatureViewBackground.warmPaper,
                              onTap: () => setState(() =>
                                  _bgMode = SignatureViewBackground.warmPaper),
                            ),
                            const SizedBox(width: 6),
                            _BgChoiceChip(
                              label: '🌙 Dark',
                              isSelected:
                                  _bgMode == SignatureViewBackground.dark,
                              onTap: () => setState(
                                  () => _bgMode = SignatureViewBackground.dark),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceMd),

                // ── Why does it look black in Gallery? Banner ────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: cs.primaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Why external gallery shows black on black?',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cs.primaryContainer,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Your signature is saved with transparent background & black ink (perfect for official forms & documents). External gallery viewers (Google Photos) display transparent PNGs on a black canvas in dark mode, making black ink blend in. Your signature is 100% intact!',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),

                // ── File Metadata Card ───────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? cs.surfaceContainerLowest
                        : cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MetaItem(
                        icon: Icons.aspect_ratio_rounded,
                        label: 'Dimensions',
                        value: _imageDimensions != null
                            ? '${_imageDimensions!.width.toInt()} × ${_imageDimensions!.height.toInt()} px'
                            : 'Loading…',
                      ),
                      _MetaItem(
                        icon: Icons.straighten_rounded,
                        label: 'File Size',
                        value: widget.meta.formattedSize,
                      ),
                      _MetaItem(
                        icon: Icons.schedule_rounded,
                        label: 'Saved',
                        value: widget.meta.formattedDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLg),

                // ── Action Buttons ───────────────────────────────────
                // 1. Primary Action: Use in Combine Tool
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/combine-tool');
                  },
                  icon: const Icon(Icons.layers_rounded, size: 18),
                  label: const Text('Use in Combine Photo & Sign Tool'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Secondary Actions Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            FileService.shareFile(widget.meta.filePath),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            FileService.openFile(widget.meta.filePath),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Open External'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                        ),
                      ),
                    ),
                    if (widget.onDelete != null) ...[
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Delete Signature',
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onDelete!();
                        },
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: cs.error,
                        ),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(46, 46),
                          side: BorderSide(
                            color: cs.error.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BgChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BgChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primaryContainer.withValues(alpha: 0.15)
                : cs.surfaceContainerHigh.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? cs.primaryContainer : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? cs.primaryContainer : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, size: 18, color: cs.primaryContainer),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Draws an industry-standard transparency checkerboard pattern.
class _CheckerboardPainter extends CustomPainter {
  final double squareSize;
  final Color color1;
  final Color color2;

  _CheckerboardPainter({
    required this.squareSize,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isEvenRow = (y / squareSize).floor() % 2 == 0;
        final isEvenCol = (x / squareSize).floor() % 2 == 0;
        if (isEvenRow != isEvenCol) {
          canvas.drawRect(
            Rect.fromLTWH(
              x,
              y,
              (x + squareSize > size.width) ? size.width - x : squareSize,
              (y + squareSize > size.height) ? size.height - y : squareSize,
            ),
            paint2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
