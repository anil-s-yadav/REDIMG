import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/photo_preset.dart';
import '../../services/file_service.dart';
import '../../services/image_processing_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Passport Photo Maker screen matching the auto_standard_mode design.
class PassportPhotoScreen extends StatefulWidget {
  const PassportPhotoScreen({super.key});

  @override
  State<PassportPhotoScreen> createState() => _PassportPhotoScreenState();
}

class _PassportPhotoScreenState extends State<PassportPhotoScreen> {
  File? _selectedImage;
  int _selectedPresetIndex = 0;
  bool _isProcessing = false;
  OutputFormat _outputFormat = OutputFormat.png;
  int _bgIndex = 0; // 0 = White, 1 = Black, 2 = Stretch

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _uploadSectionKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile != null) {
      setState(() => _selectedImage = File(xFile.path));
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final preset = PhotoPreset.presets[_selectedPresetIndex];

    ResizeFitType fitType = ResizeFitType.fitBackground;
    Color bgColor = Colors.white;
    if (_bgIndex == 1) {
      bgColor = Colors.black;
    } else if (_bgIndex == 2) {
      fitType = ResizeFitType.stretch;
    }

    final result = await ImageProcessingService.createPassportPhoto(
      inputPath: _selectedImage!.path,
      widthMm: preset.widthMm,
      heightMm: preset.heightMm,
      targetKB: preset.targetKB,
      fitType: fitType,
      backgroundColor: bgColor,
    );

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
          'dimensions': '${preset.widthMm}x${preset.heightMm} mm',
          'format': 'JPEG',
          'originalSize': _selectedImage != null
              ? ImageProcessingService.formatFileSize(
                  await _selectedImage!.length(),
                )
              : '',
          'toolName': 'Passport Photo Maker',
          'outputFormat': _outputFormat.name,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = PhotoPreset.presets;
    final selected = presets[_selectedPresetIndex];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(AppTheme.containerMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Text(
                'Auto KB + Dimension\nMode',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                'One-click optimization for standard document requirements.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // ── Select Standard ─────────────────────────────────
              Text(
                'Select Standard',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),

              // Preset Cards
              ...List.generate(presets.length, (index) {
                final preset = presets[index];
                final isSelected = index == _selectedPresetIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                  child: _PresetCard(
                    preset: preset,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() => _selectedPresetIndex = index);
                      // Scroll to upload area after build
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final context = _uploadSectionKey.currentContext;
                        if (context != null) {
                          Scrollable.ensureVisible(
                            context,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      });
                    },
                  ),
                );
              }),

              const SizedBox(height: AppTheme.spaceLg),

              // ── Upload Area ─────────────────────────────────────
              Container(
                key: _uploadSectionKey,
                child: UploadArea(
                  onTap: _pickImage,
                  icon: Icons.cloud_upload_rounded,
                  title: 'Drag & Drop Image',
                  subtitle: 'or click to browse files',
                  hasFile: _selectedImage != null,
                  preview: _selectedImage != null
                      ? Stack(
                          children: [
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                                child: Image.file(
                                  _selectedImage!,
                                  width: 300,
                                  height: 300,
                                  fit: BoxFit.cover,
                                ),
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
                          ],
                        )
                      : null,
                ),
              ),

              // if (_selectedImage == null) ...[
              //   const SizedBox(height: AppTheme.spaceMd),
              //   Center(
              //     child: OutlinedButton(
              //       onPressed: _pickImage,
              //       child: const Text('Browse Files'),
              //     ),
              //   ),
              // ],
              const SizedBox(height: AppTheme.spaceLg),

              // ── Automated Settings ──────────────────────────────
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Automated Settings',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    _SettingRow(
                      icon: Icons.photo_size_select_large_rounded,
                      label: 'Target File Size',
                      value: selected.targetText,
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    _SettingRow(
                      icon: Icons.crop_rounded,
                      label: 'Crop Dimensions',
                      value:
                          '${selected.widthMm / 10} × ${selected.heightMm / 10} cm',
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    _SettingRow(
                      icon: Icons.image_rounded,
                      label: 'Output Format',
                      value: 'JPEG',
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                            Icons.palette_rounded,
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Background',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _bgIndex = 0),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _bgIndex == 0
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer
                                          : Colors.grey.shade300,
                                      width: _bgIndex == 0 ? 2 : 1,
                                    ),
                                  ),
                                  child: _bgIndex == 0
                                      ? Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() => _bgIndex = 1),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _bgIndex == 1
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer
                                          : Colors.transparent,
                                      width: _bgIndex == 1 ? 2 : 0,
                                    ),
                                  ),
                                  child: _bgIndex == 1
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() => _bgIndex = 2),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _bgIndex == 2
                                        ? Theme.of(context).colorScheme.primary
                                              .withValues(alpha: 0.15)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _bgIndex == 2
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer
                                          : Colors.transparent,
                                      width: _bgIndex == 2 ? 2 : 0,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.fit_screen_rounded,
                                    size: 16,
                                    color: _bgIndex == 2
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

              // ── Process Button ──────────────────────────────────
              PrimaryActionButton(
                label: 'Process Image',
                icon: Icons.auto_awesome,
                onPressed: _processImage,
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

/// Card for each document type preset.
class _PresetCard extends StatelessWidget {
  final PhotoPreset preset;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PresetCard({
    required this.preset,
    required this.isSelected,
    this.onTap,
  });

  IconData get _presetIcon {
    switch (preset.icon) {
      case 'badge':
        return Icons.badge_rounded;
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'flight':
        return Icons.flight_rounded;
      default:
        return Icons.badge_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Icon(
              _presetIcon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.description,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Row showing an automated setting (icon + label + value chip).
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
