import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/features/auth/presentation/SplashWidget.dart';
import 'package:mobiletest/features/home/presentation/HomePage.dart';
import 'package:mobiletest/features/restaurants/presentation/StorePickerPage.dart';
import 'package:mobiletest/features/store/data/store_service.dart';
import 'package:mobiletest/features/auth/data/auth_service.dart';
import 'package:mobiletest/shared/screens/LoadingScreen.dart';
import 'package:mobiletest/features/employee/presentation/EmployeePage.dart';
import 'package:mobiletest/features/menu/presentation/BuildDishWizardPage.dart';
import 'package:mobiletest/core/config/firebase_options.dart';

/// Global navigator key để show dialog từ FCM
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print(
    '[BG] Nhận notification khi app bị kill: ${message.notification?.title}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM setup
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // In token ra console
  final token = await messaging.getToken();
  print('FCM TOKEN: $token');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChickenKitchen',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xFF86C144),
        scaffoldBackgroundColor: Colors.white,
        // make progress indicators (Circular/Linear) use red by default
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.red,
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF86C144),
          onPrimary: Colors.white,
          secondary: Color(0xFF426A20),
          surface: Colors.white,
        ),
      ),
      home: const _StartUpRouter(),
    );
  }
}

/// ===================== Start-Up Router =====================
class _StartUpRouter extends StatefulWidget {
  const _StartUpRouter();

  @override
  State<_StartUpRouter> createState() => _StartUpRouterState();
}

class _StartUpRouterState extends State<_StartUpRouter> {
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _initMessagingListeners();
  }

  void _initMessagingListeners() {
    // Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      print('[FG] Nhận notification: ${notification?.title}');
      if (notification != null && navigatorKey.currentContext != null) {
        showDialog(
          context: navigatorKey.currentContext!,
          builder: (context) => AlertDialog(
            title: Text(notification.title ?? 'Thông báo'),
            content: Text(notification.body ?? 'Bạn có thông báo mới.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    });

    // Khi user click notification (background / terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[CLICK] User mở app từ notification: ${message.data}');
    });

    // Khi app mở từ terminated
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('[INIT] App mở từ notification bị kill: ${message.data}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _decideStartUpScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen();
        }
        final route = snapshot.data;
        switch (route) {
          case 'home':
            return const HomePage();
          case 'store':
            return const StorePickerPage();
          case 'employee':
            return const EmployeePage();
          case 'storeOrder':
            return const BuildDishWizardPage();
          default:
            return const SplashWidget();
        }
      },
    );
  }

  /// Quyết định màn hình start-up
  Future<String> _decideStartUpScreen() async {
    final tokens = await _auth.loadTokens();
    if (tokens == null) return 'splash';

    // Role-based redirect using accessToken claims
    try {
      final claims = _auth.decodeAccessTokenClaims(tokens.accessToken);
      final role = (claims?['role'] as String?)?.toUpperCase();
      if (role == 'EMPLOYEE') return 'employee';
      if (role == 'STORE') return 'storeOrder';
    } catch (_) {}

    final selected = await StoreService.loadSelectedStore();
    if (selected == null) return 'store';

    try {
      await _preloadHome().timeout(const Duration(seconds: 6));
    } catch (_) {}
    return 'home';
  }

  /// Preload các asset và API để giảm jank
  Future<void> _preloadHome() async {
    const bannerUrl =
        'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=1200';
    final futures = <Future<void>>[];

    futures.add(precacheImage(const NetworkImage(bannerUrl), context));

    futures.add(http.get(
      Uri.parse('https://chickenkitchen.milize-lena.space/api/store'),
      headers: const {'Accept': 'application/json'},
    ).then((_) {}));

    futures.add(http.get(
      Uri.parse('https://chickenkitchen.milize-lena.space/api/promotion'),
      headers: const {'Accept': 'application/json'},
    ).then((_) {}));

    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final storeId = await StoreService.getSelectedStoreId() ?? 1;
    futures.add(http.get(
            Uri.parse(
              'https://chickenkitchen.milize-lena.space/api/daily-menu/store/$storeId?date=$date',
            ),
      headers: const {'Accept': 'application/json'},
    ).then((_) {}));

    await Future.wait(futures);
  }
}
