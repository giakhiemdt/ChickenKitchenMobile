import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthTokens {
  final String accessToken;
  final String refreshToken;

  const AuthTokens({required this.accessToken, required this.refreshToken});
}

class AuthService {
  final _googleSignIn = GoogleSignIn.standard();
  final _auth = FirebaseAuth.instance;
  final _messaging = FirebaseMessaging.instance;
  final _storage = const FlutterSecureStorage();

  // ==================== ĐĂNG NHẬP GOOGLE + FCM ====================
  Future<AuthTokens?> signInAndLoginBackend() async {
    try {
      print("Step 1: Google Sign-In...");
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("User canceled Google Sign-In");
        return null;
      }

      final googleAuth = await googleUser.authentication;

      // Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase sign-in
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) throw Exception("Firebase sign-in failed");

      final idToken = await firebaseUser.getIdToken();
      if (idToken == null) throw Exception("Cannot get Firebase ID token");

      print("✅ Firebase ID token obtained");

      // Lấy FCM token
      final fcmToken = await _getFcmToken();
      print("✅ FCM token obtained: $fcmToken");

      // Gửi lên Backend
      final tokens = await _loginToBackend(idToken, fcmToken);
      print("✅ Backend login successful");

      return tokens;
    } catch (e, st) {
      print("❌ signInAndLoginBackend error: $e");
      print(st);
      return null;
    }
  }

  // ==================== LẤY FCM TOKEN ====================
  Future<String?> _getFcmToken() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print("FCM permission: ${settings.authorizationStatus}");
      final token = await _messaging.getToken();

      if (token == null) {
        print("⚠️ Could not get FCM token");
        return null;
      }

      _messaging.onTokenRefresh.listen((newToken) {
        print("🔄 FCM token refreshed: $newToken");
      });

      return token;
    } catch (e) {
      print("❌ Error getting FCM token: $e");
      return null;
    }
  }

  // ==================== LOGIN VỀ BACKEND ====================
  Future<AuthTokens> _loginToBackend(String idToken, String? fcmToken) async {
    final uri = Uri.parse(
      'https://chickenkitchen.milize-lena.space/api/auth/login',
    );

    final resp = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'idToken': idToken,
        if (fcmToken != null) 'fcmToken': fcmToken, // 👈 gửi FCM token kèm
      }),
    );

    print("id token: $idToken");

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Backend login failed: HTTP ${resp.statusCode}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final statusCode = json['statusCode'];
    final data = json['data'] as Map<String, dynamic>?;

    final accessToken = data?['accessToken'];
    final refreshToken = data?['refreshToken'];

    if (statusCode != 200 || accessToken is! String || refreshToken is! String) {
      throw Exception('Unexpected response format from backend');
    }

    final tokens = AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    await saveTokens(tokens);
    return tokens;
  }

  // ==================== TOKEN LƯU TRỮ ====================
  Future<void> saveTokens(AuthTokens tokens) async {
    await _storage.write(key: 'accessToken', value: tokens.accessToken);
    await _storage.write(key: 'refreshToken', value: tokens.refreshToken);
  }

  Future<AuthTokens?> loadTokens() async {
    final access = await _storage.read(key: 'accessToken');
    final refresh = await _storage.read(key: 'refreshToken');
    if (access == null || refresh == null) return null;
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
  }

  // ==================== CÁC HÀM HỖ TRỢ ====================
  Map<String, dynamic>? decodeAccessTokenClaims(String accessToken) {
    try {
      return JwtDecoder.decode(accessToken);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> authHeaders() async {
    final tokens = await loadTokens();
    if (tokens == null) return {};
    return {
      'Authorization': 'Bearer ${tokens.accessToken}',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> logout() async {
    await signOut();
    await clearTokens();
  }
}
