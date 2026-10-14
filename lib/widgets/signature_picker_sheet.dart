import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/file_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Shows a bottom sheet allowing the user to pick a signature
/// either from their device gallery or from saved signatures in the app.
Future<File?> showSignaturePickerSheet(BuildContext context) async {
  return showModalBottomSheet<File?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _SignaturePickerSheetContent(),
  );
}

class _SignaturePickerSheetContent extends StatefulWidget {
  const _SignaturePickerSheetContent();

  @override
  State<_SignaturePickerSheetContent> createState() =>
      _SignaturePickerSheetContentState();
}

class _SignaturePickerSheetContentState
    extends State<_SignaturePickerSheetContent> {
  List<SavedFileMeta> _savedSignatures = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  Future<void> _loadSignatures() async {
    setState(() => _isLoading = true);
    final signatures = await FileService.getSavedSignatures();
    if (mounted) {
      setState(() {
        _savedSignatures = signatures;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile != null && mounted) {
      Navigator.of(context).pop(File(xFile.path));
    }
  }

  void _createNewSignature() {
    Navigator.of(context).pop();
    context.push('/signature-maker');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetHeight = MediaQuery.of(context).size.height * 0.78;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
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
          const SizedBox(height: 12),

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
                      Text(
                        'Select Signature',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose from gallery or your saved signatures',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
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
          const SizedBox(height: AppTheme.spaceSm),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),

          // ── Content ─────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.containerMargin),
              children: [
                // Option 1: Pick from Gallery
                _SourceOptionCard(
                  icon: Icons.photo_library_outlined,
                  iconColor: AppColors.primary,
                  title: 'Choose from Gallery',
                  subtitle: 'Select an existing signature image or PNG from device',
                  onTap: _pickFromGallery,
                ),
                const SizedBox(height: 12),

                // Option 2: Create in Signature Maker
                _SourceOptionCard(
                  icon: Icons.draw_outlined,
                  iconColor: AppColors.tertiary,
                  title: 'Create New Signature',
                  subtitle: 'Draw and save a new digital signature in REDIMG',
                  onTap: _createNewSignature,
                ),
                const SizedBox(height: AppTheme.spaceLg),

                // ── Section Title: Saved in App ──────────────────────
                Row(
                  children: [
                    Icon(
                      Icons.history_edu_rounded,
                      size: 20,
                      color: cs.primaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Saved in App',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_savedSignatures.length}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!_isLoading)
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        tooltip: 'Refresh',
                        onPressed: _loadSignatures,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        color: cs.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceMd),

                // ── Saved Signatures Grid / Empty ────────────────────
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_savedSignatures.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? cs.surfaceContainerLowest
                          : cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.draw_rounded,
                            color: AppColors.tertiary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No saved signatures yet',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Signatures you draw and save in Signature Maker will appear here for easy reuse.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _savedSignatures.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.15,
                    ),
                    itemBuilder: (context, index) {
                      final item = _savedSignatures[index];
                      final file = File(item.filePath);
                      return _SavedSignatureCard(
                        meta: item,
                        file: file,
                        onSelect: () =>
                            Navigator.of(context).pop(file),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceOptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceOptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLowest : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: cs.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedSignatureCard extends StatelessWidget {
  final SavedFileMeta meta;
  final File file;
  final VoidCallback onSelect;

  const _SavedSignatureCard({
    required this.meta,
    required this.file,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLowest : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Signature image preview box
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: file.existsSync()
                        ? Image.file(
                            file,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.grey,
                            ),
                          )
                        : const Icon(
                            Icons.draw_rounded,
                            color: Colors.grey,
                          ),
                  ),
                ),
                const SizedBox(height: 8),

                // Name and Meta
                Text(
                  meta.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      meta.formattedSize,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '•',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.outline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        meta.formattedDate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
