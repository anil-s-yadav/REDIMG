import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/file_service.dart';
import '../../services/image_processing_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Compress Image screen.
class CompressImageScreen extends StatefulWidget {
  const CompressImageScreen({super.key});

  @override
  State<CompressImageScreen> createState() => _CompressImageScreenState();
}

class _CompressImageScreenState extends State<CompressImageScreen> {
  File? _selectedImage;
  double _quality = 80;
  bool _isCompressing = false;
  String _originalSize = '';
  OutputFormat _outputFormat = OutputFormat.png;

  // Target size compression state
  int _compressModeIndex = 0; // 0 = By Target Size (KB), 1 = By Quality (%)
  int _targetKB = 100;
  int _selectedPresetIndex = 3; // 100kb chip
  final _kbController = TextEditingController(text: '100');
  final List<int> _presets = [10, 20, 50, 100];

  @override
  void dispose() {
    _kbController.dispose();
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
      });
    }
  }

  Future<void> _compressImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    setState(() => _isCompressing = true);

    File? result;
    if (_compressModeIndex == 0) {
      result = await ImageProcessingService.resizeToTargetKB(
        inputPath: _selectedImage!.path,
        targetKB: _targetKB,
        isPng: _outputFormat == OutputFormat.png,
      );
    } else {
      result = await ImageProcessingService.compressImage(
        inputPath: _selectedImage!.path,
        quality: _quality.round(),
      );
    }

    setState(() => _isCompressing = false);

    if (result != null && mounted) {
      final fileSize = ImageProcessingService.formatFileSize(
        await result.length(),
      );
      context.push(
        '/result',
        extra: {
          'filePath': result.path,
          'fileSize': fileSize,
          'dimensions': '',
          'format': _outputFormat.name.toUpperCase(),
          'originalSize': _originalSize,
          'toolName': 'Compress Image',
          'outputFormat': _outputFormat.name,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimatedPercent = (100 - _quality).round();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.containerMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Text(
                'Compress Image',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),

              // ── Upload Area ─────────────────────────────────────
              UploadArea(
                onTap: _pickImage,
                icon: Icons.cloud_upload_rounded,
                title: 'Upload Image',
                subtitle: 'Select an image to compress',
                hasFile: _selectedImage != null,
                preview: _selectedImage != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            child: Image.file(
                              _selectedImage!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedImage = null),
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
                          if (_originalSize.isNotEmpty)
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Original: $_originalSize',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : null,
              ),

              const SizedBox(height: AppTheme.spaceXs),

              // ── Mode Switcher ──────────────────────────────────
              Container(

                width: double.infinity,
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / 2;
                    return Stack(
                      children: [
                        // Sliding indicator pill (no blinking, smooth slide)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOutCubic,
                          left: _compressModeIndex == 0 ? 0 : itemWidth,
                          top: 0,
                          bottom: 0,
                          width: itemWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Tab labels
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (_compressModeIndex != 0) {
                                    setState(() => _compressModeIndex = 0);
                                  }
                                },
                                child: Center(
                                  child: Text(
                                    'By Target Size (KB)',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: _compressModeIndex == 0
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: _compressModeIndex == 0
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (_compressModeIndex != 1) {
                                    setState(() => _compressModeIndex = 1);
                                  }
                                },
                                child: Center(
                                  child: Text(
                                    'By Quality (%)',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: _compressModeIndex == 1
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: _compressModeIndex == 1
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),


              // const SizedBox(height: AppTheme.spaceMd),
              // ── Compress Controls ───────────────────────────────
              if (_compressModeIndex == 0) ...[
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter Target Size Limit',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      Container(
                        height: 50,
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
                                controller: _kbController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
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
                                      _selectedPresetIndex = _presets.indexOf(
                                        kb,
                                      );
                                    });
                                  }
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                right: 16,
                                left: 10,
                              ),
                              child: Text(
                                'KB',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
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
                          onTap: () {
                            setState(() {
                              _selectedPresetIndex = index;
                              _targetKB = _presets[index];
                              _kbController.text = _targetKB.toString();
                            });
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ] else ...[
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Compression Quality',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_quality.round()}%',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      SliderTheme(
                        data: Theme.of(context).sliderTheme.copyWith(
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 10,
                          ),
                        ),
                        child: Slider(
                          value: _quality,
                          min: 1,
                          max: 100,
                          onChanged: (val) => setState(() => _quality = val),
                        ),
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
                      const SizedBox(height: AppTheme.spaceMd),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusDefault,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Estimated ~$estimatedPercent% reduction in file size',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                const SectionLabel('Quick Quality'),
                const SizedBox(height: AppTheme.spaceSm),
                Row(
                  children: [
                    for (final q in [30, 50, 70, 90]) ...[
                      Expanded(
                        child: PresetChip(
                          label: '$q%',
                          isSelected: _quality.round() == q,
                          onTap: () => setState(() => _quality = q.toDouble()),
                        ),
                      ),
                      if (q != 90) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],

              const SizedBox(height: AppTheme.spaceLg),

              // ── Output Format ────────────────────────────────────
              FormatPicker(
                selected: _outputFormat,
                onChanged: (fmt) => setState(() => _outputFormat = fmt),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // ── Compress Button ─────────────────────────────────
              PrimaryActionButton(
                label: 'Compress Image',
                icon: Icons.compress_rounded,
                onPressed: _compressImage,
                isLoading: _isCompressing,
              ),
              const SizedBox(height: AppTheme.spaceXl),
            ],
          ),
        ),
      ),
    );
  }
}
