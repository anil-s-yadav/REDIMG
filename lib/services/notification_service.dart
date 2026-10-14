import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service for scheduling local push notifications.
/// During closed testing: 4 notifications per day.
/// For production: reduce to 1 per day.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Channel ID for the app's reminder notifications.
  static const String _channelId = 'redimg_reminders';
  static const String _channelName = 'REDIMG Reminders';
  static const String _channelDescription =
      'Reminders to use REDIMG image tools';

  /// Notification messages to rotate through.
  static const List<Map<String, String>> _messages = [
    {
      'title': '📸 Need to resize an image?',
      'body': 'Quickly resize any image to your exact KB size with REDIMG!',
    },
    {
      'title': '🪪 Passport Photo Ready!',
      'body':
          'Create perfect passport photos for Aadhar, PAN & more in seconds.',
    },
    {
      'title': '✍️ Create a Digital Signature',
      'body': 'Draw and save your signature for documents with REDIMG.',
    },
    {
      'title': '🗜️ Compress Your Images',
      'body':
          'Reduce image file size without losing quality. Try it now!',
    },
  ];

  /// Initialize the notification plugin. Call this once at app startup.
  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Timezone error, using UTC: $e');
      // Fallback to UTC if timezone detection fails
    }

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

  /// Schedule 4 daily notifications at fixed times.
  /// Times: 9:00 AM, 1:00 PM, 5:00 PM, 8:00 PM
  Future<void> scheduleDailyNotifications() async {
    // Cancel any existing scheduled notifications first
    await _plugin.cancelAll();

    const times = [
      (hour: 9, minute: 0),  // 9:00 AM
      (hour: 13, minute: 0), // 1:00 PM
      (hour: 17, minute: 0), // 5:00 PM
      (hour: 20, minute: 0), // 8:00 PM
    ];

    for (int i = 0; i < times.length; i++) {
      final message = _messages[i % _messages.length];
      await _scheduleDailyNotification(
        id: i,
        hour: times[i].hour,
        minute: times[i].minute,
        title: message['title']!,
        body: message['body']!,
      );
    }

    debugPrint('NotificationService: Scheduled 4 daily notifications');
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // App opens automatically when notification is tapped.
    // No additional navigation needed.
    debugPrint('Notification tapped: ${response.payload}');
  }
}
