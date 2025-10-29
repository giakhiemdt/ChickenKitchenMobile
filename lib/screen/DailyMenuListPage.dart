import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/components/categories_strip.dart';
import 'package:mobiletest/components/app_bottom_nav.dart';
import 'package:mobiletest/screen/HomePage.dart';
import 'package:mobiletest/screen/RestaurantsListPage.dart';
import 'package:mobiletest/screen/ProfilePage.dart';
import 'package:mobiletest/screen/MenuItemDetailPage.dart';
import 'package:mobiletest/services/store_service.dart';
import 'package:mobiletest/components/dual_fabs.dart';
import 'package:mobiletest/screen/BuildDishWizardPage.dart';
import 'package:mobiletest/screen/CurrentOrderPage.dart';

class SpecialItem {
  final int id;
  final String name;
  final int price;
  final int cal;
  final String imageUrl;
  final int categoryId;
  final String categoryName;
  final String description;

  const SpecialItem({
    required this.id,
    required this.name,
    required this.price,
    required this.cal,
    required this.imageUrl,
    required this.categoryId,
    required this.categoryName,
    required this.description,
  });

  factory SpecialItem.fromJson(Map<String, dynamic> j) => SpecialItem(
        id: j['id'] as int,
        name: j['name'] as String,
        price: (j['price'] ?? 0) as int,
        cal: (j['cal'] ?? 0) as int,
        imageUrl: (j['imageUrl'] ?? '') as String,
        categoryId: (j['categoryId'] ?? 0) as int,
        categoryName: (j['categoryName'] ?? '') as String,
        description: (j['description'] ?? '') as String,
      );
}

class _ItemWithCategory {
  final SpecialItem item;
  _ItemWithCategory(this.item);
}

class DailyMenuListPage extends StatefulWidget {
  final String? initialSelectedCategoryName;
  const DailyMenuListPage({super.key, this.initialSelectedCategoryName});

  @override
  State<DailyMenuListPage> createState() => _DailyMenuListPageState();
}

class _DailyMenuListPageState extends State<DailyMenuListPage> {
  late Future<List<_ItemWithCategory>> _future;
  final _search = TextEditingController();
  String _query = '';
  Set<String> _selectedCategoryNames = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _fetch();
    if (widget.initialSelectedCategoryName != null &&
        widget.initialSelectedCategoryName!.isNotEmpty) {
      _selectedCategoryNames = {widget.initialSelectedCategoryName!};
    }
    _search.addListener(() {
      setState(() => _query = _search.text.trim());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _today() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Future<List<_ItemWithCategory>> _fetch() async {
    final date = _today();
    final storeId = await StoreService.getSelectedStoreId() ?? 1;
    final uri = Uri.parse(
        'https://chickenkitchen.milize-lena.space/api/daily-menu/store/$storeId?date=$date');
    final resp = await http.get(uri, headers: const {'Accept': 'application/json'});
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = map['data'] as Map<String, dynamic>;
    final categories = (data['categories'] as List<dynamic>).cast<Map<String, dynamic>>();
    final items = <_ItemWithCategory>[];
    for (final c in categories) {
      final list = (c['items'] as List<dynamic>).cast<Map<String, dynamic>>();
      for (final it in list) {
        final item = SpecialItem.fromJson(it);
        items.add(_ItemWithCategory(item));
      }
    }
    return items;
  }

  Color _categoryTint(String name) {
    switch (name) {
      case 'Carbohydrates':
        return const Color(0xFFE9F7D3);
      case 'Proteins':
        return const Color(0xFFD9F6F0);
      case 'Vegetables':
        return const Color(0xFFE3F5E1);
      case 'Sauces':
        return const Color(0xFFFFECD6);
      case 'Dairy':
        return const Color(0xFFE3F0FF);
      case 'Fruits':
        return const Color(0xFFFFE3EC);
      default:
        return const Color(0xFFF1F7E8);
    }
  }

  String _formatVnd(int vnd) {
    final s = vnd.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      buf.write(s[i]);
      if (idx > 1 && idx % 3 == 1) buf.write(',');
    }
    return '${buf.toString()} ₫';
  }

  String _image(String url, String category) {
    bool bad = url.isEmpty || url.contains('example.com');
    if (!bad) return url;
    switch (category) {
      case 'Carbohydrates':
        return 'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=1200';
      case 'Proteins':
        return 'https://images.unsplash.com/photo-1553163147-622ab57be1c7?w=1200';
      case 'Vegetables':
        return 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=1200';
      case 'Sauces':
        return 'https://picsum.photos/seed/sauce/1200/800';
      case 'Dairy':
        return 'https://images.unsplash.com/photo-1541698444083-023c97d3f4b6?w=1200';
      case 'Fruits':
        return 'https://images.unsplash.com/photo-1546554137-f86b9593a222?w=1200';
      default:
        return 'https://images.unsplash.com/photo-1543353071-10c8ba85a904?w=1200';
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF86C144);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Specials"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Stack(
        children: [
          Column(
            children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search dishes',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primary),
                ),
              ),
            ),
          ),
          // Categories icons row
          CategoriesStrip(
            selectedNames: _selectedCategoryNames,
            onTap: (c) {
              setState(() {
                if (_selectedCategoryNames.contains(c.name)) {
                  _selectedCategoryNames.remove(c.name);
                } else {
                  _selectedCategoryNames.add(c.name);
                }
              });
            },
          ),
          const SizedBox(height: 8),
          // Results
          Expanded(
            child: FutureBuilder<List<_ItemWithCategory>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Failed to load menu: ${snap.error}'),
                    ),
                  );
                }
                var list = snap.data ?? const <_ItemWithCategory>[];
                if (_query.isNotEmpty) {
                  final q = _query.toLowerCase();
                  list = list
                      .where((e) => e.item.name.toLowerCase().contains(q))
                      .toList(growable: false);
                }
                if (_selectedCategoryNames.isNotEmpty) {
                  list = list
                      .where((e) => _selectedCategoryNames.contains(e.item.categoryName))
                      .toList(growable: false);
                }
                if (list.isEmpty) {
                  return const Center(child: Text('No items match your search'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final it = list[i].item;
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MenuItemDetailPage(id: it.id),
                          ),
                        );
                      },
                      child: Container(
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
                            child: SizedBox(
                              width: 120,
                              height: 110,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                clipBehavior: Clip.hardEdge,
                                child: Image.network(
                                  _image(it.imageUrl, it.categoryName),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _categoryTint(it.categoryName),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    it.categoryName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  it.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      _formatVnd(it.price),
                                      style: const TextStyle(
                                        color: primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.local_fire_department,
                                        size: 14, color: Colors.orange),
                                    const SizedBox(width: 2),
                                    Text('${it.cal} cal',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.black54)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  it.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ));
                  },
                );
              },
            ),
          ),
            ],
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
        currentIndex: 1, // not a fixed tab; keep selection neutral
        onTap: (i) {
          switch (i) {
            case 0:
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
              break;
            case 2:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RestaurantsListPage()),
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
