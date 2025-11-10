import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/features/menu/presentation/BuildDishWizardPage.dart';
import 'package:mobiletest/features/auth/data/auth_service.dart';
import 'package:mobiletest/core/services/http_guard.dart';
import 'package:mobiletest/features/store/data/store_service.dart';
import 'package:mobiletest/features/orders/data/cart_events.dart';
import 'package:mobiletest/features/orders/presentation/ConfirmOrderPage.dart';

class CurrentOrderPage extends StatefulWidget {
  const CurrentOrderPage({super.key});

  @override
  State<CurrentOrderPage> createState() => _CurrentOrderPageState();
}

class _CurrentOrderPageState extends State<CurrentOrderPage> {
  late Future<Map<String, dynamic>?> _future;
  final Map<int, bool> _expanded = <int, bool>{};
  bool _editMode = false;
  final Set<int> _selected = <int>{};
  bool _deleting = false;
  StreamSubscription<void>? _cartSub;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
    _cartSub = CartEvents.stream.listen((_) {
      if (!mounted) return;
      _refresh();
    });
  }

  // Removed cart-level cancel API logic per request. Keep UI; actual
  // integration will be replaced with a new API later.

  Future<Map<String, dynamic>?> _fetch() async {
    final storeId = await StoreService.getSelectedStoreId() ?? 1;
    final headers = await AuthService().authHeaders();
    final uri = Uri.parse(
      'https://chickenkitchen.milize-lena.space/api/orders/current?storeId=$storeId',
    );
    final resp = await http.get(
      uri,
      headers: headers.isEmpty ? {'Accept': 'application/json'} : headers,
    );
    if (await HttpGuard.handleUnauthorized(context, resp)) return null;
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    return map['data'] as Map<String, dynamic>?; // can be null
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetch();
    });
  }

  Future<bool> _deleteDish(int dishId) async {
    try {
      final headers = await AuthService().authHeaders();
      if (!(headers['Authorization']?.startsWith('Bearer ') ?? false)) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn cần đăng nhập để xoá món.')),
        );
        return false;
      }
      final uri = Uri.parse(
        'https://chickenkitchen.milize-lena.space/api/orders/dishes/$dishId',
      );
      final resp = await http.delete(uri, headers: headers);
      if (await HttpGuard.handleUnauthorized(context, resp)) return false;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      } else {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xoá thất bại: HTTP ${resp.statusCode}')),
        );
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi xoá: $e')));
      return false;
    }
  }

  @override
  void dispose() {
    _cartSub?.cancel();
    super.dispose();
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

  Widget _itemCard(Map<String, dynamic> it, String stepName) {
    const primary = Color(0xFFB71C1C);
    final name = it['menuItemName'] as String? ?? 'Item';
    final price = (it['price'] ?? 0) as int;
    final cal = (it['cal'] ?? 0) as int;
    final qty = (it['quantity'] ?? 1) as int;
    final imageUrl = (it['imageUrl'] as String?)?.isNotEmpty == true
        ? it['imageUrl'] as String
        : 'https://images.unsplash.com/photo-1543353071-10c8ba85a904?w=800';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 90,
              height: 70,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.network(
                  'https://images.unsplash.com/photo-1543353071-10c8ba85a904?w=800',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step as category tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stepName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'x$qty',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatVnd(price),
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
                      '$cal cal',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFB71C1C);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _editMode = !_editMode;
              if (!_editMode) _selected.clear();
            }),
            style: TextButton.styleFrom(
              foregroundColor: primary,
            ),
            child: Text(_editMode ? 'Cancel' : 'Edit'),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Failed to load order: ${snap.error}'),
              ),
            );
          }
          final data = snap.data; // may be null
          if (data == null) {
            return _EmptyState(
              onAdd: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BuildDishWizardPage(),
                  ),
                );
              },
            );
          }
          final dishes =
              (data['dishes'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              const <Map<String, dynamic>>[];
          if (dishes.isEmpty) {
            return _EmptyState(
              onAdd: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BuildDishWizardPage(),
                  ),
                );
              },
            );
          }
          return Stack(
            children: [
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: dishes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final d = dishes[i];
                  final dishId = (d['dishId'] ?? i) as int;
                  final expanded = _expanded[dishId] ?? false;
                  final steps =
                      (d['steps'] as List<dynamic>?)
                          ?.cast<Map<String, dynamic>>() ??
                      const <Map<String, dynamic>>[];
                  return Dismissible(
                    key: ValueKey('dish_$dishId'),
                    direction: DismissDirection.endToStart,
                    background: const SizedBox.shrink(),
                    secondaryBackground: Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.delete, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    confirmDismiss: (dir) async {
                      if (dir != DismissDirection.endToStart) return false;
                      final ok = await _deleteDish(dishId);
                      if (ok) await _refresh();
                      return ok;
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        children: [
                          // Header
                          InkWell(
                            onTap: () async {
                              if (_editMode) {
                                setState(() {
                                  if (_selected.contains(dishId)) {
                                    _selected.remove(dishId);
                                  } else {
                                    _selected.add(dishId);
                                  }
                                });
                                return;
                              }
                              // Only allow editing if dish is custom
                              final isCustom = (d['isCustom'] as bool?) ?? false;
                              if (!isCustom) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Only custom dishes can be edited.')),
                                );
                                return;
                              }
                              // Build initial selections from current dish
                              final Map<int, Map<int, int>> initial = {};
                              for (final s in steps) {
                                final sid = (s['stepId'] ?? 0) as int;
                                final map = initial.putIfAbsent(
                                  sid,
                                  () => <int, int>{},
                                );
                                final items =
                                    (s['items'] as List<dynamic>?)
                                        ?.cast<Map<String, dynamic>>() ??
                                    const <Map<String, dynamic>>[];
                                for (final it in items) {
                                  final mid = (it['menuItemId'] ?? 0) as int;
                                  final q = (it['quantity'] ?? 0) as int;
                                  if (mid > 0 && q > 0) map[mid] = q;
                                }
                              }
                              final note = (d['note'] as String?) ?? '';
                              final updated = await Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => BuildDishWizardPage(
                                        editingDishId: dishId,
                                        initialSelections: initial,
                                        initialNote: note,
                                      ),
                                    ),
                                  );
                              if (updated == true) {
                                await _refresh();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_editMode)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                        top: 2,
                                      ),
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: _selected.contains(dishId),
                                          onChanged: (v) => setState(() {
                                            if (v == true) {
                                              _selected.add(dishId);
                                            } else {
                                              _selected.remove(dishId);
                                            }
                                          }),
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                (d['name'] as String?)?.isNotEmpty == true
                                                    ? d['name'] as String
                                                    : 'Dish #$dishId',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: primary.withOpacity(.12),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Text(
                                                '${data['status'] ?? 'NEW'}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        if ((d['note'] as String?)
                                                ?.isNotEmpty ==
                                            true)
                                          Text(
                                            d['note'] as String,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.local_fire_department,
                                              size: 16,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${d['cal'] ?? 0} cal',
                                              style: const TextStyle(
                                                color: Colors.black54,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              _formatVnd(
                                                (d['price'] ?? 0) as int,
                                              ),
                                              style: const TextStyle(
                                                color: primary,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _expanded[dishId] = !expanded,
                                    ),
                                    child: AnimatedRotation(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      turns: expanded ? 0.5 : 0,
                                      child: const Icon(
                                        Icons.keyboard_arrow_down,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Expanded content
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 200),
                            crossFadeState: expanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final s in steps) ...[
                                    ...((s['items'] as List<dynamic>?)
                                            ?.cast<Map<String, dynamic>>()
                                            .map(
                                              (it) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: _itemCard(
                                                  it,
                                                  s['stepName'] as String? ??
                                                      'Step',
                                                ),
                                              ),
                                            )
                                            .toList() ??
                                        const <Widget>[]),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Order now bar
              SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
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
                    child: _editMode
                        ? ElevatedButton(
                            onPressed: _selected.isEmpty || _deleting
                                ? null
                                : () async {
                                    setState(() => _deleting = true);
                                    try {
                                      bool allOk = true;
                                      for (final id in _selected.toList()) {
                                        final ok = await _deleteDish(id);
                                        allOk = allOk && ok;
                                      }
                                      await _refresh();
                                      _selected.clear();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            allOk
                                                ? 'Đã xoá món đã chọn'
                                                : 'Một số món xoá thất bại',
                                          ),
                                        ),
                                      );
                                    } finally {
                                      if (mounted) setState(() => _deleting = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: Text(_deleting ? 'Deleting...' : 'Delete'),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ConfirmOrderPage(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: const Text('Continue'),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFB71C1C);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                'https://images.unsplash.com/photo-1515003197210-e0cd71810b5f?w=1080',
                width: 220,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có món nào',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy thêm món mới cho đơn hiện tại',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add new dish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
