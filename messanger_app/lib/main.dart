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

import 'data/cache_sync_service.dart';

import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

final ThemeController themeController = ThemeController();

void main() async {
  runApp(const OrbitaApp());
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  HttpService.init();
  await themeController.load();
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
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'Orbita',
        debugShowCheckedModeBanner: false,
        theme: AppThemes.light(),
        darkTheme: AppThemes.dark(),
        themeMode: themeController.themeMode,
        themeAnimationDuration: const Duration(milliseconds: 350),
        themeAnimationCurve: Curves.easeOutCubic,
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthWrapper(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
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
    if (token != null) CacheSyncService.start();
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
    final screen = _isLoading
        ? ColoredBox(color: AppTokens.of(context).headerBackground)
        : (_isAuthenticated ? const HomeScreen() : const LoginScreen());

    return Stack(
      children: [
        screen,
        if (!_splashFinished)
          Positioned.fill(
            child: OrbitaSplashScreen(onFinished: _onSplashFinished),
          ),
      ],
    );
  }
}
