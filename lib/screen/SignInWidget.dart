import 'package:flutter/material.dart';
import 'package:mobiletest/screen/HomePage.dart';
import 'package:mobiletest/screen/StorePickerPage.dart';
import 'package:mobiletest/services/auth_service.dart';

class SignInWidget extends StatefulWidget {
  const SignInWidget({super.key});

  @override
  State<SignInWidget> createState() => _SignInWidgetState();
}

class _SignInWidgetState extends State<SignInWidget> {
  final _auth = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final idToken = await _auth.signInWithGoogle();
      if (idToken == null) {
        setState(() {
          _loading = false;
          _error = 'Đăng nhập đã bị hủy';
        });
        return;
      }
      await _auth.loginToBackend(idToken);
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đăng nhập thành công')));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StorePickerPage()),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đăng nhập thất bại: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF86C144);

    return Scaffold(
      backgroundColor: primary,
      body: SafeArea(
        child: Column(
          children: [
            // Top back bar (long rounded pill with back icon)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FractionallySizedBox(
                widthFactor: 0.9,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.maybePop(context),
                    child: const SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          SizedBox(width: 12),
                          Icon(Icons.arrow_back_ios_new, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chikchen\nKitchen',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            // White content sheet
            Expanded(
              child: Column(
                children: [
                  // Lime accent bar above the white sheet (80% width)
                  const FractionallySizedBox(
                    widthFactor: 0.8,
                    child: SizedBox(
                      height: 18,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFD0F96F),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Welcome Back',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Sign in to create your own order',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black45,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _OutlinedActionButton(
                                    primary: primary,
                                    assetIcon: 'assets/images/SignInGoogle.png',
                                    label: 'Sign In With Google',
                                    onPressed: _handleGoogleLogin,
                                  ),
                                  const SizedBox(height: 12),
                                  _OutlinedActionButton(
                                    primary: primary,
                                    assetIcon: 'assets/images/SignInGitHub.png',
                                    label: 'Sign In With Github',
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Chưa hỗ trợ GitHub'),
                                        ),
                                      );
                                    },
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      _error!,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                  const Spacer(),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // No bottom navigation on sign-in screen
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  final Color primary;
  final String? assetIcon;
  final String label;
  final VoidCallback onPressed;

  const _OutlinedActionButton({
    required this.primary,
    this.assetIcon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: BorderSide(color: primary, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (assetIcon != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Image.asset(assetIcon!, width: 24, height: 24),
              ),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
