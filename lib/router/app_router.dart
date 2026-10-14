import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/my_files/my_files_screen.dart';
import '../screens/passport_photo/passport_photo_screen.dart';
import '../screens/resize_image/resize_image_screen.dart';
import '../screens/signature_maker/signature_maker_screen.dart';
import '../screens/combine_tool/combine_tool_screen.dart';
import '../screens/compress_image/compress_image_screen.dart';
import '../screens/image_to_pdf/image_to_pdf_screen.dart';
import '../screens/result/result_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shell/app_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    // Shell route provides persistent bottom nav
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/tools',
          name: 'tools',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: MyFilesScreen()),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),
    // Tool screens (no bottom nav)
    GoRoute(
      path: '/passport-photo',
      name: 'passport-photo',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const PassportPhotoScreen(),
        transitionsBuilder: _slideTransition,
      ),
    ),
    GoRoute(
      path: '/resize-image',
      name: 'resize-image',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const ResizeImageScreen(),
        transitionsBuilder: _slideTransition,
      ),
    ),
    GoRoute(
      path: '/signature-maker',
      name: 'signature-maker',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const SignatureMakerScreen(),
        transitionsBuilder: _slideTransition,
      ),
    ),
    GoRoute(
      path: '/combine-tool',
      name: 'combine-tool',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const CombineToolScreen(),
        transitionsBuilder: _slideTransition,
      ),
    ),
    GoRoute(
      path: '/compress-image',
      name: 'compress-image',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const CompressImageScreen(),
        transitionsBuilder: _slideTransition,
      ),
    ),
    GoRoute(
      path: '/image-to-pdf',
      name: 'image-to-pdf',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const ImageToPdfScreen(),
        transitionsBuilder: _slideTransition,
      ),
    ),
    GoRoute(
      path: '/result',
      name: 'result',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return CustomTransitionPage(
          child: ResultScreen(
            filePath: extra['filePath'] as String? ?? '',
            fileSize: extra['fileSize'] as String? ?? '',
            dimensions: extra['dimensions'] as String? ?? '',
            format: extra['format'] as String? ?? 'JPEG',
            originalSize: extra['originalSize'] as String? ?? '',
            toolName: extra['toolName'] as String? ?? '',
            outputFormat: extra['outputFormat'] as String? ?? 'png',
            fileName: extra['fileName'] as String?,
          ),
          transitionsBuilder: _slideTransition,
        );
      },
    ),
  ],
);

Widget _slideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: child,
  );
}
