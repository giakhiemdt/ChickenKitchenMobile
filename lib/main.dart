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
import 'package:mobiletest/shared/widgets/in_app_notification.dart';

/// Global navigator key để show dialog từ FCM
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Background handler — bắt buộc có để FCM hoạt động khi app bị kill
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print(
    '[BG] Nhận notification khi app bị kill: ${message.notification?.title}',
  );
}

/// ===================== MAIN =====================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣ Khởi tạo Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2️⃣ Delay nhỏ cho Samsung / Android 13+ (tránh lỗi FCM chưa sẵn sàng)
  await Future.delayed(const Duration(seconds: 2));

  // 3️⃣ Đăng ký background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;

  // 4️⃣ Xin quyền thông báo
  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('🔔 Notification permission: ${settings.authorizationStatus}');

  // 5️⃣ Lấy token, thử lại tối đa 3 lần nếu bị lỗi
  String? token;
  int attempts = 0;
  while (token == null && attempts < 3) {
    try {
      token = await messaging.getToken();
      if (token != null) {
        print('🔥 FCM TOKEN: $token');
      } else {
        print('⚠️ Token null, thử lại...');
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      print('❌ Lấy FCM token lỗi: $e (Firebase messaging không khả dụng)');
      await Future.delayed(const Duration(seconds: 2));
    }
    attempts++;
  }

  // 6️⃣ Theo dõi nếu token được làm mới
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    print('♻️ FCM token refreshed: $newToken');
  });

  runApp(const MyApp());
}

/// ===================== APP WIDGET =====================
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

/// ===================== ROUTER =====================
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

  /// Lắng nghe sự kiện FCM (foreground, background, click notification)
  void _initMessagingListeners() {
    // Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      print('[FG] Nhận notification: ${notification?.title}');
      final ctx = navigatorKey.currentContext;
      if (notification != null && ctx != null) {
        InAppNotification.show(
          ctx,
          title: notification.title,
          body: notification.body,
          visibleDuration: const Duration(seconds: 1),
        );
      }
    });

    // Khi user click notification (background / terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[CLICK] User mở app từ notification: ${message.data}');
    });

    // Khi app mở từ trạng thái bị kill
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('[INIT] App mở từ notification bị kill: ${message.data}');
      }
    });
  }

  /// Router chọn màn hình khởi động
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

  /// Quyết định màn hình start-up theo token và role
  Future<String> _decideStartUpScreen() async {
    final tokens = await _auth.loadTokens();
    if (tokens == null) return 'splash';

    // Role-based redirect
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

  /// Preload assets và API để giảm giật lag
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
