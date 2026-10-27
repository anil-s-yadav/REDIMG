import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';

/// Per-tool accent colors for the home bento grid.
abstract final class _HomeToolColors {
  static const passport = Color(0xFF2563EB);
  static const resize = Color(0xFF0891B2);
  static const signature = Color(0xFF7C3AED);
  static const compress = Color(0xFF3B82F6);
  static const combine = Color(0xFF16A34A);
  static const imageToPdf = Color(0xFFDC2626);

  static LinearGradient gradientFor(Color accent) => LinearGradient(
    colors: [accent, Color.lerp(accent, Colors.white, 0.28)!],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Home screen matching the Stitch home_dashboard design.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : AppColors.surfaceContainerLow,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.containerMargin),
          child: Column(
            spacing: 3,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section Header ────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.red.shade800,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  RichText(
                    text: TextSpan(
                      // style: TextStyle(letterSpacing: 2),
                      children: [
                        TextSpan(
                          text: 'RED',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                        ),
                        TextSpan(
                          text: 'IMG ',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                        ),
                        TextSpan(
                          text: 'Tools',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                // fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                'Select a utility to process your images.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // ── Bento Grid ───────────────────────────────────────────
              // Row 1: Passport Photo Maker (full width, highlighted)
              _HighlightToolCard(
                title: 'Passport Photo Maker',
                subtitle:
                    'For Aadhar, PAN, Gov forms, Office, School & College.',
                icon: Icons.badge_rounded,
                accent: _HomeToolColors.passport,
                onTap: () => context.push('/passport-photo'),
              ),
              const SizedBox(height: AppTheme.gutter),

              // Row 2: Resize Image to KB (full width)
              _HighlightToolCard(
                title: 'Change height & width',
                subtitle: 'Change image dimentions and compress too.',
                icon: Icons.aspect_ratio_rounded,
                accent: _HomeToolColors.resize,
                onTap: () => context.push('/resize-image'),
              ),
              const SizedBox(height: AppTheme.gutter),

              // Row 3: 2-column grid
              Row(
                children: [
                  Expanded(
                    child: _SmallToolCard(
                      title: 'Compress Image MB to KB',
                      icon: Icons.image,
                      
                      accent: _HomeToolColors.compress,
                      onTap: () => context.push('/compress-image'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.gutter),
                  Expanded(
                    child: _SmallToolCard(
                      title: 'Combine \nPhoto + Signature',
                      customIcon: const _CombineToolLayoutIcon(),
                      accent: _HomeToolColors.combine,
                      onTap: () => context.push('/combine-tool'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.gutter),

              // Row 4: 2-column grid
              Row(
                children: [
                  Expanded(
                    child: _SmallToolCard(
                      title: 'Signature Maker',
                      icon: Icons.draw_rounded,
                      accent: _HomeToolColors.signature,
                      onTap: () => context.push('/signature-maker'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.gutter),
                  Expanded(
                    child: _SmallToolCard(
                      title: 'Image to PDF',
                      icon: Icons.picture_as_pdf_rounded,
                      accent: _HomeToolColors.imageToPdf,
                      onTap: () => context.push('/image-to-pdf'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceXl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large horizontal tool card (Passport Photo, Resize to KB).
class _HighlightToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const _HighlightToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          // border: Border.all(color: accent.withOpacity(isDark ? 0.35 : 0.25)),
          boxShadow: [
            BoxShadow(
              color: accent.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(1, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: _HomeToolColors.gradientFor(accent),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(1, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: accent.withValues(alpha: 0.7),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small vertical tool card (Signature, Compress, Combine, Image to PDF).
class _SmallToolCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? customIcon;
  final Color accent;
  final VoidCallback? onTap;

  const _SmallToolCard({
    required this.title,
    this.icon,
    this.customIcon,
    required this.accent,
    this.onTap,
  }) : assert(icon != null || customIcon != null);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: accent.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(1, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customIcon != null)
              customIcon!
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Miniature document layout showing the Combine Photo + Signature output in color.
class _CombineToolLayoutIcon extends StatelessWidget {
  const _CombineToolLayoutIcon();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = _HomeToolColors.combine;

    return Container(
      width: 44,
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.75 : 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.3 : 0.16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2.5),
      child: Column(
        children: [
          // ── Photo Area (Top ~70%) ──────────────────────────────
          Expanded(
            flex: 7,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE0F2FE), // Soft passport sky blue backdrop
                    Color(0xFFBAE6FD),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF7DD3FC),
                  width: 0.8,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: Color(0xFF0284C7), // Blue avatar
                  ),
                  SizedBox(height: 1),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 1.5),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Photo Area',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 5.2,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0369A1),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 2),

          // ── Signature Area (Bottom ~30%) ───────────────────────
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1),
                  width: 0.8,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.draw_rounded,
                      size: 8,
                      color: Color(0xFF16A34A), // Combine green
                    ),
                    SizedBox(width: 1.5),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Signature Area',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 4.8,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
