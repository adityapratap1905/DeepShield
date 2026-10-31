import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/storage_service.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/onboarding_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/social/presentation/community_screen.dart';
import '../features/learn/presentation/learn_screen.dart';
import '../features/scan/presentation/scan_hub_screen.dart';
import '../features/scan/presentation/url_scanner_screen.dart';
import '../features/scan/presentation/qr_scanner_screen.dart';
import '../features/scan/presentation/file_scanner_screen.dart';
import '../features/scan/presentation/analysis_screen.dart';
import '../features/scan/presentation/scan_result_screen.dart';
import '../features/scan/presentation/full_report_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/settings_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/moderation/presentation/moderation_screen.dart';
import '../models/scan_result_model.dart';

/// Named route constants to avoid magic strings
abstract class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPw = '/forgot-password';

  // Shell routes
  static const String home = '/home';
  static const String explore = '/explore';
  static const String scan = '/scan';
  static const String learn = '/learn';
  static const String history = '/history';
  static const String notifications = '/notifications';
  static const String communityDetail = '/communities';
  static String community(String id) => '$communityDetail/$id';
  static const String profile = '/profile';

  // Sub-routes
  static const String scanUrl = '/scan/url';
  static const String scanQr = '/scan/qr';
  static const String scanFile = '/scan/file';
  static const String analysis = '/scan/analysis';
  static const String scanResult = '/scan/result';
  static const String fullReport = '/scan/report';
  static const String settings = '/settings';
  static const String reports = '/reports';
  static const String moderation = '/moderation';
}

/// Riverpod provider for GoRouter — allows reactive re-evaluation when auth changes
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final storage = StorageService.instance;
      final isLoggedIn = storage.isLoggedIn;
      final isOnboardingDone = storage.isOnboardingDone;
      final path = state.uri.path;

      // Auth-guarded routes
      const protectedRoutes = [
        AppRoutes.home,
        AppRoutes.explore,
        AppRoutes.scan,
        AppRoutes.learn,
        AppRoutes.history,
        AppRoutes.notifications,
        AppRoutes.profile,
        AppRoutes.settings,
        AppRoutes.reports,
        AppRoutes.moderation,
        AppRoutes.scanUrl,
        AppRoutes.scanQr,
        AppRoutes.scanFile,
        AppRoutes.scanResult,
        AppRoutes.fullReport,
      ];

      // Redirect to onboarding if first launch
      if (path == AppRoutes.splash) return null;
      if (!isOnboardingDone && !path.startsWith('/onboarding')) {
        return AppRoutes.onboarding;
      }
      if (!isLoggedIn &&
          (protectedRoutes.contains(path) ||
              path.startsWith('/communities/'))) {
        return AppRoutes.login;
      }
      if (isLoggedIn &&
          (path == AppRoutes.login || path == AppRoutes.register)) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      // ── Auth Routes ─────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPw,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      // ── Shell (bottom nav) ───────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.explore,
            builder: (_, __) => const ExploreScreen(),
          ),
          GoRoute(
            path: AppRoutes.scan,
            builder: (_, __) => const ScanHubScreen(),
          ),
          GoRoute(
            path: AppRoutes.learn,
            builder: (_, state) => LearnScreen(
              initialCategory: state.extra as String?,
            ),
          ),
          GoRoute(
            path: '${AppRoutes.communityDetail}/:communityId',
            builder: (_, state) => CommunityScreen(
              communityId: state.pathParameters['communityId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.history,
            builder: (_, __) => const HistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // ── Standalone Routes ────────────────────────────────────────
      GoRoute(
        path: AppRoutes.scanUrl,
        builder: (_, __) => const UrlScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.scanQr,
        builder: (_, __) => const QrScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.scanFile,
        builder: (_, state) => FileScannerScreen(
          initialVideoMode: state.extra == 'video',
        ),
      ),
      GoRoute(
        path: AppRoutes.analysis,
        builder: (_, state) {
          final payload = state.extra as Map<String, dynamic>? ?? {};
          return AnalysisScreen(payload: payload);
        },
      ),
      GoRoute(
        path: AppRoutes.scanResult,
        builder: (context, state) {
          final result = state.extra as ScanResultModel;
          return ScanResultScreen(result: result);
        },
      ),
      GoRoute(
        path: AppRoutes.fullReport,
        builder: (context, state) {
          final result = state.extra as ScanResultModel;
          return FullReportScreen(result: result);
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (_, __) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.moderation,
        builder: (_, __) => const ModerationScreen(),
      ),
    ],
  );
});
