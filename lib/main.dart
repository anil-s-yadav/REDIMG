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

  // Initialize notifications core and register daily alarms
  try {
    final notif = NotificationService.instance;
    await notif.init();
    final enabled = await notif.isEnabled();
    if (enabled) {
      await notif.scheduleDailyNotifications();
    }
  } catch (e) {
    debugPrint('Notification init error in main: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeModeProvider(),
      child: const RdPdfImageToolsApp(),
    ),
  );
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
