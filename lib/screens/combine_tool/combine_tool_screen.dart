import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../services/file_service.dart';
import '../../services/image_processing_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/signature_picker_sheet.dart';
import '../../widgets/trimmed_signature_image.dart';

/// Combine Photo & Signature screen matching pro_combine_tool_v2 design.
class CombineToolScreen extends StatefulWidget {
  const CombineToolScreen({super.key});

  @override
  State<CombineToolScreen> createState() => _CombineToolScreenState();
}

class _ItemState {
  Offset position;
  double scale;
  double baseScale;
  _ItemState({required this.position, this.scale = 1.0}) : baseScale = scale;
}

class _CombineToolScreenState extends State<CombineToolScreen> {
  File? _photo;
  File? _signature;
  bool _isGenerating = false;
  OutputFormat _outputFormat = OutputFormat.png;
  final _kbController = TextEditingController();
  int? _targetKB;
  List<SavedFileMeta> _savedSignatures = [];
  bool _isLoadingSignatures = false;

  final GlobalKey _previewKey = GlobalKey();
  final _photoState = _ItemState(position: const Offset(10, 10), scale: 1.0);
  final _sigState = _ItemState(position: const Offset(10, 310), scale: 1.0);

  @override
  void initState() {
    super.initState();
    _loadSavedSignatures();
  }

  @override
  void dispose() {
    _kbController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSignatures() async {
    setState(() => _isLoadingSignatures = true);
    final list = await FileService.getSavedSignatures();
    if (mounted) {
      setState(() {
        _savedSignatures = list;
        _isLoadingSignatures = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile != null) setState(() => _photo = File(xFile.path));
  }

  Future<void> _pickSignatureFromGallery() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile != null) {
      final trimmed = await ImageProcessingService.getTrimmedSignatureFile(
        File(xFile.path),
      );
      if (!mounted) return;
      setState(() => _signature = trimmed);
    }
  }

  Future<void> _pickSignature() async {
    final chosen = await showSignaturePickerSheet(context);
    if (chosen != null && mounted) {
      final trimmed = await ImageProcessingService.getTrimmedSignatureFile(
        chosen,
      );
      if (!mounted) return;
      setState(() => _signature = trimmed);
      _loadSavedSignatures();
    }
  }

  Future<void> _selectSavedSignature(SavedFileMeta meta) async {
    final raw = File(meta.filePath);
    final trimmed = await ImageProcessingService.getTrimmedSignatureFile(raw);
    if (!mounted) return;
    setState(() => _signature = trimmed);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected "${meta.name}"'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetPositions() {
    setState(() {
      _photoState.position = const Offset(10, 10);
      _photoState.scale = 1.0;
      _photoState.baseScale = 1.0;
      _sigState.position = const Offset(10, 310);
      _sigState.scale = 1.0;
      _sigState.baseScale = 1.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Positions and scales reset'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _generateCombined() async {
    if (_photo == null || _signature == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both photo and signature')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // Brief delay to allow UI to rebuild without borders before capturing
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary =
          _previewKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Preview not ready');

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        final dir = await getTemporaryDirectory();
        final outPath = p.join(
          dir.path,
          'combined_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        File outFile = File(outPath);
        await outFile.writeAsBytes(byteData.buffer.asUint8List());

        // Apply compression if target KB is set
        if (_targetKB != null && _targetKB! > 0) {
          final compressedFile = await ImageProcessingService.resizeToTargetKB(
            inputPath: outFile.path,
            targetKB: _targetKB!,
            isPng: _outputFormat == OutputFormat.png,
          );
          if (compressedFile != null) {
            // Delete the uncompressed file and use the compressed one
            if (await outFile.exists()) {
              await outFile.delete();
            }
            outFile = compressedFile;
          }
        }

        final fileLength = await outFile.length();
        if (mounted) {
          final fileSize = ImageProcessingService.formatFileSize(fileLength);
          context.push(
            '/result',
            extra: {
              'filePath': outFile.path,
              'fileSize': fileSize,
              'dimensions': '${image.width} × ${image.height} px',
              'format': 'PNG',
              'toolName': 'Combine Photo + Signature',
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

    setState(() => _isGenerating = false);
  }

  Widget _buildPlaceholder(
    IconData icon,
    String text,
    double width,
    double height, {
    double iconSize = 40,
  }) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: Colors.grey.shade400),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveItem(
    File? file,
    _ItemState state,
    Widget placeholder,
    double width,
    double height, {
    required bool isSignature,
  }) {
    final content = file != null
        ? SizedBox(
            width: width,
            height: height,
            child: Image.file(
              file,
              fit: isSignature ? BoxFit.contain : BoxFit.cover,
            ),
          )
        : placeholder;

    return Positioned(
      left: state.position.dx,
      top: state.position.dy,
      child: Transform.scale(
        scale: state.scale,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onScaleStart: (details) {
            state.baseScale = state.scale;
          },
          onScaleUpdate: (details) {
            setState(() {
              state.position += details.focalPointDelta * state.scale;
              state.scale = state.baseScale * details.scale;
            });
          },
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              border: _isGenerating
                  ? null
                  : Border.all(
                      color: file != null
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.5)
                          : Colors.grey.withValues(alpha: 0.5),
                      width: 1 / state.scale.clamp(0.1, 10.0),
                    ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: _isDragging
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.containerMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Text(
                'Combine Photo & Signature',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      size: 14,
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'REQUIRED FOR MANY GOVT FORMS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                'Upload your portrait photo and handwritten signature to generate a single standardized document.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // ── 1. Portrait Photo ───────────────────────────────
              _UploadSection(
                number: '1',
                title: 'Portrait Photo',
                badge: 'JPG, PNG, WEBP',
                file: _photo,
                onTap: _pickPhoto,
                onClear: () => setState(() => _photo = null),
                icon: Icons.camera_alt_rounded,
                uploadTitle: 'Click to upload photo',
              ),
              const SizedBox(height: AppTheme.spaceMd),

              // ── 2. Signature ────────────────────────────────────
              _SignatureSection(
                file: _signature,
                savedSignatures: _savedSignatures,
                isLoadingSaved: _isLoadingSignatures,
                onPickFromGallery: _pickSignatureFromGallery,
                onOpenPickerSheet: _pickSignature,
                onSelectSavedSignature: _selectSavedSignature,
                onClear: () => setState(() => _signature = null),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // ── Live Preview ────────────────────────────────────
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.preview_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Live Preview',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Interactive Editor',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Reset Positions',
                          onPressed: _resetPositions,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hold image to drag, zoom, and position the photo and signature freely.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    Listener(
                      onPointerDown: (_) => setState(() => _isDragging = true),
                      onPointerUp: (_) => setState(() => _isDragging = false),
                      onPointerCancel: (_) =>
                          setState(() => _isDragging = false),
                      child: Center(
                        child: Container(
                          width: 300,
                          height: 400,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).shadowColor.withValues(alpha: 0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRect(
                            child: RepaintBoundary(
                              key: _previewKey,
                              child: Stack(
                                children: [
                                  // Background needs to be explicitly colored for the output
                                  Container(color: Colors.white),
                                  _buildInteractiveItem(
                                    _photo,
                                    _photoState,
                                    _buildPlaceholder(
                                      Icons.person_rounded,
                                      'Photo Area',
                                      280,
                                      290,
                                      iconSize: 48,
                                    ),
                                    280,
                                    290,
                                    isSignature: false,
                                  ),
                                  _buildInteractiveItem(
                                    _signature,
                                    _sigState,
                                    _buildPlaceholder(
                                      Icons.draw_rounded,
                                      'Signature Area',
                                      280,
                                      80,
                                      iconSize: 24,
                                    ),
                                    280,
                                    80,
                                    isSignature: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spaceLg),

              // ── Target Size Input ───────────────────────────────
              Text(
                'Target Size Limit (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Container(
                height: 35,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _kbController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          hintText: 'e.g. 100',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _targetKB = int.tryParse(val);
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16, left: 10),
                      child: Text(
                        'KB',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // ── Output Format ────────────────────────────────────
              FormatPicker(
                selected: _outputFormat,
                onChanged: (fmt) => setState(() => _outputFormat = fmt),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // ── Generate Button ─────────────────────────────────
              PrimaryActionButton(
                label: 'Generate Image',
                icon: Icons.bolt_rounded,
                onPressed: _generateCombined,
                isLoading: _isGenerating,
              ),
              const SizedBox(height: AppTheme.spaceXl),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadSection extends StatelessWidget {
  final String number;
  final String title;
  final String badge;
  final File? file;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final IconData icon;
  final String uploadTitle;

  const _UploadSection({
    required this.number,
    required this.title,
    required this.badge,
    required this.file,
    required this.onTap,
    required this.onClear,
    required this.icon,
    required this.uploadTitle,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                badge,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          UploadArea(
            onTap: onTap,
            icon: icon,
            title: uploadTitle,
            subtitle: 'or drag and drop file here',
            hasFile: file != null,
            preview: file != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        child: Image.file(
                          file!,

                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onClear,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black45,
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
                : null,
          ),
        ],
      ),
    );
  }
}

class _SignatureSection extends StatelessWidget {
  final File? file;
  final List<SavedFileMeta> savedSignatures;
  final bool isLoadingSaved;
  final VoidCallback onPickFromGallery;
  final VoidCallback onOpenPickerSheet;
  final ValueChanged<SavedFileMeta> onSelectSavedSignature;
  final VoidCallback onClear;

  const _SignatureSection({
    required this.file,
    required this.savedSignatures,
    required this.isLoadingSaved,
    required this.onPickFromGallery,
    required this.onOpenPickerSheet,
    required this.onSelectSavedSignature,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '2',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Signature',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Transparent PNG preferred',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: cs.outline,
                ),
              ),
              const Spacer(),
              if (savedSignatures.isNotEmpty)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onOpenPickerSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_edu_rounded,
                            size: 14,
                            color: cs.primaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${savedSignatures.length} saved',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.primaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // ── Upload Box or Selected Preview ───────────────────
          if (file == null) ...[
            UploadArea(
              onTap: onOpenPickerSheet,
              icon: Icons.draw_rounded,
              title: 'Click to select or upload signature',
              subtitle: 'Choose from Gallery or saved signatures',
              hasFile: false,
            ),
          ] else ...[
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: TrimmedSignatureImage(
                      file: file!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onClear,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 15),
                    label: const Text(
                      'Change: Gallery',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenPickerSheet,
                    icon: const Icon(Icons.history_edu_rounded, size: 15),
                    label: Text(
                      'Change: Saved (${savedSignatures.length})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickSavedSignatureCard extends StatelessWidget {
  final SavedFileMeta meta;
  final VoidCallback onTap;

  const _QuickSavedSignatureCard({required this.meta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final file = File(meta.filePath);

    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: file.existsSync()
                ? TrimmedSignatureImage(
                    file: file,
                    fit: BoxFit.contain,
                    errorWidget: const Icon(
                      Icons.draw_rounded,
                      size: 20,
                      color: Colors.grey,
                    ),
                  )
                : const Icon(Icons.draw_rounded, size: 20, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
