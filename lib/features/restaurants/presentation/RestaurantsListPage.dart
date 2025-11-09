import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/shared/widgets/app_bottom_nav.dart';
import 'package:mobiletest/shared/widgets/dual_fabs.dart';
import 'package:mobiletest/features/menu/presentation/BuildDishWizardPage.dart';
import 'package:mobiletest/features/home/presentation/HomePage.dart';
import 'package:mobiletest/features/profile/presentation/ProfilePage.dart';
import 'package:mobiletest/features/orders/presentation/CurrentOrderPage.dart';
import 'package:mobiletest/features/menu/presentation/DailyMenuListPage.dart';
import 'package:mobiletest/features/orders/presentation/OrderHistoryPage.dart';

class Store {
  final int id;
  final String name;
  final String address;
  const Store({required this.id, required this.name, required this.address});

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: j['id'] as int,
        name: j['name'] as String,
        address: (j['address'] ?? '') as String,
      );
}

class RestaurantsListPage extends StatefulWidget {
  const RestaurantsListPage({super.key});

  @override
  State<RestaurantsListPage> createState() => _RestaurantsListPageState();
}

class _RestaurantsListPageState extends State<RestaurantsListPage> {
  late Future<List<Store>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchStores();
  }

  Future<List<Store>> _fetchStores() async {
    final uri = Uri.parse('https://chickenkitchen.milize-lena.space/api/store');
    final resp = await http.get(uri, headers: const {'Accept': 'application/json'});
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (map['data'] as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(Store.fromJson).toList();
  }

  static double _ratingFor(Store s) {
    final base = 4.2;
    final delta = (s.id % 8) / 20.0; // up to +0.35
    double r = base + delta;
    if (r > 4.9) r = 4.9;
    return r;
  }

  static int _ratingCountFor(Store s) => 350 + s.id * 127;

  static String _formatCount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      buf.write(s[i]);
      if (idx > 1 && idx % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF86C144);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurants'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Stack(
        children: [
          FutureBuilder<List<Store>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Failed to load stores: ${snap.error}'),
              ),
            );
          }
          final stores = snap.data ?? const <Store>[];
          if (stores.isEmpty) {
            return const Center(child: Text('No stores available'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: stores.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final s = stores[i];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=800',
                        width: 110,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 2),
                              Text(
                                _ratingFor(s).toStringAsFixed(1),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(' (${_formatCount(_ratingCountFor(s))})',
                                  style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.place, size: 14, color: Colors.black45),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  s.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
          ),
          DualFABs(
            onAddDish: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BuildDishWizardPage()),
              );
            },
            onCart: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CurrentOrderPage()),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 2,
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
              break; // already here
            case 3:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
              );
              break;
            case 4:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
              break;
            default:
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Tab này sẽ sớm có.')));
          }
        },
      ),
    );
  }
}
