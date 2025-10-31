import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/screen/MenuItemDetailPage.dart';
import 'package:mobiletest/services/store_service.dart';

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

class SpecialCategory {
  final int id;
  final String name;
  final List<SpecialItem> items;
  const SpecialCategory({required this.id, required this.name, required this.items});

  factory SpecialCategory.fromJson(Map<String, dynamic> j) => SpecialCategory(
        id: j['categoryId'] as int,
        name: j['categoryName'] as String,
        items: ((j['items'] as List<dynamic>).cast<Map<String, dynamic>>())
            .map(SpecialItem.fromJson)
            .toList(),
      );
}

class TodaysSpecials extends StatefulWidget {
  const TodaysSpecials({super.key});

  @override
  State<TodaysSpecials> createState() => _TodaysSpecialsState();
}

class _TodaysSpecialsState extends State<TodaysSpecials> {
  late Future<List<SpecialCategory>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  String _today() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Future<List<SpecialCategory>> _fetch() async {
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
    final cats = (data['categories'] as List<dynamic>).cast<Map<String, dynamic>>();
    return cats.map(SpecialCategory.fromJson).toList();
  }

  // Bright, fresh tints mapped per category
  Color _categoryTint(String name) {
    switch (name) {
      case 'Carbohydrates':
        return const Color(0xFFE9F7D3); // light green
      case 'Proteins':
        return const Color(0xFFD9F6F0); // light teal
      case 'Vegetables':
        return const Color(0xFFE3F5E1); // minty green
      case 'Sauces':
        return const Color(0xFFFFECD6); // light orange
      case 'Dairy':
        return const Color(0xFFE3F0FF); // light blue
      case 'Fruits':
        return const Color(0xFFFFE3EC); // light pink
      default:
        return const Color(0xFFF1F7E8); // safe default
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

  String _sanitizedUrl(String url, String categoryName) {
    bool bad = url.isEmpty || url.contains('example.com');
    if (!bad) return url;
    switch (categoryName) {
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
  const primary = Color(0xFFB71C1C);
    return FutureBuilder<List<SpecialCategory>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(child: Text('Failed to load specials: ${snap.error}')),
            ]),
          );
        }

        final categories = snap.data ?? const <SpecialCategory>[];
        if (categories.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No specials for today'),
          );
        }

        return Column(
          children: [
            for (final c in categories) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _categoryTint(c.name),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_dining, size: 16, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 210,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: c.items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final it = c.items[i];
                    return SizedBox(
                      width: 160,
                      child: InkWell(
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
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  SizedBox(
                                    height: 96,
                                    width: double.infinity,
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      clipBehavior: Clip.hardEdge,
                                      child: Image.network(
                                        _sanitizedUrl(it.imageUrl, it.categoryName),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.favorite_border,
                                        size: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              it.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  _formatVnd(it.price),
                                  style: const TextStyle(
                                    color: Color(0xFFB71C1C),
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
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
            ],
          ],
        );
      },
    );
  }
}
