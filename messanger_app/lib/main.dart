import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
//import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'services/auth_service.dart';
//import 'services/notification_service.dart';
import 'services/key_storage_service.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

import 'utils/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  HttpService.init();
  runApp(const OrbitaApp());
}

Future<void> _deferredInit() async {
  await Firebase.initializeApp();
  await initializeDateFormatting('ru', null);
  await KeyStorageService.initializeKeys();
  //await NotificationService.init();
}

class OrbitaApp extends StatelessWidget {
  const OrbitaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orbita',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.scaffoldBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.mutedBlue,
          surface: AppColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _splashFinished = false;

  @override
  void initState() {
    super.initState();
    _startup();
  }

  Future<void> _startup() async {
    await _deferredInit();
    final token = await AuthService.getToken();
    if (mounted) {
      setState(() {
        _isAuthenticated = token != null;
        _isLoading = false;
      });
    }
  }

  void _onSplashFinished() {
    if (mounted) {
      setState(() => _splashFinished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashFinished || _isLoading) {
      final target = _isLoading
          ? const ColoredBox(color: AppColors.primary)
          : (_isAuthenticated ? const HomeScreen() : const LoginScreen());

      return Stack(
        children: [
          target,
          Positioned.fill(
            child: OrbitaSplashScreen(onFinished: _onSplashFinished),
          ),
        ],
      );
    }

    return _isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}
