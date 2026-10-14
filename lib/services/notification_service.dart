import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


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

  /// Schedule daily reminder notification without timezone dependency.
  Future<void> scheduleDailyNotifications() async {
    // Cancel any existing scheduled notifications first
    await _plugin.cancelAll();

    final message = _messages[0];
    await _plugin.periodicallyShow(
      0,
      message['title']!,
      message['body']!,
      RepeatInterval.daily,
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
    );

    debugPrint('NotificationService: Scheduled daily notification');
  }


  void _onNotificationTapped(NotificationResponse response) {
    // App opens automatically when notification is tapped.
    // No additional navigation needed.
    debugPrint('Notification tapped: ${response.payload}');
  }
}
