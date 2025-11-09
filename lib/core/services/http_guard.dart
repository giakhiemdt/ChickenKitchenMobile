import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/features/auth/data/auth_service.dart';
import 'package:mobiletest/features/auth/presentation/SignInWidget.dart';

class HttpGuard {
  /// Returns true if handled (i.e., navigated due to 401); caller should stop further processing.
  static Future<bool> handleUnauthorized(BuildContext context, http.Response resp) async {
    if (resp.statusCode == 401) {
      try {
        await AuthService().logout();
      } catch (_) {}
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInWidget()),
          (route) => false,
        );
      }
      return true;
    }
    return false;
  }

  /// Optionally throws for non-2xx responses after checking 401.
  static Future<void> checkOrThrow(BuildContext context, http.Response resp) async {
    final handled = await handleUnauthorized(context, resp);
    if (handled) return;
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}');
    }
  }
}

