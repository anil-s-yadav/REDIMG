import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize notifications (non-blocking, crash-safe)
  _initNotifications();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeModeProvider(),
      child: const RdPdfImageToolsApp(),
    ),
  );
}

/// Initialize notification service in background.
/// Wrapped in try-catch to prevent app crashes.
void _initNotifications() async {
  try {
    final notificationService = NotificationService.instance;
    await notificationService.init();
    await notificationService.requestPermission();
    await notificationService.scheduleDailyNotifications();
  } catch (e) {
    debugPrint('Notification init error (non-fatal): $e');
  }
}

class RdPdfImageToolsApp extends StatelessWidget {
  const RdPdfImageToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeModeProvider>().themeMode;

    return MaterialApp.router(
      title: 'RdPdf Image Tools',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
