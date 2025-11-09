import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/features/menu/presentation/DishDetailPage.dart';
import 'package:mobiletest/features/auth/data/auth_service.dart';
import 'package:mobiletest/core/services/http_guard.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // Keyword (manual trigger)
  final _keywordCtrl = TextEditingController();

  // Chip-based filters (auto trigger on change)
  int _priceIndex = 0; // 0-none, 1-<=50k, 2-50-100k, 3->=100k
  int _calIndex = 0; // 0-none, 1-<=700, 2-700-900, 3->=900
  String? _menuItemIds; // optional, set via dialog

  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;
  bool _hasMore = false;
  int _page = 1;
  static const int _size = 10;

  static const String _fallbackImage =
      'https://images.unsplash.com/photo-1543353071-10c8ba85a904?auto=format&fit=crop&q=80&w=1200';

  @override
  void initState() {
    super.initState();
    // Auto load first page with defaults (only page & size)
    // Delay to ensure build context ready
    Future.microtask(() => _search(reset: true));
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
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

  Map<String, String> _buildQuery({required int page}) {
    final Map<String, String> q = {'size': '$_size', 'pageNumber': '$page'};
    final kw = _keywordCtrl.text.trim();
    if (kw.isNotEmpty) q['keyword'] = kw;

    // Apply chip filters
    // Price
    int? minPrice;
    int? maxPrice;
    switch (_priceIndex) {
      case 1:
        maxPrice = 50000;
        break;
      case 2:
        minPrice = 50000;
        maxPrice = 100000;
        break;
      case 3:
        minPrice = 100000;
        break;
    }
    if (minPrice != null) q['minPrice'] = '$minPrice';
    if (maxPrice != null) q['maxPrice'] = '$maxPrice';

    // Calories
    int? minCal;
    int? maxCal;
    switch (_calIndex) {
      case 1:
        maxCal = 700;
        break;
      case 2:
        minCal = 700;
        maxCal = 900;
        break;
      case 3:
        minCal = 900;
        break;
    }
    if (minCal != null) q['minCal'] = '$minCal';
    if (maxCal != null) q['maxCal'] = '$maxCal';

    if (_menuItemIds != null && _menuItemIds!.trim().isNotEmpty) {
      q['menuItemIds'] = _menuItemIds!.trim();
    }
    return q;
  }

  Future<void> _search({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _page = 1;
      }
    });
    try {
      final headers = await AuthService().authHeaders();
      if (!(headers['Authorization']?.startsWith('Bearer ') ?? false)) {
        throw Exception('Bạn cần đăng nhập');
      }
      final q = _buildQuery(page: _page);
      final uri = Uri.https(
        'chickenkitchen.milize-lena.space',
        '/api/dishes/search',
        q,
      );
      final resp = await http.get(uri, headers: headers);
      if (await HttpGuard.handleUnauthorized(context, resp)) return;
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = (json['data'] as Map<String, dynamic>);
      final items = (data['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final total = (data['total'] as int?) ?? items.length;
      setState(() {
        _items.addAll(items);
        _page += 1;
        _hasMore = _items.length < total;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFB71C1C);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
        title: Container(
          height: 40,
          constraints: const BoxConstraints(maxWidth: 720),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.black54, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _keywordCtrl,
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Search keyword...',
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(reset: true),
                ),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: kToolbarHeight,
            child: IconButton(
              onPressed: _loading ? null : () => _search(reset: true),
              icon: const Icon(Icons.arrow_forward),
              splashRadius: 20,
            ),
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification || n is ScrollUpdateNotification) {
            final metrics = n.metrics;
            if (_hasMore &&
                !_loading &&
                metrics.pixels >= metrics.maxScrollExtent - 120) {
              _search(reset: false);
            }
          }
          return false;
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Horizontal quick filters bar
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  children: [
                    _buildChoiceChip(
                      label: '≤50k',
                      selected: _priceIndex == 1,
                      onTap: () {
                        setState(() => _priceIndex = _priceIndex == 1 ? 0 : 1);
                        _search(reset: true);
                      },
                    ),
                    _buildChoiceChip(
                      label: '50k–100k',
                      selected: _priceIndex == 2,
                      onTap: () {
                        setState(() => _priceIndex = _priceIndex == 2 ? 0 : 2);
                        _search(reset: true);
                      },
                    ),
                    _buildChoiceChip(
                      label: '≥100k',
                      selected: _priceIndex == 3,
                      onTap: () {
                        setState(() => _priceIndex = _priceIndex == 3 ? 0 : 3);
                        _search(reset: true);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildChoiceChip(
                      label: '≤700 cal',
                      selected: _calIndex == 1,
                      onTap: () {
                        setState(() => _calIndex = _calIndex == 1 ? 0 : 1);
                        _search(reset: true);
                      },
                    ),
                    _buildChoiceChip(
                      label: '700–900',
                      selected: _calIndex == 2,
                      onTap: () {
                        setState(() => _calIndex = _calIndex == 2 ? 0 : 2);
                        _search(reset: true);
                      },
                    ),
                    _buildChoiceChip(
                      label: '≥900 cal',
                      selected: _calIndex == 3,
                      onTap: () {
                        setState(() => _calIndex = _calIndex == 3 ? 0 : 3);
                        _search(reset: true);
                      },
                    ),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (context) {
                        const primary = Color(0xFFB71C1C);
                        final label =
                            _menuItemIds == null || _menuItemIds!.isEmpty
                            ? 'Menu IDs'
                            : 'IDs: ${_menuItemIds!}';
                        return ActionChip(
                          label: Text(
                            label,
                            style: const TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _editMenuItemIds,
                          avatar: const Icon(
                            Icons.tune,
                            size: 16,
                            color: primary,
                          ),
                          backgroundColor: Colors.white,
                          shape: const StadiumBorder(
                            side: BorderSide(color: primary, width: 1),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
                  ],
                ),
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // Results
              if (_items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final it = _items[i];
                          return InkWell(
                            onTap: () {
                              final id = it['id'] as int;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DishDetailPage(dishId: id),
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
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 92,
                                      height: 92,
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
                                              fit: BoxFit.cover,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (it['name'] as String?) ??
                                              'Dish #${it['id']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          it['note'] as String? ?? '',
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
                                              _formatVnd(
                                                (it['price'] as int?) ?? 0,
                                              ),
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
                                              '${it['cal'] ?? 0} cal',
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
                      const SizedBox(height: 12),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              if (_items.isEmpty && !_loading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: 0.9,
                            child: Image.asset(
                              'assets/images/OnboardingSliceShow_03.png',
                              height: 140,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No dishes found',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const primary = Color(0xFFB71C1C);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        selected: selected,
        backgroundColor: Colors.white,
        selectedColor: primary,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? Colors.white : primary, width: 1),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Future<void> _editMenuItemIds() async {
    final controller = TextEditingController(text: _menuItemIds ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Menu Item IDs'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'e.g. 1 or 1,2,3'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      setState(() => _menuItemIds = result);
      _search(reset: true);
    }
  }
}
