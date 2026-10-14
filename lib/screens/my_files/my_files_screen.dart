import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/file_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/signature_viewer_modal.dart';
import '../../widgets/trimmed_signature_image.dart';

/// Screen showing all user-created files organized in tabs.
class MyFilesScreen extends StatefulWidget {
  const MyFilesScreen({super.key});

  @override
  State<MyFilesScreen> createState() => _MyFilesScreenState();
}

class _MyFilesScreenState extends State<MyFilesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SavedFileMeta> _allFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    final files = await FileService.getSavedFiles();
    if (mounted) {
      setState(() {
        _allFiles = files;
        _isLoading = false;
      });
    }
  }

  List<SavedFileMeta> _filterByCategory(String? category) {
    if (category == null) return _allFiles;
    return _allFiles.where((f) => f.category == category).toList();
  }

  Future<void> _deleteFile(SavedFileMeta meta) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete "${meta.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FileService.deleteFile(meta.filePath);
      _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${meta.name}" deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : AppColors.surfaceContainerLow,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.containerMargin,
                AppTheme.containerMargin,
                AppTheme.containerMargin,
                AppTheme.spaceSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Files',
                    style: Theme.of(
                      context,
                    ).textTheme.displayMedium?.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    '${_allFiles.length} file${_allFiles.length == 1 ? '' : 's'} saved to Downloads/RedImage/',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            // ── Tab Bar ─────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppTheme.containerMargin,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? cs.surfaceContainerLow
                    : cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.3 : 0.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: cs.onPrimary,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Signs'),
                  Tab(text: 'Images'),
                  Tab(text: 'PDFs'),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),

            // ── Tab Content ─────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFileList(null),
                        _buildFileList('signature'),
                        _buildFileList('image'),
                        _buildFileList('pdf'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(String? category) {
    final files = _filterByCategory(category);

    if (files.isEmpty) {
      return _EmptyState(category: category, onRefresh: _loadFiles);
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.containerMargin,
        ),
        itemCount: files.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _FileCard(
          meta: files[index],
          onShare: () => FileService.shareFile(files[index].filePath),
          onDelete: () => _deleteFile(files[index]),
        ),
      ),
    );
  }
}

// ── File Card ─────────────────────────────────────────────────────────────
class _FileCard extends StatelessWidget {
  final SavedFileMeta meta;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _FileCard({
    required this.meta,
    required this.onShare,
    required this.onDelete,
  });

  IconData get _categoryIcon {
    switch (meta.category) {
      case 'signature':
        return Icons.draw_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      default:
        return Icons.image_rounded;
    }
  }

  Color get _categoryColor {
    switch (meta.category) {
      case 'signature':
        return AppColors.tertiary;
      case 'pdf':
        return AppColors.error;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = _categoryColor;
    final isImage = meta.category == 'image' || meta.category == 'signature';
    final file = File(meta.filePath);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
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
          onTap: () {
            if (meta.category == 'signature') {
              showSignatureViewerModal(
                context,
                meta: meta,
                onDelete: onDelete,
              );
            } else {
              FileService.openFile(meta.filePath);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail / Icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: meta.category == 'signature'
                        ? Colors.white
                        : catColor.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: meta.category == 'signature'
                          ? cs.outlineVariant.withValues(alpha: 0.6)
                          : Colors.transparent,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  padding: meta.category == 'signature'
                      ? const EdgeInsets.all(4)
                      : EdgeInsets.zero,
                  child: isImage && file.existsSync()
                      ? (meta.category == 'signature'
                          ? TrimmedSignatureImage(
                              file: file,
                              fit: BoxFit.contain,
                              errorWidget: Icon(
                                _categoryIcon,
                                color: catColor,
                                size: 24,
                              ),
                            )
                          : Image.file(
                              file,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                _categoryIcon,
                                color: catColor,
                                size: 24,
                              ),
                            ))
                      : Icon(_categoryIcon, color: catColor, size: 24),

                ),
                const SizedBox(width: 14),

                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _InfoChip(label: meta.format, color: catColor),
                          const SizedBox(width: 8),
                          Text(
                            meta.formattedSize,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            meta.formattedDate,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (meta.toolName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta.toolName,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ), // Actions
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'view') {
                      showSignatureViewerModal(
                        context,
                        meta: meta,
                        onDelete: onDelete,
                      );
                    }
                    if (value == 'open') FileService.openFile(meta.filePath);
                    if (value == 'share') onShare();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    if (meta.category == 'signature')
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('View Signature'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Open External'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Share'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.red,
                          ),
                          SizedBox(width: 10),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
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

// ── Info Chip ─────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String? category;
  final VoidCallback onRefresh;

  const _EmptyState({this.category, required this.onRefresh});

  String get _title {
    switch (category) {
      case 'signature':
        return 'No signatures yet';
      case 'image':
        return 'No images yet';
      case 'pdf':
        return 'No PDFs yet';
      default:
        return 'No files yet';
    }
  }

  String get _subtitle {
    switch (category) {
      case 'signature':
        return 'Create a signature using the\nSignature Maker tool.';
      case 'image':
        return 'Process images using the\nPassport Photo or Resize tools.';
      case 'pdf':
        return 'Convert images to PDF using\nthe Image to PDF tool.';
      default:
        return 'Files you create will appear here.\nStart by using any tool.';
    }
  }

  IconData get _icon {
    switch (category) {
      case 'signature':
        return Icons.draw_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      default:
        return Icons.folder_open_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.containerMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 32, color: cs.primary),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              _title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
