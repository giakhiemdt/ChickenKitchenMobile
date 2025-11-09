import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/features/auth/data/auth_service.dart';
import 'package:mobiletest/features/store/data/store_service.dart';
import 'package:mobiletest/core/services/http_guard.dart';

class DishDetailPage extends StatefulWidget {
  final int dishId;
  const DishDetailPage({super.key, required this.dishId});

  @override
  State<DishDetailPage> createState() => _DishDetailPageState();
}

class _DishDetailPageState extends State<DishDetailPage> {
  Map<String, dynamic>? _dish;
  bool _loading = false;
  String? _error;
  int _quantity = 1;

  static const String _fallbackImage =
      'https://images.unsplash.com/photo-1543353071-10c8ba85a904?auto=format&fit=crop&q=80&w=1200';

  @override
  void initState() {
    super.initState();
    _fetch();
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

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final headers = await AuthService().authHeaders();
      if (headers.isEmpty || !headers.containsKey('Authorization')) {
        throw Exception('Missing token');
      }
      final uri = Uri.parse(
          'https://chickenkitchen.milize-lena.space/api/dishes/${widget.dishId}');
      final resp = await http.get(uri, headers: headers);
      if (await HttpGuard.handleUnauthorized(context, resp)) return;
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      setState(() {
        _dish = (json['data'] as Map<String, dynamic>);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToCurrentOrder() async {
    if (_dish == null) return;
    try {
      final headers = await AuthService().authHeaders();
      if (!(headers['Authorization']?.startsWith('Bearer ') ?? false)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bạn cần đăng nhập.')));
        return;
      }
      final storeId = await StoreService.getSelectedStoreId() ?? 1;
      final isCustom = (_dish!['isCustom'] as bool?) ?? false;
      http.Response resp;
      if (!isCustom) {
        // Add existing dish shortcut
        final uri = Uri.parse(
            'https://chickenkitchen.milize-lena.space/api/orders/current/dishes/existing');
        final body = jsonEncode({
          'storeId': storeId,
          'dishId': _dish!['id'],
          'quantity': _quantity,
        });
        resp = await http.post(uri, headers: headers, body: body);
        if (await HttpGuard.handleUnauthorized(context, resp)) return;
      } else {
        // Fallback to custom add with selections
        final note = (_dish!['note'] as String?)?.trim();
        final steps = ((_dish!['steps'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>();
        final selections = <Map<String, dynamic>>[];
        for (final s in steps) {
          final stepId = s['stepId'] as int?;
          final items = ((s['items'] as List<dynamic>?) ?? const [])
              .cast<Map<String, dynamic>>();
          if (stepId == null || items.isEmpty) continue;
          final payloadItems = <Map<String, dynamic>>[];
          for (final it in items) {
            final menuItemId = it['menuItemId'] as int?;
            final qty = (it['quantity'] as int? ?? 1) * _quantity;
            if (menuItemId != null && qty > 0) {
              payloadItems.add({'menuItemId': menuItemId, 'quantity': qty});
            }
          }
          if (payloadItems.isNotEmpty) {
            selections.add({'stepId': stepId, 'items': payloadItems});
          }
        }

        if (selections.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không có dữ liệu món để thêm.')),
          );
          return;
        }
        final uri = Uri.parse(
            'https://chickenkitchen.milize-lena.space/api/orders/current/dishes/custom');
        final body = jsonEncode({
          'storeId': storeId,
          if (note != null && note.isNotEmpty) 'note': note,
          'selections': selections,
          'isCustom': true,
        });
        resp = await http.post(uri, headers: headers, body: body);
        if (await HttpGuard.handleUnauthorized(context, resp)) return;
      }
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm ${_quantity}x vào đơn hiện tại.')),
        );
        Navigator.of(context).pop(true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Thêm thất bại: HTTP ${resp.statusCode}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFB71C1C);
    final dish = _dish;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dish Detail'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Failed: $_error'))
              : dish == null
                  ? const Center(child: Text('No data'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 88),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              (dish['imageUrl'] as String?)?.isNotEmpty == true
                                  ? dish['imageUrl'] as String
                                  : _fallbackImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.network(
                                _fallbackImage,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (dish['name'] as String?) ?? 'Dish #${dish['id']}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      _formatVnd((dish['price'] as int?) ?? 0),
                                      style: const TextStyle(
                                        color: primary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.local_fire_department,
                                        size: 16, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text('${dish['cal'] ?? 0} cal',
                                        style: const TextStyle(
                                            color: Colors.black54)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if ((dish['note'] as String?)?.isNotEmpty == true)
                                  Text(
                                    dish['note'] as String,
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black87, height: 1.3),
                                  ),
                              ],
                            ),
                          ),

                          // Steps
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Text('Included Items',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 8),
                          ...(((dish['steps'] as List<dynamic>?) ?? const [])
                                  .cast<Map<String, dynamic>>())
                              .map((s) {
                            final stepName = s['stepName'] as String? ?? 'Step';
                            final items = ((s['items'] as List<dynamic>?) ?? const [])
                                .cast<Map<String, dynamic>>();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    child: Text(stepName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  ...items.map((it) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 6),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: SizedBox(
                                                width: 54,
                                                height: 54,
                                                child: Image.network(
                                                  (it['imageUrl'] as String?)
                                                              ?.isNotEmpty ==
                                                          true
                                                      ? it['imageUrl'] as String
                                                      : _fallbackImage,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Image.network(
                                                          _fallbackImage,
                                                          fit: BoxFit.cover),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(it['name'] as String? ?? 'Item',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        _formatVnd((it['price']
                                                                    as int?) ??
                                                                0),
                                                        style: const TextStyle(
                                                            color: primary,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Icon(
                                                          Icons
                                                              .local_fire_department,
                                                          size: 14,
                                                          color: Colors
                                                              .orange),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                          '${it['cal'] ?? 0} cal',
                                                          style: const TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .black54)),
                                                      const Spacer(),
                                                      Text('x${it['quantity'] ?? 1}',
                                                          style: const TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .black54)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            );
                          }),

                          // Nutrients
                          if ((dish['nutrients'] as List<dynamic>?)
                                  ?.isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: const Text('Nutrients',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ((dish['nutrients']
                                            as List<dynamic>)
                                        .cast<Map<String, dynamic>>())
                                    .map((n) {
                                  final name = n['name'] as String? ?? '';
                                  final qty = n['quantity'];
                                  final unit = n['baseUnit'] as String? ?? '';
                                  return Chip(
                                    label: Text('$name: $qty $unit'),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              // Quantity stepper
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity -= 1)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$_quantity', style: const TextStyle(fontSize: 16)),
                    IconButton(
                      onPressed: () => setState(() => _quantity += 1),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _addToCurrentOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB71C1C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Add'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
