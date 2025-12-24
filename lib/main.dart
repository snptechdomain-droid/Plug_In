import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/screens/guest_screen.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/register_screen.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/screens/splash_screen.dart';
import 'package:app/services/theme_service.dart';
import 'package:app/screens/forgot_password_screen.dart';
import 'package:app/screens/role_management_screen.dart';
import 'package:app/screens/permissions_screen.dart';
import 'package:app/services/auth_service.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/widgets/auth_guard.dart';

import 'dart:async';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize role-based database service with timeout
    await RoleBasedDatabaseService().initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () => print('Database initialization timed out - proceeding anyway'),
    );
    
    await AuthService().loadCurrentUser().timeout(
      const Duration(seconds: 10),
      onTimeout: () => null, // Just proceed if it times out
    );
    // await AuthService().createTemporaryUsers(); 
    
    final bool loggedIn = await AuthService().isLoggedIn();
    runApp(SlugNPlugApp(isLoggedIn: loggedIn));
  }, (error, stack) {
    print('Uncaught Error in runZonedGuarded: $error');
    print(stack);
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SelectableText(
                'CRITICAL APP ERROR:\n$error\n\nSTACK:\n$stack',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  });
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
          debugShowCheckedModeBanner: false,
          title: 'Slug N Plug',
          themeMode: themeMode,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          onGenerateRoute: _onGenerateRoute,
          initialRoute: isLoggedIn ? '/dashboard' : '/guest',
        );
      },
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case '/login':
        page = const LoginScreen();
        break;
      case '/register':
        page = const RegisterScreen();
        break;
      case '/dashboard':
        page = const AuthGuard(child: DashboardScreen());
        break;
      case '/forgot-password':
        page = const ForgotPasswordScreen();
        break;
      case '/roles':
        page = const AuthGuard(child: RoleManagementScreen());
        break;
      case '/permissions':
        page = const AuthGuard(child: PermissionsScreen());
        break;
      case '/guest':
        page = const GuestScreen();
        break;
      case '/splash':
      default:
        page = const SplashScreen();
        break;
    }

    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return FadeTransition(opacity: curve, child: child);
      },
    );
  }
}

// -------------------- THEME --------------------

final _lightTheme = ThemeData(
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: Colors.black,
    secondary: Color(0xFFFFD700), // Gold/Yellow
    surface: Colors.white,
    onPrimary: Colors.white,
    onSecondary: Colors.black,
    onSurface: Colors.black,
    error: Color(0xFFB00020),
    onError: Colors.white,
  ),
  scaffoldBackgroundColor: const Color(0xFFF5F7FA),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 0,
    scrolledUnderElevation: 2,
  ),
  cardColor: Colors.white,
  useMaterial3: true,
  textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
    displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 42, color: Colors.black),
    headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 28, color: Colors.black),
    titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black),
    bodyMedium: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF424242)),
  ),
);

final _darkTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFFFD700), // Gold/Yellow
    secondary: Colors.white,
    surface: Color(0xFF121212),
    onPrimary: Colors.black,
    onSecondary: Colors.black,
    onSurface: Colors.white,
    error: Color(0xFFCF6679),
    onError: Colors.black,
  ),
  scaffoldBackgroundColor: Colors.black,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.black,
    foregroundColor: Color(0xFFFFD700), // Gold/Yellow
    elevation: 0,
    scrolledUnderElevation: 2,
  ),
  cardColor: const Color(0xFF1E1E1E),
  useMaterial3: true,
  textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
    displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFFFD700), fontSize: 42),
    headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFFFFD700), fontSize: 28),
    titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
    bodyMedium: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
  ),
);
