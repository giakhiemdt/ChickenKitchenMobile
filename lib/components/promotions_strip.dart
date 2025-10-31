import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Promotion {
  final int id;
  final String name;
  final String description;
  final String code;
  final String discountType; // PERCENT or AMOUNT
  final int discountValue;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  const Promotion({
    required this.id,
    required this.name,
    required this.description,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  factory Promotion.fromJson(Map<String, dynamic> j) => Promotion(
        id: j['id'] as int,
        name: j['name'] as String,
        description: (j['description'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        discountType: (j['discountType'] ?? 'PERCENT') as String,
        discountValue: (j['discountValue'] ?? 0) as int,
        startDate: DateTime.parse(j['startDate'] as String),
        endDate: DateTime.parse(j['endDate'] as String),
        isActive: (j['isActive'] ?? false) as bool,
      );
}

class PromotionsStrip extends StatefulWidget {
  const PromotionsStrip({super.key});

  @override
  State<PromotionsStrip> createState() => _PromotionsStripState();
}

class _PromotionsStripState extends State<PromotionsStrip> {
  late Future<List<Promotion>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
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

  Future<List<Promotion>> _fetch() async {
    final uri = Uri.parse('https://chickenkitchen.milize-lena.space/api/promotion');
    final resp = await http.get(uri, headers: const {'Accept': 'application/json'});
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (map['data'] as List<dynamic>).cast<Map<String, dynamic>>();
    final now = DateTime.now();
    return list
        .map(Promotion.fromJson)
        .where((p) => p.isActive && !now.isBefore(p.startDate) && !now.isAfter(p.endDate))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
  const primary = Color(0xFFB71C1C);
    return SizedBox(
      height: 130,
      child: FutureBuilder<List<Promotion>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Failed to load promotions: ${snap.error}')),
                ],
              ),
            );
          }
          final promos = snap.data ?? const <Promotion>[];
          if (promos.isEmpty) {
            return const Center(child: Text('No active promotions'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: promos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final p = promos[i];
              final badge = p.discountType == 'AMOUNT'
                  ? '${_formatVnd(p.discountValue)} OFF'
                  : '${p.discountValue}% OFF';
              return Container(
                width: 240,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_offer, size: 14, color: Color(0xFFB71C1C)),
                              const SizedBox(width: 4),
                              Text(
                                p.code,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7A1414),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
