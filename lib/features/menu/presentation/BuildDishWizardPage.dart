import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/features/store/data/store_service.dart';
import 'package:mobiletest/features/menu/presentation/MenuItemDetailPage.dart';
import 'package:mobiletest/features/auth/data/auth_service.dart';
import 'package:mobiletest/core/services/http_guard.dart';

class StepModel {
  final int id;
  final String name;
  final String description;
  final int categoryId;
  final String categoryName;
  final int stepNumber;
  final bool isActive;
  const StepModel({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.stepNumber,
    required this.isActive,
  });
  factory StepModel.fromJson(Map<String, dynamic> j) => StepModel(
    id: j['id'] as int,
    name: j['name'] as String,
    description: (j['description'] ?? '') as String,
    categoryId: (j['categoryId'] ?? 0) as int,
    categoryName: (j['categoryName'] ?? '') as String,
    stepNumber: (j['stepNumber'] ?? 0) as int,
    isActive: (j['isActive'] ?? true) as bool,
  );
}

class MenuItemShort {
  final int id;
  final String name;
  final int price;
  final int cal;
  final String imageUrl;
  final String categoryName;
  final String description;
  const MenuItemShort({
    required this.id,
    required this.name,
    required this.price,
    required this.cal,
    required this.imageUrl,
    required this.categoryName,
    required this.description,
  });
}

class BuildDishWizardPage extends StatefulWidget {
  final int?
  editingDishId; // if present, update existing dish instead of creating
  final Map<int, Map<int, int>>?
  initialSelections; // stepId -> {menuItemId: qty}
  final String? initialNote;
  const BuildDishWizardPage({
    super.key,
    this.editingDishId,
    this.initialSelections,
    this.initialNote,
  });

  @override
  State<BuildDishWizardPage> createState() => _BuildDishWizardPageState();
}

class _BuildDishWizardPageState extends State<BuildDishWizardPage> {
  late Future<void> _future;
  List<StepModel> _steps = const [];
  List<MenuItemShort> _items = const [];
  final Map<int, MenuItemShort> _catalog = <int, MenuItemShort>{};
  int _index = 0;
  bool _loadingItems = false;
  int _itemsPage = 1;
  bool _itemsHasMore = true;
  final ScrollController _itemsCtrl = ScrollController();
  // Map from stepId to map of itemId -> quantity (multi-select with qty)
  final Map<int, Map<int, int>> _selectedQtys = {};
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
    _itemsCtrl.addListener(_onItemsScroll);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _itemsCtrl.removeListener(_onItemsScroll);
    _itemsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final steps = await _fetchSteps();
    setState(() {
      _steps = steps..sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
      _items = const [];
      _index = 0;
      _itemsPage = 1;
      _itemsHasMore = true;
      _catalog.clear();
      if (widget.initialSelections != null) {
        _selectedQtys
          ..clear()
          ..addAll({
            for (final e in widget.initialSelections!.entries)
              e.key: Map<int, int>.from(e.value),
          });
      }
      if (widget.initialNote != null) {
        _noteController.text = widget.initialNote!;
      }
    });
    try {
      await _loadItemsForCurrentStep(reset: true);
    } catch (_) {
      // keep steps visible even if items fail to load
    }
  }

  Future<List<StepModel>> _fetchSteps() async {
    final headers = await AuthService().authHeaders();
    if (!(headers['Authorization']?.startsWith('Bearer ') ?? false)) {
      throw Exception('Missing token for steps');
    }
    final uri = Uri.https('chickenkitchen.milize-lena.space', '/api/steps', {
      'size': '0',
      'pageNumber': '0',
    });
    try {
      // Log request (masked headers)
      try {
        debugPrint('FETCH STEPS -> GET $uri');
        debugPrint('Headers(safe): ${jsonEncode(_maskHeaders(headers))}');
      } catch (_) {}

      final resp = await http.get(uri, headers: headers);
      if (await HttpGuard.handleUnauthorized(context, resp)) {
        return [];
      }
      try {
        debugPrint('FETCH STEPS <- HTTP ${resp.statusCode}');
        final body = resp.body;
        // Avoid flooding logs: cap to 2000 chars
        final preview = body.length > 2000
            ? '${body.substring(0, 2000)}…'
            : body;
        debugPrint('Response body: $preview');
      } catch (_) {}
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (map['data'] as List).cast<Map<String, dynamic>>();
      return list.map(StepModel.fromJson).where((s) => s.isActive).toList();
    } catch (e) {
      debugPrint('FETCH STEPS !! error: $e');
      rethrow;
    }
  }

  Map<String, String> _maskHeaders(Map<String, String> headers) {
    final m = Map<String, String>.from(headers);
    final auth = m['Authorization'];
    if (auth != null) {
      final parts = auth.split(' ');
      if (parts.length == 2) {
        m['Authorization'] = '${parts[0]} ***';
      } else {
        m['Authorization'] = '***';
      }
    }
    return m;
  }

  Future<void> _loadItemsForCurrentStep({bool reset = false, int? page}) async {
    if (_steps.isEmpty) return;
    final step = _steps[_index];
    final headers = await AuthService().authHeaders();
    if (!(headers['Authorization']?.startsWith('Bearer ') ?? false)) {
      throw Exception('Missing token for menu items');
    }
    if (reset) {
      _itemsPage = 1;
      _itemsHasMore = true;
      if (mounted) setState(() => _items = const []);
    }
    final currentPage = page ?? _itemsPage;
    final uri = Uri.https(
      'chickenkitchen.milize-lena.space',
      '/api/menu-items/search',
      {
        'categoryId': step.categoryId.toString(),
        'size': '10',
        'pageNumber': currentPage.toString(),
        'sortBy': 'name',
        'direction': 'desc',
      },
    );
    try {
      if (mounted) setState(() => _loadingItems = true);
      debugPrint('FETCH ITEMS -> GET $uri');
      final resp = await http.get(uri, headers: headers);
      if (await HttpGuard.handleUnauthorized(context, resp)) {
        return;
      }
      debugPrint('FETCH ITEMS <- HTTP ${resp.statusCode}');
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = (map['data'] as Map<String, dynamic>);
      final list = (data['items'] as List).cast<Map<String, dynamic>>();
      final items = list
          .map(
            (it) => MenuItemShort(
              id: it['id'] as int,
              name: it['name'] as String,
              price: (it['price'] ?? 0) as int,
              cal: (it['cal'] ?? 0) as int,
              imageUrl: (it['imageUrl'] ?? '') as String,
              categoryName: it['categoryName'] as String? ?? '',
              description: (it['description'] ?? '') as String,
            ),
          )
          .toList();
      final total = (data['total'] as int?) ?? -1;
      if (mounted) {
        setState(() {
          if (currentPage == 1) {
            _items = items;
          } else {
            _items = List.of(_items)..addAll(items);
          }
          for (final it in items) {
            _catalog[it.id] = it;
          }
          _itemsPage = currentPage;
          _itemsHasMore = total == -1 ? items.length == 10 : _items.length < total;
        });
      }
    } catch (e) {
      debugPrint('FETCH ITEMS !! error: $e');
      rethrow;
    } finally {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  void _onItemsScroll() {
    if (!_itemsHasMore || _loadingItems) return;
    if (!_itemsCtrl.hasClients) return;
    final pos = _itemsCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      _loadItemsForCurrentStep(page: _itemsPage + 1);
    }
  }

  // --- UI helpers to match list styling ---
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

  MenuItemShort? _findItemById(int id) {
    final cached = _catalog[id];
    if (cached != null) return cached;
    for (final it in _items) {
      if (it.id == id) return it;
    }
    return null;
  }

  int _calcTotal() {
    int sum = 0;
    _selectedQtys.forEach((_, map) {
      map.forEach((id, qty) {
        if (qty > 0) {
          final it = _findItemById(id);
          if (it != null) sum += it.price * qty;
        }
      });
    });
    return sum;
  }

  int _calcCalories() {
    int sum = 0;
    _selectedQtys.forEach((_, map) {
      map.forEach((id, qty) {
        if (qty > 0) {
          final it = _findItemById(id);
          if (it != null) sum += it.cal * qty;
        }
      });
    });
    return sum;
  }

  Future<void> _submitOrder() async {
    if (_submitting) return;
    final selections = <Map<String, dynamic>>[];
    for (final s in _steps) {
      final map = _selectedQtys[s.id];
      if (map == null || map.isEmpty) continue;
      final items = <Map<String, dynamic>>[];
      map.forEach((menuItemId, qty) {
        if (qty > 0) items.add({'menuItemId': menuItemId, 'quantity': qty});
      });
      if (items.isNotEmpty) {
        selections.add({'stepId': s.id, 'items': items});
      }
    }
    if (selections.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hãy chọn ít nhất 1 món.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final storeId = await StoreService.getSelectedStoreId() ?? 1;
      final headers = await AuthService().authHeaders();
      if (!(headers['Authorization']?.startsWith('Bearer ') ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn cần đăng nhập để đặt món.')),
        );
        setState(() => _submitting = false);
        return;
      }
      // Build endpoint and payload per mode (create vs update)
      final bool isCreate = widget.editingDishId == null;
      final Uri uri = isCreate
          ? Uri.parse(
              'https://chickenkitchen.milize-lena.space/api/orders/current/dishes/custom',
            )
          : Uri.parse(
              'https://chickenkitchen.milize-lena.space/api/orders/dishes/${widget.editingDishId}?storeId=$storeId',
            );
      // For update (editing), server expects body with note + selections only (storeId moved to query)
      final Map<String, dynamic> payload = {
        'note': _noteController.text.trim(),
        'selections': selections,
        if (isCreate) 'storeId': storeId,
        if (isCreate) 'isCustom': true,
      };
      final commonHeaders = {
        ...headers,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final resp = isCreate
          ? await http.post(
              uri,
              headers: commonHeaders,
              body: jsonEncode(payload),
            )
          : await http.put(
              uri,
              headers: commonHeaders,
              body: jsonEncode(payload),
            );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.editingDishId == null
                  ? 'Đã thêm món vào đơn hiện tại.'
                  : 'Đã cập nhật món trong đơn.',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gửi thất bại: HTTP ${resp.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFB71C1C);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Build Your Dish'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: FutureBuilder<void>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: primary));
          }
          if (_steps.isEmpty) {
            return const Center(child: Text(' thì '));
          }
          final s = _steps[_index];
          final list = _items;
          final selectedMap = _selectedQtys[s.id] ?? const <int, int>{};
          return Column(
            children: [
              // Step indicator
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    for (int i = 0; i < _steps.length; i++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i <= _index ? primary : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ListTile(
                title: Text(
                  s.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(s.description),
                trailing: selectedMap.isEmpty
                    ? const SizedBox.shrink()
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final entry in selectedMap.entries)
                                Builder(
                                  builder: (_) {
                                    final id = entry.key;
                                    final qty = entry.value;
                                    final it = _findItemById(id);
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Chip(
                                        label: Text(
                                          '${it?.name ?? '#$id'} x$qty',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
              const Divider(height: 1),
              Expanded(
                child: list.isEmpty && _loadingItems
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        controller: _itemsCtrl,
                        itemCount: list.length + ((_loadingItems && _itemsHasMore) ? 1 : 0),
                        padding: const EdgeInsets.all(16),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          if (i >= list.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final it = list[i];
                          final qty = selectedMap[it.id] ?? 0;
                          final isSelected = qty > 0;
                          return InkWell(
                            onTap: () async {
                              final initial = selectedMap[it.id] ?? 1;
                              final result = await Navigator.of(context).push<int>(
                                MaterialPageRoute(
                                  builder: (_) => MenuItemDetailPage(
                                    id: it.id,
                                    selectionMode: true,
                                    initialQty: initial,
                                    onAdd:
                                        (
                                          q,
                                        ) {}, // placeholder, not used because we await result
                                  ),
                                ),
                              );
                              if (result != null) {
                                setState(() {
                                  final map = _selectedQtys.putIfAbsent(
                                    s.id,
                                    () => <int, int>{},
                                  );
                                  if (result <= 0) {
                                    map.remove(it.id);
                                    if (map.isEmpty) _selectedQtys.remove(s.id);
                                  } else {
                                    map[it.id] = result;
                                  }
                                });
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? primary : Colors.black12,
                                ),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
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
                                              _image(
                                                it.imageUrl,
                                                it.categoryName,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          right: 6,
                                          bottom: 6,
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: primary,
                                                width: 2,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '$qty',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Positioned(
                                          right: 6,
                                          bottom: 6,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                final map = _selectedQtys.putIfAbsent(
                                                  s.id,
                                                  () => <int, int>{},
                                                );
                                                map[it.id] = 1;
                                              });
                                            },
                                            child: Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: primary,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(.1),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.add,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Category tag
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _categoryTint(
                                              it.categoryName,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
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
                            ),
                          );
                        },
                      ),
              ),
              // Note bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: 'Ghi chú cho bếp (ví dụ: Không hành)',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
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
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Summary row on its own line to avoid overflow
                      Center(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                              child: Container(
                                key: ValueKey<int>(_calcTotal()),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: primary),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.payments_outlined, color: primary, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatVnd(_calcTotal()),
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: primary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: primary.withOpacity(.18)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_calcCalories()} kcal',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: primary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Buttons row, compact fixed widths
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            width: 92,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: const Text('Back'),
                              onPressed: (_index > 0 && !_submitting)
                                  ? () async {
                                      setState(() {
                                        _index--;
                                        _items = const [];
                                        _itemsPage = 1;
                                        _itemsHasMore = true;
                                      });
                                      await _loadItemsForCurrentStep(reset: true);
                                    }
                                  : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primary,
                                side: const BorderSide(color: primary),
                                minimumSize: const Size(92, 38),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 104,
                            child: ElevatedButton.icon(
                              icon: _submitting
                                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.arrow_forward, size: 16),
                              label: Text(_index < _steps.length - 1 ? 'Next' : 'Submit'),
                              onPressed: _submitting
                                  ? null
                                  : () async {
                                      if (_index < _steps.length - 1) {
                                        setState(() {
                                          _index++;
                                          _items = const [];
                                          _itemsPage = 1;
                                          _itemsHasMore = true;
                                        });
                                        await _loadItemsForCurrentStep(reset: true);
                                      } else {
                                        await _submitOrder();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(104, 38),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
