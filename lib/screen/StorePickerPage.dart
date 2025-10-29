import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/services/store_service.dart';
import 'package:mobiletest/screen/HomePage.dart';

class StorePickerPage extends StatefulWidget {
  const StorePickerPage({super.key});

  @override
  State<StorePickerPage> createState() => _StorePickerPageState();
}

class _StorePickerPageState extends State<StorePickerPage> {
  late Future<List<StoreInfo>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchStores();
  }

  Future<List<StoreInfo>> _fetchStores() async {
    final uri = Uri.parse('https://chickenkitchen.milize-lena.space/api/store');
    final resp = await http.get(uri, headers: const {'Accept': 'application/json'});
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (map['data'] as List<dynamic>).cast<Map<String, dynamic>>();
    return list
        .map((j) => StoreInfo(
              id: j['id'] as int,
              name: j['name'] as String,
              address: (j['address'] ?? '') as String,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF86C144);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Store'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: FutureBuilder<List<StoreInfo>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load stores: ${snap.error}'));
          }
          final stores = snap.data ?? const <StoreInfo>[];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: stores.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final s = stores[i];
              return InkWell(
                onTap: () async {
                  await StoreService.saveSelectedStore(s);
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE9F7D3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.store_mall_directory, color: primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(s.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

