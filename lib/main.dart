import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'firebase_options.dart';
import 'constants.dart';
import 'controllers/menu_app_controller.dart';
import 'screens/main/main_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/init_service.dart';
import 'services/session_service.dart';
import 'services/platform_service.dart';
import 'services/webview_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize WebView for Web platform
  if (kIsWeb) {
    WebViewPlatform.instance = WebWebViewPlatform();
  }

  // Initialize platform-specific services
  PlatformService.initialize();

  // Initialize MediaKit
  MediaKit.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configure Firestore settings based on platform
  if (kIsWeb) {
    // Web platform - disable persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } else {
    // Mobile/Desktop platforms - enable persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Initialize budget data
  final initService = InitService();
  await initService.initializeBudgetData();

  WebViewService.initializeWebView();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<SessionService> _sessionServiceFuture;

  @override
  void initState() {
    super.initState();
    _sessionServiceFuture = SessionService.init();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SessionService>(
      future: _sessionServiceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Error: ${snapshot.error}'),
              ),
            ),
          );
        }

        final sessionService = snapshot.data!;

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (context) => MenuAppController(),
            ),
            Provider<SessionService>.value(
              value: sessionService,
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'AMS Dashboard',
            theme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: bgColor,
              canvasColor: secondaryColor,
              primaryColor: primaryColor,
            ),
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasData) {
                  return const MainScreen();
                }

                return const LoginScreen();
              },
            ),
            routes: {
              '/dashboard': (context) {
                // Get the arguments
                final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                final initialTab = args?['initialTab'] as String?;
                final athleteId = args?['athleteId'] as String?;
                
                // Return the MainScreen with the specified tab
                return MainScreen(
                  initialTab: initialTab,
                  initialAthleteId: athleteId,
                );
              },
              '/medical_dashboard': (context) {
                // Navigate to MainScreen with medical dashboard
                return const MainScreen(
                  initialTab: 'medical',  // This should match the case statement in _initializeScreen
                );
              },
            },
          ),
        );
      },
    );
  }
}
