import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

class RestaurantsCarousel extends StatefulWidget {
  final Color primary;
  const RestaurantsCarousel({super.key, required this.primary});

  @override
  State<RestaurantsCarousel> createState() => _RestaurantsCarouselState();
}

class _RestaurantsCarouselState extends State<RestaurantsCarousel> {
  late PageController _controller;
  Timer? _timer;
  List<Store>? _stores;
  int _page = 0;
  double? _lastFraction;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.95);
    _fetchStores();
  }

  Future<void> _fetchStores() async {
    try {
      final uri = Uri.parse(
        'https://chickenkitchen.milize-lena.space/api/store',
      );
      final resp = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (map['data'] as List<dynamic>).cast<Map<String, dynamic>>();
      final stores = list.take(4).map(Store.fromJson).toList();
      if (!mounted) return;
      setState(() => _stores = stores);
      _startAutoPlay();
    } catch (_) {
      if (!mounted) return;
      setState(() => _stores = const []);
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _stores == null || _stores!.isEmpty) return;
      _page = (_page + 1) % _stores!.length;
      _controller.animateToPage(
        _page,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final itemsPerView = width >= 900
        ? 3
        : width >= 600
        ? 2
        : 1;
    final fraction = 1 / itemsPerView * 0.95;
    if (_lastFraction != fraction) {
      final old = _controller;
      _controller = PageController(
        viewportFraction: fraction,
        initialPage: _page,
      );
      _lastFraction = fraction;
      old.dispose();
    }

    if (_stores == null) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_stores!.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text('No stores available')),
      );
    }

    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: _controller,
        itemCount: _stores!.length,
        onPageChanged: (i) => _page = i,
        itemBuilder: (context, i) {
          final s = _stores![i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: _StoreCard(store: s, primary: widget.primary),
          );
        },
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Store store;
  final Color primary;
  const _StoreCard({required this.store, required this.primary});

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
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Stack(
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=1200',
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                // Open status badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primary.withOpacity(.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Open',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      color: Colors.black87,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        store.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 2),
                    Text(
                      _ratingFor(store).toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      ' (${_formatCount(_ratingCountFor(store))})',
                      style: const TextStyle(color: Colors.black54),
                    ),
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
                        store.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
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
  }
}
