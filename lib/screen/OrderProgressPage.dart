import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/services/auth_service.dart';
import 'package:mobiletest/services/store_service.dart';
import 'package:mobiletest/screen/HomePage.dart';
import 'package:mobiletest/screen/OrderHistoryPage.dart';
import 'package:mobiletest/services/cart_events.dart';

class OrderProgressPage extends StatefulWidget {
  final int orderId;
  const OrderProgressPage({super.key, required this.orderId});

  @override
  State<OrderProgressPage> createState() => _OrderProgressPageState();
}

class _OrderProgressPageState extends State<OrderProgressPage> {
  Map<String, dynamic>? _order; // generic order data
  Map<String, dynamic>? _orderDetails; // /orders/{id}
  Map<String, dynamic>? _tracking; // /orders/{id}/tracking
  Map<String, dynamic>? _store; // store info
  Timer? _timer;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _lastOrder;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final headers = await AuthService().authHeaders();
      if (headers.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Missing token';
        });
        return;
      }
      // 1) Tracking info
      final trackingUri = Uri.parse(
        'https://chickenkitchen.milize-lena.space/api/orders/${widget.orderId}/tracking',
      );
      final trackingResp = await http.get(trackingUri, headers: headers);
      if (trackingResp.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'HTTP ${trackingResp.statusCode}';
        });
        return;
      }
      final trackingMap = jsonDecode(trackingResp.body) as Map<String, dynamic>;
      final trackingData = trackingMap['data'] as Map<String, dynamic>?;

      // 2) Order details (storeId, totals, times)
      Map<String, dynamic>? orderData;
      try {
        final orderUri = Uri.parse(
          'https://chickenkitchen.milize-lena.space/api/orders/${widget.orderId}',
        );
        final orderResp = await http.get(orderUri, headers: headers);
        if (orderResp.statusCode == 200) {
          final orderMap = jsonDecode(orderResp.body) as Map<String, dynamic>;
          orderData = orderMap['data'] as Map<String, dynamic>?;
        }
      } catch (_) {}

      // 3) Store details (optional)
      Map<String, dynamic>? storeData;
      final storeId =
          (orderData?['storeId'] as int?) ?? (trackingData?['storeId'] as int?);
      if (storeId != null) {
        try {
          final sUri = Uri.parse(
            'https://chickenkitchen.milize-lena.space/api/store/$storeId',
          );
          final sResp = await http.get(
            sUri,
            headers: const {'Accept': 'application/json'},
          );
          if (sResp.statusCode == 200) {
            final sMap = jsonDecode(sResp.body) as Map<String, dynamic>;
            final s = sMap['data'];
            if (s is Map<String, dynamic>) {
              storeData = s;
            } else if (s is List &&
                s.isNotEmpty &&
                s.first is Map<String, dynamic>) {
              storeData = s.first as Map<String, dynamic>;
            }
          }
        } catch (_) {}
      }
      if (storeData == null) {
        final sel = await StoreService.loadSelectedStore();
        if (sel != null) {
          storeData = {'id': sel.id, 'name': sel.name, 'address': sel.address};
        }
      }

      final baseForChange = orderData ?? trackingData;
      final changed = _hasOrderChanged(_lastOrder, baseForChange);
      setState(() {
        _tracking = trackingData;
        _orderDetails = orderData;
        _store = storeData;
        _order = baseForChange;
        _lastOrder = baseForChange == null
            ? null
            : Map<String, dynamic>.from(baseForChange);
        _loading = false;
        _error = null;
      });
      if (changed) CartEvents.notifyChanged();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF86C144);
    final status =
        (_tracking?['status'] as String?)?.toUpperCase() ??
        (_order?['status'] as String?)?.toUpperCase() ??
        'CONFIRMED';
    final steps = _stepsForStatus(status);
    final progress = (_tracking?['progress'] as num?)?.toDouble();
    final total =
        (_orderDetails?['totalPrice'] ??
                _order?['totalPrice'] ??
                _order?['total'] ??
                0)
            as int;
    final createdAt =
        (_orderDetails?['createdAt'] ?? _order?['createdAt'] ?? '') as String;
    final pickupTime =
        (_orderDetails?['pickupTime'] ?? _order?['pickupTime'] ?? '') as String;
    final storeName = (_store?['name'] ?? '') as String;
    final storeAddress = (_store?['address'] ?? '') as String;
    final dishes =
        (_tracking?['dishes'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final totalCal = dishes.fold<int>(
      0,
      (sum, d) => sum + ((d['cal'] ?? 0) as int),
    );
    final totalFromDishes = dishes.fold<int>(
      0,
      (sum, d) => sum + ((d['price'] ?? 0) as int),
    );
    final displayTotal = (total != 0) ? total : totalFromDishes;

    return WillPopScope(
      onWillPop: () async {
        _goBackToHistory();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Order Progress'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBackToHistory,
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text('Failed: $_error'))
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long, color: Colors.black54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order #${widget.orderId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Status: $status',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                if (progress != null) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: (progress.clamp(0, 100)) / 100.0,
                                      minHeight: 6,
                                      backgroundColor: Colors.black12,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${progress.toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (storeName.isNotEmpty ||
                        storeAddress.isNotEmpty ||
                        createdAt.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (storeName.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.storefront,
                                    size: 16,
                                    color: Colors.black45,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      storeName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (storeAddress.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 22.0,
                                    top: 2,
                                  ),
                                  child: Text(
                                    storeAddress,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: Colors.black45,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    createdAt.isEmpty
                                        ? 'Created: —'
                                        : 'Created: ${_formatDate(createdAt)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (pickupTime.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.event_available,
                                    size: 16,
                                    color: Colors.black45,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Pickup: ${_formatDate(pickupTime)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.payments,
                                  size: 16,
                                  color: Colors.black45,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Total: ${_formatVnd(displayTotal)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (totalCal > 0) ...[
                                  const SizedBox(width: 16),
                                  const Icon(
                                    Icons.local_fire_department,
                                    size: 16,
                                    color: Colors.black45,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Calories: $totalCal kcal',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView(
                        children: [
                          ...List.generate(steps.length, (i) {
                            final s = steps[i];
                            final done = s.done;
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: i < steps.length - 1 ? 12 : 0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(
                                      right: 12,
                                      top: 2,
                                    ),
                                    width: 20,
                                    child: Column(
                                      children: [
                                        Icon(
                                          done
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: done
                                              ? primary
                                              : Colors.black26,
                                          size: 20,
                                        ),
                                        if (i < steps.length - 1)
                                          Container(
                                            width: 2,
                                            height: 36,
                                            color: done
                                                ? primary.withOpacity(.4)
                                                : Colors.black12,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: done
                                              ? primary.withOpacity(.4)
                                              : Colors.black12,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            s.subtitle,
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (dishes.isNotEmpty) const SizedBox(height: 20),
                          if (dishes.isNotEmpty)
                            const Text(
                              'Dishes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (dishes.isNotEmpty) const SizedBox(height: 10),
                          ...dishes.map((d) {
                            final dishId = (d['dishId'] ?? 0) as int;
                            final dishPrice = (d['price'] ?? 0) as int;
                            final dishCal = (d['cal'] ?? 0) as int;
                            final updatedAt = (d['updatedAt'] ?? '') as String;
                            final note = (d['note'] ?? '') as String;
                            final stepsArr =
                                (d['steps'] as List<dynamic>?)
                                    ?.cast<Map<String, dynamic>>() ??
                                const <Map<String, dynamic>>[];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
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
                                      const Icon(
                                        Icons.rice_bowl,
                                        color: Colors.black54,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Dish #$dishId',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatVnd(dishPrice),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department,
                                        size: 14,
                                        color: Colors.black45,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$dishCal kcal',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      if (updatedAt.isNotEmpty) ...[
                                        const SizedBox(width: 12),
                                        const Icon(
                                          Icons.schedule,
                                          size: 14,
                                          color: Colors.black45,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDate(updatedAt),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (note.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Note: $note',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  ...stepsArr.map((s) {
                                    final name =
                                        (s['stepName'] ?? 'Step') as String;
                                    final items =
                                        (s['items'] as List<dynamic>?)
                                            ?.cast<Map<String, dynamic>>() ??
                                        const <Map<String, dynamic>>[];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          ...items.map((it) {
                                            final itemName =
                                                (it['menuItemName'] ?? 'Item')
                                                    as String;
                                            final qty =
                                                (it['quantity'] ?? 0) as int;
                                            final price =
                                                (it['price'] ?? 0) as int;
                                            final cal = (it['cal'] ?? 0) as int;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6.0,
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'x$qty $itemName',
                                                    ),
                                                  ),
                                                  Text(
                                                    '${_formatVnd(price)}  •  $cal kcal',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  List<_StepVM> _stepsForStatus(String status) {
    // Generic Grab-like steps
    final all = [
      _StepVM('Order confirmed', 'We received your order', true),
      _StepVM('Preparing', 'Kitchen is preparing your food', false),
      _StepVM('Ready for pickup', 'Your food is ready', false),
      _StepVM('On the way', 'Driver is on the way', false),
      _StepVM('Delivered', 'Enjoy your meal!', false),
    ];

    int idx;
    switch (status) {
      case 'NEW':
      case 'CONFIRMED':
        idx = 0;
        break;
      case 'PREPARING':
      case 'PROCESSING':
        idx = 1;
        break;
      case 'READY':
        idx = 2;
        break;
      case 'DELIVERING':
        idx = 3;
        break;
      case 'COMPLETED':
      case 'DELIVERED':
        idx = 4;
        break;
      default:
        idx = 0;
    }
    for (int i = 0; i < all.length; i++) {
      all[i] = all[i].copyWith(done: i <= idx);
    }
    return all;
  }

  String _formatVnd(int vnd) {
    final s = vnd.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      buf.write(s[i]);
      if (idx > 1 && idx % 3 == 1) buf.write(',');
    }
    final sign = vnd < 0 ? '-' : '';
    return '$sign${buf.toString()} ₫';
  }

  String _formatDate(String iso) {
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

  bool _hasOrderChanged(
    Map<String, dynamic>? oldOrder,
    Map<String, dynamic>? newOrder,
  ) {
    if (oldOrder == null && newOrder == null) return false;
    if (oldOrder == null || newOrder == null) return true;
    final oldStatus = (oldOrder['status'] as String?) ?? '';
    final newStatus = (newOrder['status'] as String?) ?? '';
    if (oldStatus != newStatus) return true;
    final oldDishes = (oldOrder['dishes'] as List?)?.length ?? -1;
    final newDishes = (newOrder['dishes'] as List?)?.length ?? -1;
    if (oldDishes != newDishes) return true;
    final oldTotal =
        oldOrder['total'] ?? oldOrder['totalPrice'] ?? oldOrder['price'];
    final newTotal =
        newOrder['total'] ?? newOrder['totalPrice'] ?? newOrder['price'];
    if (oldTotal != newTotal) return true;
    return false;
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  void _goBackToHistory() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
      (_) => false,
    );
  }
}

class _StepVM {
  final String title;
  final String subtitle;
  final bool done;
  _StepVM(this.title, this.subtitle, this.done);

  _StepVM copyWith({bool? done}) => _StepVM(title, subtitle, done ?? this.done);
}
