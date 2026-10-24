import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../router/app_router.dart';

/// Specification for a daily scheduled notification slot.
class DailyNotificationSlot {
  final int id;
  final int hour;
  final int minute;
  final String title;
  final String body;
  final String route;

  const DailyNotificationSlot({
    required this.id,
    required this.hour,
    required this.minute,
    required this.title,
    required this.body,
    required this.route,
  });
}

/// Service for scheduling local push notifications.
///
/// Features:
/// - Fires 4 times a day at optimal waking hours (10:00 AM, 02:00 PM, 06:00 PM, 09:00 PM).
/// - Inexact schedule with [AndroidScheduleMode.inexactAllowWhileIdle].
/// - 100% compliant with Google Play Store policies (NO SCHEDULE_EXACT_ALARM needed).
/// - Uses [matchDateTimeComponents: DateTimeComponents.time] for automatic daily repetition.
/// - Restored after device reboot via ScheduledNotificationBootReceiver.
/// - High importance notification channel for heads-up alert visibility.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Upgraded channel ID with high importance and priority.
  static const String _channelId = 'redimg_daily_reminders_v2';
  static const String _channelName = 'REDIMG Reminders & Tips';
  static const String _channelDescription =
      'Helpful reminders and tips to use REDIMG image and PDF tools';

  /// 4 daily notification slots at fixed clock hours.
  static const List<DailyNotificationSlot> _dailySlots = [
    DailyNotificationSlot(
      id: 101,
      hour: 10,
      minute: 0,
      title: 'Anil Yadav - click here',
      body: 'Click use any feature and help me',
      route: '/passport-photo',
    ),
    DailyNotificationSlot(
      id: 102,
      hour: 14,
      minute: 0,
      title: 'Anil Yadav - click here',
      body: 'Click use any feature and help me',
      route: '/resize-image',
    ),
    DailyNotificationSlot(
      id: 103,
      hour: 18,
      minute: 0,
      title: 'Anil Yadav - click here',
      body: 'Click use any feature and help me',
      route: '/compress-image',
    ),
    DailyNotificationSlot(
      id: 104,
      hour: 21,
      minute: 0,
      title: 'Anil Yadav - click here',
      body: 'Click use any feature and help me',
      route: '/signature-maker',
    ),
  ];

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  /// Initialize timezone and notification plugin. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize Timezones
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      String timeZoneName = tzInfo.identifier;
      if (timeZoneName == 'Asia/Calcutta') {
        timeZoneName = 'Asia/Kolkata';
      }
      if (tz.timeZoneDatabase.locations.containsKey(timeZoneName)) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint('NotificationService: Local timezone set to $timeZoneName');
      } else {
        tz.setLocalLocation(tz.getLocation('UTC'));
        debugPrint(
          'NotificationService: Timezone $timeZoneName not in DB, fallback to UTC',
        );
      }
    } catch (e) {
      debugPrint('NotificationService: Timezone initialization error: $e');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    // 2. Platform initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

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

    // 3. Android notification channel creation
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        try {
          await androidPlugin.deleteNotificationChannel('redimg_reminders');
        } catch (_) {}

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
    }

    _initialized = true;
  }

  /// Request notification permission (Android 13+ / iOS).
  Future<bool> requestPermission() async {
    await init();
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted =
          await androidPlugin?.requestNotificationsPermission() ?? false;
      return granted;
    } else if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted =
          await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted;
    }
    return true;
  }

  /// Check whether notification permission is granted at the OS level.
  Future<bool> areNotificationsEnabled() async {
    await init();
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }
    return true;
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

  /// Get count of pending scheduled notifications.
  Future<int> getPendingNotificationCount() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (e) {
      return 0;
    }
  }

  /// Immediately triggers a test notification so the user can verify it works.
  Future<bool> showTestNotification() async {
    try {
      await init();
      final systemEnabled = await areNotificationsEnabled();
      if (!systemEnabled) {
        final granted = await requestPermission();
        if (!granted) return false;
      }

      await _plugin.show(
        999,
        '🔔 REDIMG: Notifications are working!',
        'Daily reminders are active. You will receive 4 helpful tips daily.',
        _notificationDetails,
        payload: '/home',
      );
      return true;
    } catch (e) {
      debugPrint('NotificationService: showTestNotification error: $e');
      return false;
    }
  }

  /// Schedule 4 notifications per day at fixed waking hours.
  ///
  /// Uses [AndroidScheduleMode.inexactAllowWhileIdle] which:
  /// - Does NOT require SCHEDULE_EXACT_ALARM permission.
  /// - Is fully compliant with Google Play Store policies.
  /// - Repeats daily at fixed times (10:00 AM, 02:00 PM, 06:00 PM, 09:00 PM).
  Future<void> scheduleDailyNotifications({bool force = false}) async {
    try {
      await init();

      final isNotificationEnabled = await isEnabled();
      if (!isNotificationEnabled) {
        await cancelAll();
        return;
      }

      // Schedule/refresh all 4 daily slots in AlarmManager.
      // We deliberately do not gate this on areNotificationsEnabled() so alarms
      // exist in AlarmManager regardless of whether the user has answered the
      // runtime prompt yet.
      for (final slot in _dailySlots) {
        // Cancel existing slot before rescheduling to avoid duplicates
        await _plugin.cancel(slot.id);

        final scheduledDate = _nextInstanceOfTime(slot.hour, slot.minute);

        await _plugin.zonedSchedule(
          slot.id,
          slot.title,
          slot.body,
          scheduledDate,
          _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: slot.route,
        );

        debugPrint(
          'NotificationService: Scheduled slot [${slot.id}] "${slot.title}" at $scheduledDate',
        );
      }
    } catch (e) {
      debugPrint('NotificationService: Schedule error: $e');
    }
  }

  /// Calculate the next instance of a specific hour:minute in the local timezone.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now) || scheduledDate.isAtSameMomentAs(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Cancel all scheduled and active notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('NotificationService: All notifications canceled');
  }

  /// Handle notification tap when app is opened from a notification.
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
