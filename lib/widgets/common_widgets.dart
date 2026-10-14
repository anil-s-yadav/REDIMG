import 'package:flutter/material.dart';
import '../../services/file_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Primary gradient action button matching Stitch's CTA buttons.
class PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? height;

  const PrimaryActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Ink(
          height: height ?? 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.onPrimary,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Upload area widget matching Stitch's dashed-border upload zones.
class UploadArea extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool hasFile;
  final Widget? preview;

  const UploadArea({
    super.key,
    this.onTap,
    this.icon = Icons.cloud_upload_outlined,
    this.title = 'Click to upload',
    this.subtitle = 'or drag and drop file here',
    this.hasFile = false,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    if (hasFile && preview != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: preview!,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            style: BorderStyle.solid,
          ),
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: AppTheme.radiusMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
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
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;

  _DashedBorderPainter({required this.color, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    // We skip painting since the container already has a border.
    // This is kept as a stub in case dashed borders are needed later.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Preset chip button used in Resize and Signature screens.
class PresetChip extends StatelessWidget {
  final String label;
  final String? suffix;
  final bool isSelected;
  final VoidCallback? onTap;

  const PresetChip({
    super.key,
    required this.label,
    this.suffix,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Center(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (suffix != null)
                  TextSpan(
                    text: ' $suffix',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: isSelected
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header matching the Stitch label-caps style.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Premium card container with Stitch's Level 2 shadow.
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}

/// Reusable output format picker (PNG / JPEG / PDF).
class FormatPicker extends StatelessWidget {
  final OutputFormat selected;
  final ValueChanged<OutputFormat> onChanged;

  const FormatPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Save As',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        Row(
          children: [
            for (final fmt in OutputFormat.values) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(fmt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected == fmt
                          ? cs.primary.withValues(alpha: 0.15)
                          : cs.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: selected == fmt
                            ? cs.primary
                            : cs.outlineVariant.withValues(alpha: 0.5),
                        width: selected == fmt ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        fmt.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selected == fmt ? cs.primary : cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (fmt != OutputFormat.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

/// A draggable split-screen before/after image comparison slider.
class ImageComparisonSlider extends StatefulWidget {
  final Widget original;
  final Widget preview;
  final double height;

  const ImageComparisonSlider({
    super.key,
    required this.original,
    required this.preview,
    this.height = 220,
  });

  @override
  State<ImageComparisonSlider> createState() => _ImageComparisonSliderState();
}

class _ImageComparisonSliderState extends State<ImageComparisonSlider> {
  double _sliderPosition = 0.5;

  void _updatePosition(Offset globalPosition, double width) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final localPos = renderBox.globalToLocal(globalPosition);
      setState(() {
        _sliderPosition = (localPos.dx / width).clamp(0.0, 1.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) =>
                _updatePosition(details.globalPosition, width),
            onPanUpdate: (details) =>
                _updatePosition(details.globalPosition, width),
            onTapDown: (details) =>
                _updatePosition(details.globalPosition, width),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Preview image (underneath/right side)
                widget.preview,

                // 2. Original image (on top, clipped to show only the left part)
                ClipRect(
                  child: Align(
                    alignment: Alignment.topLeft,
                    widthFactor: _sliderPosition,
                    child: SizedBox(
                      width: width,
                      height: widget.height,
                      child: widget.original,
                    ),
                  ),
                ),

                // 3. Original Label (top-left)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ORIGINAL',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),

                // 4. Preview Label (top-right)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'PREVIEW',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),

                // 5. Divider line
                Positioned(
                  left: width * _sliderPosition - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: Colors.white),
                ),

                // 6. Handle circle with chevrons
                Positioned(
                  left: width * _sliderPosition - 16,
                  top: widget.height / 2 - 16,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).shadowColor.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 14,
                          color: Colors.black87,
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: Colors.black87,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
