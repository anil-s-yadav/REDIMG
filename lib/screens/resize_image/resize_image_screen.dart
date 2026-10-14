import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/file_service.dart';
import '../../services/image_processing_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Resize Image to KB screen matching premium_resize_image design.
class ResizeImageScreen extends StatefulWidget {
  const ResizeImageScreen({super.key});

  @override
  State<ResizeImageScreen> createState() => _ResizeImageScreenState();
}

class _ResizeImageScreenState extends State<ResizeImageScreen> {
  File? _selectedImage;
  int _targetKB = 100;
  double _sliderValue = 100;
  int _selectedPresetIndex = 3; // 100kb default
  bool _isProcessing = false;
  String _originalSize = '';
  String _originalDimensions = '';
  OutputFormat _outputFormat = OutputFormat.png;

  // New dimension-based resize state variables
  int _resizeModeIndex = 0; // 0 = By Dimensions (Px), 1 = By File Size (KB)
  int? _originalWidth;
  int? _originalHeight;
  bool _lockAspectRatio = true;
  ResizeFitType _fitType = ResizeFitType.stretch;
  Color _backgroundColor = Colors.white;
  double _qualityValue = 90; // Default compression quality for dimension resize

  // Preview generation variables
  File? _previewImage;
  bool _isGeneratingPreview = false;
  Timer? _debounceTimer;

  final _kbController = TextEditingController(text: '100');
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  final List<int> _presets = [10, 20, 50, 100];

  @override
  void dispose() {
    _kbController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _debounceTimer?.cancel();
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
        _previewImage = null; // Reset preview
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

        // Generate initial preview
        _updatePreview();
      }
    }
  }

  Future<void> _updatePreview() async {
    if (_selectedImage == null) return;

    setState(() => _isGeneratingPreview = true);

    try {
      File? result;
      if (_resizeModeIndex == 1) {
        result = await ImageProcessingService.resizeToTargetKB(
          inputPath: _selectedImage!.path,
          targetKB: _targetKB,
          isPng: _outputFormat == OutputFormat.png,
        );
      } else {
        final w = int.tryParse(_widthController.text) ?? _originalWidth ?? 300;
        final h =
            int.tryParse(_heightController.text) ?? _originalHeight ?? 300;
        result = await ImageProcessingService.resizeDimensions(
          inputPath: _selectedImage!.path,
          targetWidth: w,
          targetHeight: h,
          fitType: _fitType,
          backgroundColor: _backgroundColor,
          quality: _qualityValue.round(),
          isPng: _outputFormat == OutputFormat.png,
        );
      }

      if (result != null && mounted) {
        setState(() {
          _previewImage = result;
        });
      }
    } catch (e) {
      debugPrint('Error generating preview: $e');
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPreview = false);
      }
    }
  }

  void _debounceUpdatePreview() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _updatePreview();
    });
  }

  void _onWidthChanged(String val) {
    if (!_lockAspectRatio ||
        _originalWidth == null ||
        _originalHeight == null) {
      return;
    }
    final width = int.tryParse(val);
    if (width != null && width > 0) {
      final ratio = _originalWidth! / _originalHeight!;
      final height = (width / ratio).round();
      _heightController.text = height.toString();
    }
  }

  void _onHeightChanged(String val) {
    if (!_lockAspectRatio ||
        _originalWidth == null ||
        _originalHeight == null) {
      return;
    }
    final height = int.tryParse(val);
    if (height != null && height > 0) {
      final ratio = _originalWidth! / _originalHeight!;
      final width = (height * ratio).round();
      _widthController.text = width.toString();
    }
  }

  void _setPreset(int index) {
    setState(() {
      _selectedPresetIndex = index;
      _targetKB = _presets[index];
      _sliderValue = _targetKB.toDouble();
      _kbController.text = _targetKB.toString();
    });
    _updatePreview();
  }

  Future<void> _resizeImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    File? result;
    String finalDimensions = '';
    String toolName = '';

    if (_resizeModeIndex == 1) {
      result = await ImageProcessingService.resizeToTargetKB(
        inputPath: _selectedImage!.path,
        targetKB: _targetKB,
        isPng: _outputFormat == OutputFormat.png,
      );
      finalDimensions = _originalDimensions;
      toolName = 'Resize Image to KB';
    } else {
      final w = int.tryParse(_widthController.text);
      final h = int.tryParse(_heightController.text);
      if (w == null || w <= 0 || h == null || h <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid width and height')),
        );
        setState(() => _isProcessing = false);
        return;
      }

      result = await ImageProcessingService.resizeDimensions(
        inputPath: _selectedImage!.path,
        targetWidth: w,
        targetHeight: h,
        fitType: _fitType,
        backgroundColor: _backgroundColor,
        quality: _qualityValue.round(),
        isPng: _outputFormat == OutputFormat.png,
      );
      finalDimensions = '$w × $h px';
      toolName = 'Resize Dimensions';
    }

    setState(() => _isProcessing = false);

    if (result != null && mounted) {
      final fileSize = ImageProcessingService.formatFileSize(
        await result.length(),
      );
      context.push(
        '/result',
        extra: {
          'filePath': result.path,
          'fileSize': fileSize,
          'dimensions': finalDimensions,
          'format': _outputFormat.name.toUpperCase(),
          'originalSize': _originalSize,
          'toolName': toolName,
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
          _updatePreview();
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
        _updatePreview();
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
                _resizeModeIndex == 0
                    ? 'Resize Dimensions'
                    : 'Target File Size',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              // ── Mode Switcher ──────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _resizeModeIndex = 0);
                          _updatePreview();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _resizeModeIndex == 0
                                ? Theme.of(context).colorScheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _resizeModeIndex == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'By Dimensions (Px)',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: _resizeModeIndex == 0
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: _resizeModeIndex == 0
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _resizeModeIndex = 1);
                          _updatePreview();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _resizeModeIndex == 1
                                ? Theme.of(context).colorScheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _resizeModeIndex == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'By File Size (KB)',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: _resizeModeIndex == 1
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: _resizeModeIndex == 1
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // const SizedBox(height: AppTheme.spaceLg),

              // ── Image Preview / Upload ──────────────────────────
              PremiumCard(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Column(
                  children: [
                    // Before / After comparison view
                    if (_selectedImage != null) ...[
                      Stack(
                        children: [
                          ImageComparisonSlider(
                            original: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                            preview: _previewImage != null
                                ? Image.file(_previewImage!, fit: BoxFit.cover)
                                : Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          if (_isGeneratingPreview)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ] else ...[
                      UploadArea(
                        onTap: _pickImage,
                        icon: Icons.cloud_upload_rounded,
                        title: 'Upload Image',
                        subtitle: 'Select an image to resize',
                      ),
                    ],

                    const SizedBox(height: AppTheme.spaceSm),

                    // Stats row
                    Row(
                      children: [
                        // Original stat
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(AppTheme.spaceSm),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusDefault,
                              ),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHigh,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.image,
                                      size: 16,
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
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _originalSize.isEmpty ? '—' : _originalSize,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                if (_originalDimensions.isNotEmpty)
                                  Text(
                                    _originalDimensions,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w300,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceSm),
                        // Final stat / Target dimensions stat
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(AppTheme.spaceSm),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusDefault,
                              ),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _resizeModeIndex == 1
                                          ? Icons.compress
                                          : Icons.aspect_ratio,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _resizeModeIndex == 1
                                          ? 'FINAL SIZE'
                                          : 'NEW DIMENSIONS',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    if (_resizeModeIndex == 1) ...[
                                      Text(
                                        '$_targetKB',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'KB',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                        ),
                                      ),
                                    ] else ...[
                                      Expanded(
                                        child: Text(
                                          (_widthController.text.isEmpty ||
                                                  _heightController
                                                      .text
                                                      .isEmpty)
                                              ? '—'
                                              : '${_widthController.text} × ${_heightController.text}',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer,
                                            height: 1,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'px',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.verified,
                                        size: 12,
                                        color: Color(0xFF16A34A),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        _resizeModeIndex == 1
                                            ? 'GUARANTEED UNDER LIMIT'
                                            : 'EXACT TARGET RESOLUTION',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                          color: Color(0xFF166534),
                                        ),
                                      ),
                                    ],
                                  ),
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

              // const SizedBox(height: AppTheme.spaceLg),

              // ── Mode-Specific Controls ──────────────────────────
              if (_resizeModeIndex == 0) ...[
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
                    Text(
                      '${_qualityValue.round()}%',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Slider(
                  value: _qualityValue,
                  min: 1,
                  max: 100,
                  onChanged: (val) => setState(() => _qualityValue = val),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Smaller File',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      Text(
                        'Higher Quality',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 5),
              ] else ...[
                // ── Target Size Input ───────────────────────────────
                Text(
                  'Enter Target Size Limit',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Container(
                  height: 64,
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
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                          onChanged: (val) {
                            final kb = int.tryParse(val);
                            if (kb != null && kb > 0) {
                              setState(() {
                                _targetKB = kb;
                                _sliderValue = kb.toDouble().clamp(10, 500);
                                _selectedPresetIndex = _presets.indexOf(kb);
                              });
                            }
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

                const SizedBox(height: AppTheme.spaceMd),

                // ── Slider ──────────────────────────────────────────
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
                    value: _sliderValue.clamp(10, 500),
                    min: 10,
                    max: 500,
                    onChanged: (val) {
                      setState(() {
                        _sliderValue = val;
                        _targetKB = val.round();
                        _kbController.text = _targetKB.toString();
                        _selectedPresetIndex = _presets.indexOf(_targetKB);
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
                        '10 KB',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      Text(
                        'Max Quality',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 32),

                // ── Quick Presets ────────────────────────────────────
                const SectionLabel('Quick Presets'),
                const SizedBox(height: AppTheme.spaceSm),
                Row(
                  children: List.generate(_presets.length, (index) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index < _presets.length - 1 ? 8 : 0,
                        ),
                        child: PresetChip(
                          label: '${_presets[index]}',
                          suffix: 'kb',
                          isSelected: _selectedPresetIndex == index,
                          onTap: () => _setPreset(index),
                        ),
                      ),
                    );
                  }),
                ),
              ],

              const SizedBox(height: AppTheme.spaceLg),

              // ── Output Format ────────────────────────────────────
              FormatPicker(
                selected: _outputFormat,
                onChanged: (fmt) => setState(() => _outputFormat = fmt),
              ),
              if (_resizeModeIndex == 0 &&
                  _backgroundColor == Colors.transparent &&
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
          ),
        ),
      ),
    );
  }
}
