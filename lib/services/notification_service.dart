import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../router/app_router.dart';

/// Service for scheduling local push notifications.
///
/// Configured for 4 times a day (every 6 hours) using inexact alarms.
/// - Does NOT use exact alarms (no SCHEDULE_EXACT_ALARM permission required).
/// - Highly optimized: prevents timer reset on every app launch by checking pending requests.
/// - Rotates between 6 core tools and helpful tips.
/// - Fully user-configurable via settings.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Channel ID for the app's reminder notifications.
  static const String _channelId = 'redimg_reminders';
  static const String _channelName = 'REDIMG Reminders & Tips';
  static const String _channelDescription =
      'Helpful reminders and tips to use REDIMG image and PDF tools';

  static const int _notificationId = 1001;

  /// Notification messages to rotate through 4 times a day.
  static const List<Map<String, String>> _messages = [
    {
      'title': '📐 Need an exact image size?',
      'body': 'Resize photos to 20KB, 50KB, 100KB or custom resolution with REDIMG.',
      'route': '/resize-image',
    },
    {
      'title': '🪪 Create Passport Photo in seconds',
      'body': 'Generate standard photos for Aadhar, PAN, Visa & official exam forms.',
      'route': '/passport-photo',
    },
    {
      'title': '✍️ Draw & Save Your Signature',
      'body': 'Create clean transparent signatures ready for digital document signing.',
      'route': '/signature-maker',
    },
    {
      'title': '🗜️ Compress Heavy Photos',
      'body': 'Reduce photo file size by up to 90% without losing visual clarity.',
      'route': '/compress-image',
    },
    {
      'title': '📑 Combine Photo + Signature',
      'body': 'Merge your photo and signature together on one page for recruitment portals.',
      'route': '/combine-tool',
    },
    {
      'title': '📄 Convert Images to PDF',
      'body': 'Turn single or multiple images into high-quality PDFs with one tap.',
      'route': '/image-to-pdf',
    },
  ];

  /// Initialize the notification plugin. Call this once at app startup.
  Future<void> init() async {
    if (_initialized) return;

    // Android initialization
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Request notification permission (Android 13+ / iOS).
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await androidPlugin?.requestNotificationsPermission() ?? false;
      return granted;
    } else if (Platform.isIOS) {
      final iosPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted;
    }
    return false;
  }

  /// Check if user has notifications enabled in preferences.
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  /// Toggle notifications on/off from settings.
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    if (enabled) {
      await requestPermission();
      await scheduleDailyNotifications(force: true);
    } else {
      await cancelAll();
    }
  }

  /// Schedule 4 times a day notifications (every 6 hours).
  ///
  /// Optimization:
  /// - Uses [AndroidScheduleMode.inexactAllowWhileIdle] (no exact alarm permission needed).
  /// - Avoids resetting the 6-hour alarm countdown on every app launch if one is already pending.
  /// - Rotates between 6 diverse tools and tips.
  Future<void> scheduleDailyNotifications({bool force = false}) async {
    try {
      final isNotificationEnabled = await isEnabled();
      if (!isNotificationEnabled) {
        await cancelAll();
        return;
      }

      // Optimization: Do NOT reschedule if an inexact repeating alarm is already pending.
      // This prevents the 6-hour timer from resetting to zero every time the user launches the app!
      if (!force) {
        final pending = await _plugin.pendingNotificationRequests();
        if (pending.isNotEmpty) {
          debugPrint(
            'NotificationService: Inexact notification already active (${pending.length} pending), skipping timer reset.',
          );
          return;
        }
      }

      // Cancel any old scheduled alarms
      await _plugin.cancelAll();

      // Rotate through messages
      final prefs = await SharedPreferences.getInstance();
      final lastIndex = prefs.getInt('last_notification_index') ?? -1;
      final nextIndex = (lastIndex + 1) % _messages.length;
      await prefs.setInt('last_notification_index', nextIndex);

      final message = _messages[nextIndex];
      final title = message['title']!;
      final body = message['body']!;
      final route = message['route'];

      // Schedule for every 6 hours = 4 times a day
      await _plugin.periodicallyShowWithDuration(
        _notificationId,
        title,
        body,
        const Duration(hours: 6),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: route,
      );

      debugPrint(
        'NotificationService: Scheduled inexact periodic notification (every 6 hours, 4x daily): "$title"',
      );
    } catch (e) {
      debugPrint('NotificationService: Schedule error (non-fatal): $e');
    }
  }

  /// Cancel all scheduled and active notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('NotificationService: All notifications canceled');
  }

  /// Handle notification tap when app is opened from notification.
  Future<void> checkLaunchNotification() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        final payload = details.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            try {
              appRouter.push(payload);
            } catch (e) {
              debugPrint('NotificationService: Navigation error on launch: $e');
            }
          });
        }
      }
    } catch (e) {
      debugPrint('NotificationService: checkLaunchNotification error: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        appRouter.push(response.payload!);
      } catch (e) {
        debugPrint('NotificationService: Error navigating on tap: $e');
      }
    }
  }
}
