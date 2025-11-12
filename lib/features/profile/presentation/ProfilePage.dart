import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/shared/widgets/app_bottom_nav.dart';
import 'package:mobiletest/features/auth/data/auth_service.dart';
import 'package:mobiletest/features/auth/presentation/SignInWidget.dart';
import 'package:mobiletest/features/home/presentation/HomePage.dart';
import 'package:mobiletest/features/restaurants/presentation/RestaurantsListPage.dart';
import 'package:mobiletest/features/menu/presentation/DailyMenuListPage.dart';
import 'package:mobiletest/features/orders/presentation/OrderHistoryPage.dart';
import 'package:mobiletest/features/ai/presentation/AiChatPage.dart';

class ProfileData {
  final String fullName;
  final String email;
  final String? birthday;
  final String createdAt;
  final String? imageURL;

  const ProfileData({
    required this.fullName,
    required this.email,
    required this.birthday,
    required this.createdAt,
    required this.imageURL,
  });

  factory ProfileData.fromJson(Map<String, dynamic> j) => ProfileData(
    fullName: (j['fullName'] ?? '') as String,
    email: (j['email'] ?? '') as String,
    birthday: j['birthday'] as String?,
    createdAt: (j['createdAt'] ?? '') as String,
    imageURL: j['imageURL'] as String?,
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _UnauthorizedException implements Exception {}

class _ProfilePageState extends State<ProfilePage> {
  late Future<ProfileData> _future;
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _future = _fetchProfile();
  }

  Future<ProfileData> _fetchProfile() async {
    final uri = Uri.parse(
      'https://chickenkitchen.milize-lena.space/api/users/me',
    );
    final headers = await _auth.authHeaders();
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 401) {
      throw _UnauthorizedException();
    }
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = map['data'] as Map<String, dynamic>;
    return ProfileData.fromJson(data);
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF86C144);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: FutureBuilder<ProfileData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              if (snap.error is _UnauthorizedException) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await _auth.logout();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SignInWidget()),
                    (route) => false,
                  );
                });
              }
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(height: 8),
                    Text('Failed to load profile: ${snap.error}'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          setState(() => _future = _fetchProfile()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final p = snap.data!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // User header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: primary.withOpacity(.15),
                        backgroundImage:
                            (p.imageURL != null && p.imageURL!.isNotEmpty)
                            ? NetworkImage(p.imageURL!)
                            : null,
                        child: (p.imageURL == null || p.imageURL!.isEmpty)
                            ? const Icon(
                                Icons.person,
                                color: Colors.black54,
                                size: 30,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.fullName.isEmpty ? 'Guest' : p.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.email,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Joined: ${p.createdAt}',
                              style: const TextStyle(
                                color: Colors.black45,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _SectionHeader('General'),
                _SettingTile(
                  icon: Icons.payment,
                  title: 'Payment',
                  onTap: () {},
                ),
                _SettingTile(
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () {},
                ),
                _SettingTile(
                  icon: Icons.percent,
                  title: 'Promotions',
                  onTap: () {},
                ),
                _SettingTile(
                  icon: Icons.favorite_border,
                  title: 'Favorites',
                  onTap: () {},
                ),
                _SettingTile(
                  icon: Icons.language,
                  title: 'Language',
                  onTap: () {},
                ),

                const SizedBox(height: 8),

                _SectionHeader('Help'),
                _SettingTile(
                  icon: Icons.support_agent,
                  title: 'Support',
                  onTap: () {},
                ),
                _SettingTile(
                  icon: Icons.alternate_email,
                  title: 'Contact',
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                // Logout bar
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFAEDF0),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Logging out...')),
                      );
                      await _auth.logout();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SignInWidget()),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Log out'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 4,
        onTap: (i) {
          switch (i) {
            case 0:
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
              break;
            case 1:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DailyMenuListPage()),
              );
              break;
            case 2:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiChatPage()),
              );
              break;
            case 3:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
              );
              break;
            case 4:
              break; // already here
            default:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tab này sẽ sớm có.')),
              );
          }
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black87),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
