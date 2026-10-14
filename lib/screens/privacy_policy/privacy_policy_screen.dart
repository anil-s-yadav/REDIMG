import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Privacy Policy screen for REDIMG.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _contactEmail = 'redpdftools@gmail.com';
  static const String _lastUpdated = 'October 2026';

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: {'subject': 'REDIMG App - Privacy Inquiry'},
    );
    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _copyEmail(context);
      }
    } catch (_) {
      if (context.mounted) _copyEmail(context);
    }
  }

  void _copyEmail(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _contactEmail));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Email copied: $_contactEmail'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.containerMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────
              Text(
                'Privacy Policy',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Last updated: $_lastUpdated',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // ── Highlights Row ────────────────────────────────────
              Row(
                children: [
                  _buildBadge(context, Icons.cloud_off_rounded, '100% Offline'),
                  const SizedBox(width: 8),
                  _buildBadge(context, Icons.person_off_rounded, 'No Accounts'),
                  const SizedBox(width: 8),
                  _buildBadge(
                    context,
                    Icons.visibility_off_rounded,
                    'Zero Tracking',
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceLg),

              _buildSection(
                context,
                icon: Icons.info_outline_rounded,
                title: 'Introduction',
                content:
                    'REDIMG ("we", "our", or "us") is committed to protecting your privacy. '
                    'This Privacy Policy explains how our mobile application REDIMG ("the App") '
                    'handles information when you use our image processing tools. '
                    'By using the App, you agree to the practices described in this policy.',
              ),

              _buildSection(
                context,
                icon: Icons.no_accounts_rounded,
                title: 'Information Collection',
                content:
                    'REDIMG does not collect, store, or transmit any personal data. '
                    'We do not require you to create an account, log in, or provide any '
                    'personal information to use the App.\n\n'
                    '• No personal data is collected\n'
                    '• No usage analytics or tracking\n'
                    '• No advertising identifiers\n'
                    '• No cookies or web beacons',
              ),

              // ── Permissions Used ────────────────────────────────
              _buildPermissionsSection(context),

              _buildSection(
                context,
                icon: Icons.phone_android_rounded,
                title: 'Data Storage & Processing',
                content:
                    'All data processed by REDIMG stays entirely on your device. '
                    'Images you process, signatures you create, and PDF files you generate '
                    'are saved locally in your device\'s Downloads folder.\n\n'
                    '• No cloud storage or sync\n'
                    '• No server-side processing\n'
                    '• All processing happens on-device\n'
                    '• You have full control over your files\n'
                    '• Temporary processing files are automatically cleaned up upon completion',
              ),

              _buildSection(
                context,
                icon: Icons.block_rounded,
                title: 'Third-Party Services & Tracking',
                content:
                    'REDIMG does not integrate with any third-party analytics, advertising, '
                    'or data collection services. The only external service used is '
                    'Google Play\'s in-app update API, which is governed by Google\'s '
                    'own privacy policy.\n\n'
                    '• NO Analytics or Telemetry\n'
                    '• NO Advertisements\n'
                    '• NO Data Sharing with third parties',
              ),

              _buildSection(
                context,
                icon: Icons.child_care_rounded,
                title: 'Children\'s Privacy',
                content:
                    'REDIMG is a general-purpose image utility tool suitable for users of '
                    'all ages. We do not knowingly collect any personal information from '
                    'children or any other users. The App does not contain any '
                    'age-restricted content.',
              ),

              _buildSection(
                context,
                icon: Icons.history_rounded,
                title: 'Changes to This Policy',
                content:
                    'We may update this Privacy Policy from time to time. Any changes will '
                    'be reflected in the App with an updated "Last updated" date. We '
                    'encourage you to review this policy periodically for any changes.',
              ),

              // ── Contact Us ──────────────────────────────────────
              _buildContactSection(context),

              const SizedBox(height: AppTheme.spaceLg),
              Center(
                child: Text(
                  'Package: com.redpdf.redimg.resize_image_to_kb\nLast updated: $_lastUpdated',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.outline,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceXl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: cs.primaryContainer),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: cs.primaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.vpn_key_rounded,
                    size: 20,
                    color: cs.primaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Permissions Used',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Only minimum permissions required:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),

            _buildPermItem(
              context,
              icon: Icons.photo_library_outlined,
              title: 'System Photo Picker',
              desc:
                  'We use Android\'s privacy-preserving Photo Picker to select images. '
                  'No broad storage permissions (READ_MEDIA_IMAGES or READ_EXTERNAL_STORAGE) are requested.',
            ),
            const Divider(height: 24),
            _buildPermItem(
              context,
              icon: Icons.camera_alt_outlined,
              title: 'Camera (Optional)',
              desc:
                  'Allows capturing a photo directly inside the app for passport photos or document cropping.',
            ),
            const Divider(height: 24),
            _buildPermItem(
              context,
              icon: Icons.wifi_rounded,
              title: 'Internet',
              desc:
                  'Check for app updates via Google Play. '
                  'No image data or personal info is ever uploaded.',
            ),
            const Divider(height: 24),
            _buildPermItem(
              context,
              icon: Icons.notifications_active_outlined,
              title: 'Notifications',
              desc:
                  'Local on-device reminders about app features. '
                  'No external push tracking. Disable anytime in device settings.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 10),
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
                desc,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.contact_support_rounded,
                  size: 20,
                  color: cs.primaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Contact Us',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'If you have any questions or concerns about this Privacy Policy, '
            'please contact us:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          InkWell(
            onTap: () => _launchEmail(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.primaryContainer.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mail_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support Email',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.outline,
                          ),
                        ),
                        Text(
                          _contactEmail,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: cs.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    tooltip: 'Copy Email',
                    color: cs.primaryContainer,
                    onPressed: () => _copyEmail(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
