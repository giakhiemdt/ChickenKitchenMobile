import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/features/orders/presentation/OrderProgressPage.dart';
import 'package:mobiletest/shared/widgets/app_bottom_nav.dart';
import 'package:mobiletest/features/home/presentation/HomePage.dart';
import 'package:mobiletest/features/restaurants/presentation/RestaurantsListPage.dart';
import 'package:mobiletest/features/profile/presentation/ProfilePage.dart';
import 'package:mobiletest/features/auth/data/auth_service.dart';
import 'package:mobiletest/features/store/data/store_service.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  List<String> _statuses = const [];
  String _keyword = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final headers = await AuthService().authHeaders();
      if (headers.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Missing token';
        });
        return;
      }
      final storeId = await StoreService.getSelectedStoreId() ?? 1;

      final historyUri = Uri.parse(
          'https://chickenkitchen.milize-lena.space/api/orders/history?storeId=$storeId');
      final statusesUri =
          Uri.parse('https://chickenkitchen.milize-lena.space/api/orders/statuses');

      final respHistory = await http.get(historyUri, headers: headers);
      final respStatuses = await http.get(statusesUri, headers: const {
        'Accept': 'application/json',
      });

      if (respHistory.statusCode != 200) {
        throw Exception('HTTP ${respHistory.statusCode} for history');
      }
      if (respStatuses.statusCode != 200) {
        // Not fatal; continue without external statuses
      }

      final historyJson = jsonDecode(respHistory.body) as Map<String, dynamic>;
      final ordersList = (historyJson['data'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      List<String> statuses = _statuses;
      try {
        final statusesJson = jsonDecode(respStatuses.body) as Map<String, dynamic>;
        statuses = (statusesJson['data'] as List<dynamic>? ?? [])
            .map((e) => (e as String).toUpperCase())
            .toList();
      } catch (_) {}

      setState(() {
        _orders = ordersList;
        _statuses = statuses;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFB71C1C);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Container(
                height: 40,
                margin: const EdgeInsets.only(right: 8),
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
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Search orders (id, status)…',
                        ),
                        onChanged: (v) => setState(() => _keyword = v.trim().toLowerCase()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Failed to load: $_error'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetch,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _orders.isEmpty
                  ? const Center(child: Text('No order history yet'))
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredOrders().length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final it = _filteredOrders()[i];
                          final orderId = it['orderId'] ?? it['id'] ?? 0;
                          final status = (it['status'] as String? ?? 'CONFIRMED').toUpperCase();
                          final total = (it['totalPrice'] ?? it['total'] ?? 0) as int;
                          final createdAt = (it['createdAt'] as String?) ?? '';
                          final pickupTime = (it['pickupTime'] as String?) ?? '';

                          final steps = _stepsForStatus(status);
                          final cancelled = status == 'CANCELLED' || status == 'FAILED';

                          return InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => OrderProgressPage(orderId: orderId as int),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black12),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.receipt_long, color: Colors.black54),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Order #$orderId',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Status: $status',
                                              style: TextStyle(
                                                color: cancelled
                                                    ? Colors.red
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _formatVnd(total),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, size: 14, color: Colors.black45),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _formatDate(createdAt),
                                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                                        ),
                                      ),
                                      if (pickupTime.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.event_available,
                                            size: 14, color: Colors.black45),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDate(pickupTime),
                                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                                        ),
                                      ]
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _MiniProgress(steps: steps, primary: primary, cancelled: cancelled),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  List<Map<String, dynamic>> _filteredOrders() {
    if (_keyword.isEmpty) return _orders;
    return _orders.where((o) {
      final id = (o['orderId'] ?? o['id'] ?? '').toString().toLowerCase();
      final status = (o['status'] as String? ?? '').toLowerCase();
      return id.contains(_keyword) || status.contains(_keyword);
    }).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Widget get bottomNavigationBar => AppBottomNav(
        currentIndex: 3,
        onTap: (i) {
          switch (i) {
            case 0:
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
              break;
            case 2:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RestaurantsListPage()),
              );
              break;
            case 3:
              break; // already here
            case 4:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
              break;
            default:
              // no-op
              break;
          }
        },
      );

  List<_StepVM> _stepsForStatus(String status) {
    final base = [
      _StepVM('Confirmed'),
      _StepVM('Processing'),
      _StepVM('Ready'),
      _StepVM('Completed'),
    ];

    int idx;
    final s = status.toUpperCase();
    switch (s) {
      case 'NEW':
      case 'CONFIRMED':
        idx = 0;
        break;
      case 'PROCESSING':
      case 'PREPARING':
        idx = 1;
        break;
      case 'READY':
        idx = 2;
        break;
      case 'COMPLETED':
      case 'DELIVERED':
        idx = 3;
        break;
      case 'FAILED':
      case 'CANCELLED':
        idx = -1; // special case
        break;
      default:
        idx = 0;
    }

    if (idx >= 0) {
      for (int i = 0; i < base.length; i++) {
        base[i] = base[i].copyWith(done: i <= idx);
      }
    }
    return base;
  }

  String _formatVnd(int vnd) {
    final buf = StringBuffer();
    final s = vnd.abs().toString();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      buf.write(s[i]);
      if (idx > 1 && idx % 3 == 1) buf.write(',');
    }
    final sign = vnd < 0 ? '-' : '';
    return '$sign${buf.toString()} ₫';
  }

  String _formatDate(String iso) {
    // Keep it simple; show yyyy-MM-dd HH:mm
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(iso)?.toLocal();
      if (dt == null) return iso;
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }
}

class _MiniProgress extends StatelessWidget {
  final List<_StepVM> steps;
  final Color primary;
  final bool cancelled;
  const _MiniProgress({required this.steps, required this.primary, required this.cancelled});

  @override
  Widget build(BuildContext context) {
    final activeColor = cancelled ? Colors.red : primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: steps[i].done ? activeColor : Colors.black12,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(i == 0 ? 6 : 0),
                      bottomLeft: Radius.circular(i == 0 ? 6 : 0),
                      topRight: Radius.circular(i == steps.length - 1 ? 6 : 0),
                      bottomRight: Radius.circular(i == steps.length - 1 ? 6 : 0),
                    ),
                  ),
                ),
              ),
              if (i < steps.length - 1) const SizedBox(width: 6),
            ]
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: steps
              .map((s) => Expanded(
                    child: Text(
                      s.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: s.done ? activeColor : Colors.black54,
                        fontWeight: s.done ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ))
              .toList(),
        )
      ],
    );
  }
}

class _StepVM {
  final String title;
  final bool done;
  _StepVM(this.title, {this.done = false});

  _StepVM copyWith({bool? done}) => _StepVM(title, done: done ?? this.done);
}
