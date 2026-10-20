import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/rate_us_dialog.dart';

/// Service managing the "Rate Us" prompt and Play Store redirects.
class RateService {
  RateService._();
  static final RateService instance = RateService._();

  static const String _prefHasRated = 'has_rated_app';
  static const String playStorePackage = 'com.redpdf.resize_image_to_kb';

  /// Open Google Play Store for rating the app.
  static Future<bool> openPlayStore() async {
    final marketUri = Uri.parse('market://details?id=$playStorePackage');
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$playStorePackage',
    );

    try {
      if (Platform.isAndroid && await canLaunchUrl(marketUri)) {
        return await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }

  /// Mark that the user has rated the app (so we don't prompt them again).
  static Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefHasRated, true);
  }

  /// Check whether we should show the prompt.
  static Future<bool> shouldPrompt({bool force = false}) async {
    if (force) return true;
    final prefs = await SharedPreferences.getInstance();
    final hasRated = prefs.getBool(_prefHasRated) ?? false;
    return !hasRated;
  }

  /// Show the Rate Us prompt dialog if conditions are met.
  static Future<void> showRatePromptIfEligible(
    BuildContext context, {
    bool force = false,
  }) async {
    final eligible = await shouldPrompt(force: force);
    if (!eligible || !context.mounted) return;

    // Small delay to let the result UI render and the user celebrate success
    await Future.delayed(const Duration(milliseconds: 600));
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const RateUsDialog(),
    );
  }
}
