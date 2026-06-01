import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_colors.dart';
import 'core/services/api_service.dart';
import 'core/services/socket_service.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/presentation/screens/main_dashboard_screen.dart';

void main() {
  // Initialise Dio before the app starts
  ApiService().init();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'EduSync',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      darkTheme: _buildDarkTheme(),
      theme: _buildLightTheme(),
      home: const _AuthGate(),
    );
  }

  ThemeData _buildDarkTheme() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.accent,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
        ),
        useMaterial3: true,
        textTheme:
            GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
          titleLarge: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textHeading),
          titleMedium: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading),
          bodyLarge:
              GoogleFonts.outfit(fontSize: 16, color: AppColors.textHeading),
          bodyMedium:
              GoogleFonts.outfit(fontSize: 14, color: AppColors.textBody),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF30363D), width: 1),
          ),
          elevation: 0,
        ),
      );

  ThemeData _buildLightTheme() => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBackground,
        primaryColor: AppColors.accent,
        colorScheme: const ColorScheme.light(
          primary: AppColors.accent,
          surface: AppColors.lightSurface,
        ),
        useMaterial3: true,
        textTheme:
            GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
          titleLarge: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.lightTextHeading),
          titleMedium: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextHeading),
          bodyLarge: GoogleFonts.outfit(
              fontSize: 16, color: AppColors.lightTextHeading),
          bodyMedium:
              GoogleFonts.outfit(fontSize: 14, color: AppColors.lightTextBody),
        ),
        cardTheme: CardThemeData(
          color: AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFD0D7DE), width: 1),
          ),
          elevation: 0,
        ),
      );
}

/// Routes user to Login or Dashboard based on auth state
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

    return authAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
      error: (_, __) => const LoginScreen(),
      data: (authState) {
        if (authState.isAuthenticated) {
          // Connect socket when user is logged in
          SocketService().connect();
          return const MainDashboardScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
