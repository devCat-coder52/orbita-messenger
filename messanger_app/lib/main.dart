import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
//import 'services/socket_service.dart';
import 'services/notification_service.dart';
import '../utils/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log.i("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // 👇 Убедись, что имя файла точно совпадает с тем, что в папке
    await dotenv.load(fileName: ".env");
    print('✅ .env загружен. API URL: ${dotenv.env['BASE_URL_API']}');
  } catch (e) {
    print('❌ Ошибка загрузки .env: $e');
  }
  FlutterError.onError = (details) {
    log.e('Global Error: ${details.exception}');
  };
  try {
    await Firebase.initializeApp();
    await AuthService.initDio();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await NotificationService.init();
  } catch (error) {
    log.e("Ошибка инициализации void name: $error");
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Messenger App',
      theme: ThemeData(primarySwatch: Colors.blue),
      builder: (context, child) {
        ErrorWidget.builder = (errorDetails) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bug_report, size: 50, color: Colors.red),
                  const SizedBox(height: 20),
                  const Text(
                    'Упс! Что-то пошло не так.',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    errorDetails.exceptionAsString(),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        };
        return child!;
      },
      home: AuthCheck(),
      //initialRoute: '/',
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/home': (context) => HomeScreen(),
        '/chat': (context) => ChatScreen(),
      },
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService.getToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        } else {
          if (snapshot.data != null) {
            return HomeScreen();
          } else {
            return LoginScreen();
          }
        }
      },
    );
  }
}
