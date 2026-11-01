import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/file_service.dart';
import '../../services/image_processing_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Resize Image screen matching modern premium design.
class ResizeImageScreen extends StatefulWidget {
  const ResizeImageScreen({super.key});

  @override
  State<ResizeImageScreen> createState() => _ResizeImageScreenState();
}

class _ResizeImageScreenState extends State<ResizeImageScreen> {
  File? _selectedImage;
  int _targetKB = 100;
  bool _isProcessing = false;
  String _originalSize = '';
  String _originalDimensions = '';
  OutputFormat _outputFormat = OutputFormat.png;

  int? _originalWidth;
  int? _originalHeight;
  bool _lockAspectRatio = true;
  ResizeFitType _fitType = ResizeFitType.stretch;
  Color _backgroundColor = Colors.white;

  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  final List<int> _presets = [10, 50, 100, 200, 500];

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile != null) {
      final file = File(xFile.path);
      final bytes = await file.length();
      setState(() {
        _selectedImage = file;
        _originalSize = ImageProcessingService.formatFileSize(bytes);
        _originalDimensions = ''; // Will be set after decode
      });

      // Decode dimensions
      final decoded = await decodeImageFromList(await file.readAsBytes());
      if (mounted) {
        setState(() {
          _originalWidth = decoded.width;
          _originalHeight = decoded.height;
          _originalDimensions = '${decoded.width} × ${decoded.height} px';
          _widthController.text = decoded.width.toString();
          _heightController.text = decoded.height.toString();
        });
      }
    }
  }

  void _onWidthChanged(String val) {
    if (_lockAspectRatio && _originalWidth != null && _originalHeight != null) {
      final width = int.tryParse(val);
      if (width != null && width > 0) {
        final ratio = _originalWidth! / _originalHeight!;
        final height = (width / ratio).round();
        _heightController.text = height.toString();
      }
    }
  }

  void _onHeightChanged(String val) {
    if (_lockAspectRatio && _originalWidth != null && _originalHeight != null) {
      final height = int.tryParse(val);
      if (height != null && height > 0) {
        final ratio = _originalWidth! / _originalHeight!;
        final width = (height * ratio).round();
        _widthController.text = width.toString();
      }
    }
  }

  Future<void> _resizeImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    final w = int.tryParse(_widthController.text);
    final h = int.tryParse(_heightController.text);
    if (w == null || w <= 0 || h == null || h <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid width and height')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final isPng = _outputFormat == OutputFormat.png;
    final result = await ImageProcessingService.resizeDimensions(
      inputPath: _selectedImage!.path,
      targetWidth: w,
      targetHeight: h,
      fitType: _fitType,
      backgroundColor: _backgroundColor,
      quality: 95,
      isPng: isPng,
      targetKB: _targetKB,
    );

    setState(() => _isProcessing = false);

    if (result != null) {
      final length = await result.length();
      if (!mounted) return;
      final fileSize = ImageProcessingService.formatFileSize(length);
      context.push(
        '/result',
        extra: {
          'filePath': result.path,
          'fileSize': fileSize,
          'dimensions': '$w × $h px',
          'format': _outputFormat.name.toUpperCase(),
          'originalSize': _originalSize,
          'toolName': 'Resize Dimensions',
          'outputFormat': _outputFormat.name,
        },
      );
    }
  }

  Widget _buildFitTypeChip(ResizeFitType type, String label, IconData icon) {
    final isSelected = _fitType == type;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _fitType = type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? cs.primary.withValues(alpha: 0.15) : cs.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSelected
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? cs.primary : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorOption(Color color, String label, bool needsBorder) {
    final isSelected = _backgroundColor == color;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        setState(() {
          _backgroundColor = color;
          // Auto switch to PNG if transparent is selected
          if (color == Colors.transparent) {
            _outputFormat = OutputFormat.png;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.1)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color == Colors.transparent ? Colors.transparent : color,
                shape: BoxShape.circle,
                border: needsBorder
                    ? Border.all(color: Colors.grey.shade400, width: 0.5)
                    : null,
              ),
              child: color == Colors.transparent
                  ? const Icon(Icons.opacity, size: 14, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.radiusLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Text(
                'Resize Dimensions',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),

              if (_selectedImage == null) ...[
                // Initially show only upload image widget
                UploadArea(
                  onTap: _pickImage,
                  icon: Icons.cloud_upload_rounded,
                  title: 'Upload Image',
                  subtitle: 'Select an image to resize',
                ),
                const SizedBox(height: AppTheme.spaceLg),
              ] else ...[
                // ── Image Preview Card ──────────────────────────────
                PremiumCard(
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  child: Column(
                    children: [
                      // Selected image preview
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 170,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _selectedImage = null;
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppTheme.spaceSm),

                      // Compact Stats Row
                      Row(
                        children: [
                          // Original stat chip
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusDefault,
                                ),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.image_outlined,
                                        size: 13,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ORIGINAL',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    (_originalWidth != null &&
                                            _originalHeight != null)
                                        ? '$_originalWidth × $_originalHeight px'
                                        : (_originalDimensions.isNotEmpty
                                              ? _originalDimensions
                                              : '—'),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    _originalSize.isEmpty ? '—' : _originalSize,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Target stat chip
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusDefault,
                                ),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.aspect_ratio_rounded,
                                        size: 13,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'TARGET',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        child: const Text(
                                          'EXACT',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 7,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.2,
                                            color: Color(0xFF166534),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    (_widthController.text.isEmpty ||
                                            _heightController.text.isEmpty)
                                        ? '—'
                                        : '${_widthController.text} × ${_heightController.text} px',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Under $_targetKB KB',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),

                // ── Controls ──────────────────────────────────────────
                Text(
                  'Enter Custom Dimensions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Width field
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _widthController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  hintText: 'Width',
                                ),
                                onChanged: (val) {
                                  _onWidthChanged(val);
                                  setState(() {}); // Refresh stats display
                                },
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(right: 16, left: 5),
                              child: Text(
                                'W',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Aspect ratio lock icon
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: IconButton(
                        icon: Icon(
                          _lockAspectRatio ? Icons.link : Icons.link_off,
                          color: _lockAspectRatio
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                        onPressed: () {
                          setState(() {
                            _lockAspectRatio = !_lockAspectRatio;
                            if (_lockAspectRatio && _selectedImage != null) {
                              _onWidthChanged(_widthController.text);
                            }
                          });
                        },
                      ),
                    ),
                    // Height field
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _heightController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  hintText: 'Height',
                                ),
                                onChanged: (val) {
                                  _onHeightChanged(val);
                                  setState(() {}); // Refresh stats display
                                },
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(right: 16, left: 5),
                              child: Text(
                                'H',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceLg),

                // Fit Type Selector
                const SectionLabel('Fit Type'),
                const SizedBox(height: AppTheme.spaceSm),
                Row(
                  children: [
                    _buildFitTypeChip(
                      ResizeFitType.stretch,
                      'Stretch',
                      Icons.zoom_out_map,
                    ),
                    const SizedBox(width: 8),
                    _buildFitTypeChip(
                      ResizeFitType.fitBackground,
                      'Add Padding',
                      Icons.fit_screen,
                    ),
                    const SizedBox(width: 8),
                    _buildFitTypeChip(
                      ResizeFitType.cropFill,
                      'Crop & Fill',
                      Icons.crop_free,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceLg),

                // Background Color (shown only if fitBackground selected)
                if (_fitType == ResizeFitType.fitBackground) ...[
                  const SectionLabel('Background Color'),
                  const SizedBox(height: AppTheme.spaceSm),
                  Row(
                    children: [
                      _buildColorOption(Colors.white, 'White', true),
                      const SizedBox(width: 12),
                      _buildColorOption(Colors.black, 'Black', false),
                      const SizedBox(width: 12),
                      _buildColorOption(
                        Colors.transparent,
                        'Transparent',
                        false,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                ],

                // Compression Quality Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Compression Quality',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_targetKB KB',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSm),
                SliderTheme(
                  data: Theme.of(context).sliderTheme.copyWith(
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 20,
                    ),
                  ),
                  child: Slider(
                    value: _targetKB.toDouble().clamp(10, 500),
                    min: 10,
                    max: 500,
                    onChanged: (val) {
                      setState(() {
                        _targetKB = val.round();
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '10 KB (Smaller)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      Text(
                        '500 KB (High Quality)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),

                // Presets below Compression Quality bar
                Row(
                  children: List.generate(_presets.length, (index) {
                    final preset = _presets[index];
                    final isSelected = _targetKB == preset;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index < _presets.length - 1 ? 8 : 0,
                        ),
                        child: PresetChip(
                          label: '$preset',
                          suffix: 'kb',
                          isSelected: isSelected,
                          onTap: () => setState(() => _targetKB = preset),
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
                if (_backgroundColor == Colors.transparent &&
                    _outputFormat != OutputFormat.png) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Warning: JPEG and PDF formats do not support transparency. Transparent areas will appear black.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spaceLg),

                // ── Resize Button ───────────────────────────────────
                PrimaryActionButton(
                  label: 'Resize Image',
                  icon: Icons.bolt_rounded,
                  onPressed: _resizeImage,
                  isLoading: _isProcessing,
                ),
                const SizedBox(height: AppTheme.spaceXl),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
