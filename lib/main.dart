import 'package:app/screens/guest_screen.dart';
import 'package:flutter/material.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/register_screen.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/screens/splash_screen.dart';
import 'package:app/services/theme_service.dart';
import 'package:app/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService().createTemporaryUsers();
  await AuthService().loadCurrentUser();
  final bool loggedIn = await AuthService().isLoggedIn();
  runApp(SlugNPlugApp(isLoggedIn: loggedIn));
}

class SlugNPlugApp extends StatelessWidget {
  final bool isLoggedIn;
  const SlugNPlugApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeService,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Slug N Plug',
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: Colors.yellow,
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              secondary: Colors.yellowAccent,
              surface: Colors.white,
              onPrimary: Colors.white,
              onSecondary: Colors.black,
              onSurface: Colors.black,
              error: Colors.red,
              onError: Colors.white,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.yellow,
              foregroundColor: Colors.black,
            ),
            cardTheme: CardThemeData(
              color: Colors.grey[100],
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textTheme: const TextTheme(
              displayLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 57.0),
              displayMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 45.0),
              displaySmall: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 36.0),
              headlineLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 32.0),
              headlineMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 28.0),
              headlineSmall: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 24.0),
              titleLarge: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 22.0),
              titleMedium: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16.0),
              titleSmall: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14.0),
              bodyLarge: TextStyle(color: Colors.black87, fontSize: 16.0),
              bodyMedium: TextStyle(color: Colors.black87, fontSize: 14.0),
              bodySmall: TextStyle(color: Colors.black87, fontSize: 12.0),
              labelLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14.0),
              labelMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12.0),
              labelSmall: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11.0),
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.black,
            colorScheme: const ColorScheme.dark(
              primary: Colors.yellow,
              secondary: Colors.yellowAccent,
              surface: Color(0xFF121212),
              onPrimary: Colors.black,
              onSecondary: Colors.black,
              onSurface: Colors.white,
              error: Colors.red,
              onError: Colors.white,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.yellow,
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF1E1E1E),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textTheme: const TextTheme(
              displayLarge: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 57.0),
              displayMedium: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 45.0),
              displaySmall: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 36.0),
              headlineLarge: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 32.0),
              headlineMedium: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 28.0),
              headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 24.0),
              titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22.0),
              titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16.0),
              titleSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14.0),
              bodyLarge: TextStyle(color: Colors.white, fontSize: 16.0),
              bodyMedium: TextStyle(color: Colors.white, fontSize: 14.0),
              bodySmall: TextStyle(color: Colors.white, fontSize: 12.0),
              labelLarge: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 14.0),
              labelMedium: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 12.0),
              labelSmall: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 11.0),
            ),
            useMaterial3: true,
          ),
          themeMode: themeMode,
          initialRoute: isLoggedIn ? '/dashboard' : '/guest',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/guest': (context) => const GuestScreen(),
          },
        );
      },
    );
  }
}