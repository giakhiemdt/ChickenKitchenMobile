// import 'package:flutter/material.dart';
// import 'package:mobiletest/services/auth_service.dart';
// import 'package:mobiletest/screen/login_screen.dart';

// class SuccessScreen extends StatelessWidget {
//   const SuccessScreen({super.key});

//   Future<void> _logout(BuildContext context) async {
//     final auth = AuthService();
//     try {
//       await auth.logout();
//       if (!context.mounted) return;
//       Navigator.of(context).pushAndRemoveUntil(
//         MaterialPageRoute(builder: (_) => const LoginScreen()),
//         (_) => false,
//       );
//     } catch (e) {
//       if (!context.mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Đăng xuất thất bại: ${e.toString()}')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Đã đăng nhập')),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.account_circle, size: 120, color: Colors.green),
//             const SizedBox(height: 16),
//             const Text('Đăng nhập thành công!'),
//             const SizedBox(height: 24),
//             ElevatedButton.icon(
//               onPressed: () => _logout(context),
//               icon: const Icon(Icons.logout),
//               label: const Text('Đăng xuất'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
