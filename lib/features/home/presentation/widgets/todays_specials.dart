import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/features/auth/data/auth_service.dart';
import 'package:mobiletest/core/services/http_guard.dart';
import 'package:mobiletest/features/menu/presentation/DishDetailPage.dart';

// Model for new dishes API
class DishItem {
  final int id;
  final String name;
  final int price;
  final int cal;
  final bool isCustom; // not displayed
  final String note;
  final String imageUrl;

  const DishItem({
    required this.id,
    required this.name,
    required this.price,
    required this.cal,
    required this.isCustom,
    required this.note,
    required this.imageUrl,
  });

  factory DishItem.fromJson(Map<String, dynamic> j) => DishItem(
    id: j['id'] as int,
    name: (j['name'] ?? '') as String,
    price: (j['price'] ?? 0) as int,
    cal: (j['cal'] ?? 0) as int,
    isCustom: (j['isCustom'] ?? false) as bool,
    note: (j['note'] ?? '') as String,
    imageUrl: (j['imageUrl'] ?? '') as String,
  );
}

class TodaysSpecials extends StatefulWidget {
  const TodaysSpecials({super.key});

  @override
  State<TodaysSpecials> createState() => _TodaysSpecialsState();
}

class _TodaysSpecialsState extends State<TodaysSpecials> {
  final List<DishItem> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _size = 50; // fixed per requirements
  String? _error;
  // No local add/quantity logic here; ordering is handled in DishDetailPage

  static const String _fallbackImage =
      'https://images.unsplash.com/photo-1543353071-10c8ba85a904?auto=format&fit=crop&q=80&w=1200';

  @override
  void initState() {
    super.initState();
    _fetchPage(_page);
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

  Future<void> _fetchPage(int page) async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
        'https://chickenkitchen.milize-lena.space/api/dishes?size=$_size&pageNumber=$page',
      );
      final headers = await AuthService().authHeaders();
      final h = headers.isEmpty
          ? const {'Accept': 'application/json'}
          : headers;
      final resp = await http.get(uri, headers: h);
      if (await HttpGuard.handleUnauthorized(context, resp)) return;
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (map['data'] as List<dynamic>).cast<Map<String, dynamic>>();
      final fetched = list.map(DishItem.fromJson).toList();
      setState(() {
        _items.addAll(fetched);
        _page += 1;
        _hasMore = fetched.length == _size; // if less than size, no more pages
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // No +/- here; use DishDetailPage for ordering and quantity changes

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFB71C1C);

    if (_error != null && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(child: Text('Failed to load specials: $_error')),
          ],
        ),
      );
    }

    if (_items.isEmpty && _loading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No specials for today'),
      );
    }

    // Use shrinkWrap + never scroll so it composes inside HomePage's SingleChildScrollView
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length + (_loading ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (i >= _items.length) {
                // loader row
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              // Prefetch next page when nearing the end of current items
              if (i >= _items.length - 5 && _hasMore && !_loading) {
                _fetchPage(_page);
              }

              final it = _items[i];
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DishDetailPage(dishId: it.id),
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
                  constraints: const BoxConstraints(minHeight: 120),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            SizedBox(
                              width: 110,
                              height: 110,
                              child: Image.network(
                                it.imageUrl.isNotEmpty ? it.imageUrl : _fallbackImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.network(
                                    _fallbackImage,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                            // Removed inline add/quantity controls; open details to order
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.name.isNotEmpty ? it.name : 'Dish #${it.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              it.note,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
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
                                const Icon(
                                  Icons.local_fire_department,
                                  size: 14,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${it.cal} cal',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_error != null && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Load more failed: $_error')),
                  TextButton(
                    onPressed: () => _fetchPage(_page),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          // No confirm bar here; ordering happens in details
        ],
      ),
    );
  }
}
