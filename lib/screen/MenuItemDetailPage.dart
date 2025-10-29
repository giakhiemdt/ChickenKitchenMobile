import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/screen/BuildDishWizardPage.dart';

class NutrientInfo {
  final int id;
  final String name;
  final double quantity;
  final String baseUnit;
  const NutrientInfo({required this.id, required this.name, required this.quantity, required this.baseUnit});
  factory NutrientInfo.fromJson(Map<String, dynamic> j) => NutrientInfo(
        id: j['id'] as int,
        name: j['name'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        baseUnit: j['baseUnit'] as String,
      );
}

class RecipeItemInfo {
  final int id;
  final String name;
  const RecipeItemInfo({required this.id, required this.name});
  factory RecipeItemInfo.fromJson(Map<String, dynamic> j) => RecipeItemInfo(
        id: j['id'] as int,
        name: j['name'] as String,
      );
}

class MenuItemDetail {
  final int id;
  final String name;
  final int categoryId;
  final String categoryName;
  final bool isActive;
  final String imageUrl;
  final String createdAt;
  final int price;
  final int cal;
  final String description;
  final List<NutrientInfo> nutrients;
  final List<RecipeItemInfo> recipe;
  const MenuItemDetail({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.isActive,
    required this.imageUrl,
    required this.createdAt,
    required this.price,
    required this.cal,
    required this.description,
    required this.nutrients,
    required this.recipe,
  });
  factory MenuItemDetail.fromJson(Map<String, dynamic> j) => MenuItemDetail(
        id: j['id'] as int,
        name: j['name'] as String,
        categoryId: j['categoryId'] as int,
        categoryName: j['categoryName'] as String,
        isActive: j['isActive'] as bool,
        imageUrl: (j['imageUrl'] ?? '') as String,
        createdAt: (j['createdAt'] ?? '') as String,
        price: (j['price'] ?? 0) as int,
        cal: (j['cal'] ?? 0) as int,
        description: (j['description'] ?? '') as String,
        nutrients: ((j['nutrients'] as List<dynamic>).cast<Map<String, dynamic>>())
            .map(NutrientInfo.fromJson)
            .toList(),
        recipe: ((j['recipe'] as List<dynamic>).cast<Map<String, dynamic>>())
            .map(RecipeItemInfo.fromJson)
            .toList(),
      );
}

class MenuItemDetailPage extends StatefulWidget {
  final int id;
  final bool selectionMode; // when true, show qty + Add, and return qty on add
  final ValueChanged<int>? onAdd;
  final int initialQty;
  const MenuItemDetailPage({
    super.key,
    required this.id,
    this.selectionMode = false,
    this.onAdd,
    this.initialQty = 1,
  });

  @override
  State<MenuItemDetailPage> createState() => _MenuItemDetailPageState();
}

class _MenuItemDetailPageState extends State<MenuItemDetailPage> {
  late Future<MenuItemDetail> _future;
  int _qty = 1;
  bool _showPurchaseBar = false; // for non-selection mode CTA vs purchase

  @override
  void initState() {
    super.initState();
    _future = _fetch(widget.id);
    _qty = widget.initialQty;
    _showPurchaseBar = widget.selectionMode; // in selection mode show qty+add bar
  }

  Future<MenuItemDetail> _fetch(int id) async {
    final uri = Uri.parse('https://chickenkitchen.milize-lena.space/api/menu-items/$id');
    final resp = await http.get(uri, headers: const {'Accept': 'application/json'});
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = map['data'] as Map<String, dynamic>;
    return MenuItemDetail.fromJson(data);
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

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF86C144);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Detail'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: FutureBuilder<MenuItemDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          final d = snap.data!;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, _showPurchaseBar ? 140 : 16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  d.imageUrl.isEmpty
                      ? 'https://images.unsplash.com/photo-1543353071-10c8ba85a904?w=1200'
                      : d.imageUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      d.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(d.categoryName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _formatVnd(d.price),
                    style: const TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text('${d.cal} cal', style: const TextStyle(color: Colors.black54)),
                  const Spacer(),
                  if (d.isActive)
                    Row(
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 4),
                        Text('Available'),
                      ],
                    )
                  else
                    Row(
                      children: const [
                        Icon(Icons.cancel, color: Colors.redAccent, size: 18),
                        SizedBox(width: 4),
                        Text('Unavailable'),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(d.description, style: const TextStyle(color: Colors.black87, height: 1.4)),
              const SizedBox(height: 16),
              const Text('Nutrients', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in d.nutrients)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Text('${n.name}: ${n.quantity}${n.baseUnit}'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Recipe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in d.recipe)
                    Chip(
                      label: Text(r.name),
                      backgroundColor: Colors.grey.shade100,
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
      bottomNavigationBar: widget.selectionMode ? SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Quantity selector
              Container(
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Decrease',
                      onPressed: (widget.selectionMode ? _qty > 0 : _qty > 1)
                          ? () => setState(() => _qty--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 28,
                      child: Center(
                        child: Text('$_qty', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Increase',
                      onPressed: () => setState(() => _qty++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // In selection mode, allow returning 0 to indicate removal
                    final qty = widget.selectionMode
                        ? (_qty < 0 ? 0 : _qty)
                        : (_qty < 1 ? 1 : _qty);
                    // Prefer returning result via Navigator.pop
                    if (widget.onAdd != null) widget.onAdd!(qty);
                    Navigator.of(context).pop<int>(qty);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ),
      ) : SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BuildDishWizardPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            ),
            child: const Text('Build your dish now'),
          ),
        ),
      ),
    );
  }
}
