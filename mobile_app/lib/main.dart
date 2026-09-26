import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/storage_service.dart';
import 'core/network/dio_client.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/providers/profile_provider.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── System UI ─────────────────────────────────────────────────────
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF050508),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // ── Initialize Services ───────────────────────────────────────────
  await StorageService.instance.init();
  await DioClient.instance.init();

  runApp(
    const ProviderScope(
      child: DeepShieldApp(),
    ),
  );
}

/// Root application widget
class DeepShieldApp extends ConsumerWidget {
  const DeepShieldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);

    final materialThemeMode = switch (themeMode) {
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.system => ThemeMode.system,
    };

    return MaterialApp.router(
      // ── App Info ──────────────────────────────────────────────
      title: 'DeepShield',
      debugShowCheckedModeBanner: false,

      // ── Routing ───────────────────────────────────────────────
      routerConfig: router,

      // ── Theming ───────────────────────────────────────────────
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: materialThemeMode,

      // ── Builder — global scaffold messenger ───────────────────
      builder: (context, child) {
        return MediaQuery(
          // Prevent font scaling beyond 1.2x for layout safety
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.of(context).textScaler.clamp(
                  minScaleFactor: 0.8,
                  maxScaleFactor: 1.2,
                ),
          ),
          child: child!,
        );
      },
    );
  }
}
