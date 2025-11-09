import 'package:flutter/material.dart';
import 'package:mobiletest/features/restaurants/presentation/StorePickerPage.dart';
import 'package:mobiletest/features/employee/presentation/EmployeePage.dart';
import 'package:mobiletest/features/menu/presentation/BuildDishWizardPage.dart';
import 'package:mobiletest/features/auth/data/auth_service.dart';

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
      final tokens = await _auth.signInAndLoginBackend();
      if (tokens == null) {
        setState(() {
          _loading = false;
          _error = 'Sign in was cancelled';
        });
        return;
      }

      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đăng nhập thành công')));

      // Decode role from access token and redirect accordingly
      final claims = _auth.decodeAccessTokenClaims(tokens.accessToken);
      final role = (claims?['role'] as String?)?.toUpperCase();

      if (!mounted) return;
      if (role == 'EMPLOYEE') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmployeePage()),
        );
      } else if (role == 'STORE') {
        // Redirect to in-store ordering flow (build dish)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BuildDishWizardPage()),
        );
      } else {
        // Default user flow: select store then continue
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const StorePickerPage()),
        );
      }
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://i.pinimg.com/736x/0b/62/62/0b6262777bff2b25d1b6f6dc5335fcb1.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 4,
                            shadowColor: Colors.black26,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => Navigator.maybePop(context),
                              child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  Icons.arrow_back_ios_new,
                                  size: 18,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const Center(
                          child: Text(
                            'Chicken Kitchen',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: Column(
                    children: [
                      const Expanded(child: SizedBox()),
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(0),
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
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
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 50,
                                            child: _OutlinedActionButton(
                                              primary: Colors.red,
                                              assetIcon: 'assets/images/SignInGoogle.png',
                                              label: '', 
                                              onPressed: _handleGoogleLogin,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: SizedBox(
                                            height: 50,
                                            child: _OutlinedActionButton(
                                              primary: Colors.red,
                                              assetIcon: 'assets/images/SignInGitHub.png',
                                              label: '', 
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
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Removed Employee area button

                                    if (_error != null) ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        _error!,
                                        style: const TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final bool iconOnly = label.isEmpty;
    final double iconSize = iconOnly ? 32.0 : 24.0;

    return SizedBox(
      height: 50,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: iconOnly ? BorderSide.none : BorderSide(color: primary, width: 1),
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
              Image.asset(assetIcon!, width: iconSize, height: iconSize),
            // show label only when non-empty; for icon-only buttons pass empty string
            if (!iconOnly) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
