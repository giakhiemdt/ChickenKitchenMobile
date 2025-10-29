import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mobiletest/screen/SplashWidget.dart';
import 'package:mobiletest/screen/HomePage.dart';
import 'package:mobiletest/screen/StorePickerPage.dart';
import 'package:mobiletest/services/store_service.dart';
import 'package:mobiletest/services/auth_service.dart';
import 'package:mobiletest/screen/LoadingScreen.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChickenKitchen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false, // tránh Material 3 tự pha tông màu
        primaryColor: const Color(0xFF86C144),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF86C144),
          onPrimary: Colors.white,
          secondary: Color(0xFF426A20),
          background: Colors.white,
          surface: Colors.white,
        ),
      ),
      home: const _StartUpRouter(),
    );
  }
}

class _StartUpRouter extends StatelessWidget {
  const _StartUpRouter();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return FutureBuilder(
      future: _decide(context, auth),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen();
        }
        final route = snapshot.data as String?;
        switch (route) {
          case 'home':
            return const HomePage();
          case 'store':
            return const StorePickerPage();
          default:
            return const SplashWidget();
        }
      },
    );
  }

  Future<String> _decide(BuildContext context, AuthService auth) async {
    final tokens = await auth.loadTokens();
    if (tokens == null) return 'splash';
    final selected = await StoreService.loadSelectedStore();
    if (selected == null) return 'store';
    // Preload critical assets/APIs to reduce jank on first paint
    try {
      await _preloadHome(context).timeout(const Duration(seconds: 6));
    } catch (_) {
      // ignore preloading errors/timeouts — still allow navigation
    }
    return 'home';
  }

  Future<void> _preloadHome(BuildContext context) async {
    const bannerUrl =
        'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=1200';
    final futures = <Future<void>>[];

    // Precache header banner
    futures.add(precacheImage(const NetworkImage(bannerUrl), context));

    // Warm API caches (no parsing necessary here)
    futures.add(http.get(
      Uri.parse('https://chickenkitchen.milize-lena.space/api/store'),
      headers: const {'Accept': 'application/json'},
    ).then((_) {}));
    futures.add(http.get(
      Uri.parse('https://chickenkitchen.milize-lena.space/api/promotion'),
      headers: const {'Accept': 'application/json'},
    ).then((_) {}));
    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final storeId = await StoreService.getSelectedStoreId() ?? 1;
    futures.add(http.get(
      Uri.parse('https://chickenkitchen.milize-lena.space/api/daily-menu/store/$storeId?date=$date'),
      headers: const {'Accept': 'application/json'},
    ).then((_) {}));

    await Future.wait(futures);
  }
}
