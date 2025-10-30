import 'dart:convert';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/services/auth_service.dart';
import 'package:mobiletest/services/store_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobiletest/services/deep_link_service.dart';
import 'package:mobiletest/screen/OrderProgressPage.dart';

class ConfirmOrderPage extends StatefulWidget {
  const ConfirmOrderPage({super.key});

  @override
  State<ConfirmOrderPage> createState() => _ConfirmOrderPageState();
}

class _ConfirmOrderPageState extends State<ConfirmOrderPage> {
  late Future<_ConfirmData> _future;
  int? _selectedPaymentId;
  // Promotion selection state
  Map<String, dynamic>? _selectedPromotion;
  List<Map<String, dynamic>>? _promotionsCache;
  final Map<int, bool> _expanded = <int, bool>{};
  bool _confirming = false;
  StreamSubscription<String?>? _linkSub;
  bool _handledInitialLink = false;
  Map<String, dynamic>?
  _currentOrder; // cache current order to avoid extra fetches

  @override
  void initState() {
    super.initState();
    _future = _fetchAll();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    // Handle incoming links while app is in foreground
    _linkSub = DeepLinkService.linkStream().listen((link) {
      if (link == null) return;
      final uri = Uri.tryParse(link);
      if (uri != null) {
        _handleVnpayUri(uri);
      }
    }, onError: (_) {});

    // Handle the case where the app was launched/resumed via a link
    if (_handledInitialLink) return;
    try {
      final initialLink = await DeepLinkService.getInitialLink();
      final initial = initialLink == null ? null : Uri.tryParse(initialLink);
      if (initial != null) {
        _handleVnpayUri(initial);
      }
    } catch (_) {
      // ignore
    } finally {
      _handledInitialLink = true;
    }
  }

  bool _isVnpayResult(Uri uri) {
    return uri.scheme == 'chickenapp' && uri.host == 'vnpay-result';
  }

  Future<void> _handleVnpayUri(Uri uri) async {
    if (!_isVnpayResult(uri)) return;
    // Gather all query parameters from the URI
    final params = Map<String, String>.from(uri.queryParameters);
    _logVnpayRedirect(uri, params);
    if (params.isEmpty) {
      // Sometimes parameters might be encoded in the fragment or path; try parsing manually if needed
      // For now, if empty, just notify and return
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payment result data found')),
      );
      return;
    }
    await _sendVnpayCallback(params);
  }

  Future<void> _sendVnpayCallback(Map<String, String> params) async {
    try {
      final uri = Uri.parse(
        'https://chickenkitchen.milize-lena.space/api/orders/vnpay-callback',
      );
      final headers = await AuthService().authHeaders();
      if (headers.isEmpty || !headers.containsKey('Authorization')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing token for callback')),
        );
        return;
      }
      final body = jsonEncode(params);
      try {
        debugPrint('VNPAY CALLBACK -> POST $uri');
        debugPrint('Headers(safe): ${jsonEncode(_maskHeaders(headers))}');
        debugPrint('Body: $body');
      } catch (_) {}
      final resp = await http.post(uri, headers: headers, body: body);
      if (!mounted) return;
      try {
        debugPrint('VNPAY CALLBACK <- HTTP ${resp.statusCode}');
        debugPrint('Response body: ${resp.body}');
      } catch (_) {}
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('VNPAY callback failed: HTTP ${resp.statusCode}'),
          ),
        );
        return;
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final statusCode = json['statusCode'] as int? ?? resp.statusCode;
      final message = json['message'] as String? ?? 'Callback processed';
      if (statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment successful!')));
        // Refresh current order and navigate to progress screen
        setState(() {
          _future = _fetchAll();
        });
        final orderId = int.tryParse(params['orderId'] ?? '');
        if (orderId != null && mounted) {
          // Navigate to progress page
          // Delay slightly to allow snackbar to display
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderProgressPage(orderId: orderId),
              ),
            );
          });
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Payment failed: $message')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('VNPAY callback error: $e')));
    }
  }

  void _logVnpayRedirect(Uri uri, Map<String, String> params) {
    try {
      debugPrint('--- VNPAY REDIRECT RECEIVED ---');
      debugPrint('Time: ${DateTime.now().toIso8601String()}');
      debugPrint('URI: ${uri.toString()}');
      debugPrint('  scheme=${uri.scheme} host=${uri.host} path=${uri.path}');
      if (params.isEmpty) {
        debugPrint('Query params: <empty>');
      } else {
        debugPrint('Query params (${params.length}):');
        for (final e in params.entries) {
          debugPrint('  ${e.key} = ${e.value}');
        }
      }
      debugPrint('--- END VNPAY REDIRECT ---');
    } catch (_) {}
  }

  Future<_ConfirmData> _fetchAll() async {
    final order = await _fetchOrder();
    final payments = await _fetchPaymentMethods();
    final store = await _fetchStoreInfo();
    _currentOrder = order;
    // pick first active payment as default
    final firstActive = payments.cast<Map<String, dynamic>?>().firstWhere(
      (e) => (e?['isActive'] ?? false) == true,
      orElse: () => null,
    );
    _selectedPaymentId = firstActive?['id'] as int?;
    return _ConfirmData(order: order, payments: payments, store: store);
  }

  Future<Map<String, dynamic>?> _fetchOrder() async {
    final storeId = await StoreService.getSelectedStoreId() ?? 1;
    final headers = await AuthService().authHeaders();
    final uri = Uri.parse(
      'https://chickenkitchen.milize-lena.space/api/orders/current?storeId=$storeId',
    );
    final resp = await http.get(
      uri,
      headers: headers.isEmpty ? {'Accept': 'application/json'} : headers,
    );
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    return map['data'] as Map<String, dynamic>?; // may be null
  }

  Future<List<Map<String, dynamic>>> _fetchPaymentMethods() async {
    final uri = Uri.parse(
      'https://chickenkitchen.milize-lena.space/api/transaction/payment-method',
    );
    final resp = await http.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    final list =
        (map['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    return list;
  }

  Future<Map<String, dynamic>?> _fetchStoreInfo() async {
    try {
      final storeId = await StoreService.getSelectedStoreId() ?? 1;
      final uri = Uri.parse(
        'https://chickenkitchen.milize-lena.space/api/store',
      );
      final resp = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
      if (resp.statusCode != 200) return {'id': storeId};
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final list =
          (map['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];
      return list.firstWhere(
        (e) => (e['id'] ?? -1) == storeId,
        orElse: () => {'id': storeId},
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _openPaymentMethodPicker(
    List<Map<String, dynamic>> payments,
  ) async {
    final list = payments
        .where((e) => (e['isActive'] ?? false) == true)
        .toList(growable: false);
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active payment methods')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Choose payment method',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final pm = list[i];
                      final selected = _selectedPaymentId == pm['id'];
                      return InkWell(
                        onTap: () {
                          setState(() => _selectedPaymentId = pm['id'] as int);
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF86C144)
                                  : Colors.black12,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pm['name'] as String? ?? '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      pm['description'] as String? ?? '-',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF86C144),
                                )
                              else
                                const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPromotions() async {
    if (_promotionsCache != null) return _promotionsCache!;
    final uri = Uri.parse(
      'https://chickenkitchen.milize-lena.space/api/promotion',
    );
    final resp = await http.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    final list =
        (map['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    _promotionsCache = list;
    return list;
  }

  bool _promoValid(Map<String, dynamic> p) {
    final active = (p['isActive'] ?? false) == true;
    if (!active) return false;
    try {
      final now = DateTime.now();
      final start = DateTime.parse(p['startDate'] as String);
      final end = DateTime.parse(p['endDate'] as String);
      return now.isAfter(start) && now.isBefore(end);
    } catch (_) {
      return true; // if parse fails, assume valid to not hide
    }
  }

  Future<void> _openPromotionPicker() async {
    try {
      final list = (await _fetchPromotions())
          .where(_promoValid)
          .toList(growable: false);
      if (!mounted) return;
      // Use cached order to avoid extra network calls when opening the sheet
      final subtotal = _orderTotal(_currentOrder);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          const primary = Color(0xFF86C144);
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Choose a promotion',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = list[i];
                        final selected = _selectedPromotion?['id'] == p['id'];
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (_selectedPromotion?['id'] == p['id']) {
                                // Tapping the selected promotion again -> deselect
                                _selectedPromotion = null;
                              } else {
                                _selectedPromotion = p;
                              }
                            });
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? primary : Colors.black12,
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name'] as String? ?? '-',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        p['description'] as String? ?? '-',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Code: ${p['code'] ?? ''}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Builder(
                                        builder: (_) {
                                          final type =
                                              (p['discountType'] as String?)
                                                  ?.toUpperCase() ??
                                              '';
                                          final value =
                                              (p['discountValue'] ?? 0) as int;
                                          String detail;
                                          if (type == 'PERCENT') {
                                            final est =
                                                ((subtotal * value) / 100)
                                                    .floor();
                                            detail =
                                                'Giảm $value% (~${_formatVnd(est)})';
                                          } else {
                                            detail =
                                                'Giảm trực tiếp ${_formatVnd(value)}';
                                          }
                                          return Text(
                                            detail,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.redAccent,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const Icon(Icons.check_circle, color: primary)
                                else
                                  const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load promotions: $e')));
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

  int _orderTotal(Map<String, dynamic>? order) {
    if (order == null) return 0;
    final dishes =
        (order['dishes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    int sum = 0;
    for (final d in dishes) {
      sum += (d['price'] ?? 0) as int;
    }
    return sum;
  }

  int _discountAmount(int subtotal) {
    final p = _selectedPromotion;
    if (p == null) return 0;
    final type = (p['discountType'] as String?) ?? '';
    final value = (p['discountValue'] ?? 0) as int;
    if (subtotal <= 0 || value <= 0) return 0;
    if (type.toUpperCase() == 'PERCENT') {
      final d = ((subtotal * value) / 100).floor();
      return d.clamp(0, subtotal);
    }
    // AMOUNT or unknown -> treat as fixed amount off
    return value.clamp(0, subtotal);
  }

  int _orderCal(Map<String, dynamic>? order) {
    if (order == null) return 0;
    final dishes =
        (order['dishes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    int sum = 0;
    for (final d in dishes) {
      sum += (d['cal'] ?? 0) as int;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF86C144);
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Order'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: FutureBuilder<_ConfirmData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Failed to load: ${snap.error}'),
              ),
            );
          }
          final data = snap.data!;
          final order = data.order;
          final store = data.store;
          final payments = data.payments;
          final activePayments = payments
              .where((e) => (e['isActive'] ?? false) == true)
              .toList(growable: false);
          final dishes =
              (order?['dishes'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              const <Map<String, dynamic>>[];
          final subtotal = _orderTotal(order);
          final discount = _discountAmount(subtotal);
          final total = (subtotal - discount).clamp(0, 1 << 31);

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  // User info
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'Unknown User',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                user?.email ?? '-',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Store info
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.store_mall_directory_outlined,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (store?['name'] as String?) ?? 'Selected Store',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (store?['address'] as String?) ??
                                    'Store ID: ${(store?['id'] ?? '-') as Object}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dishes summary (collapsible, items flattened without step headers)
                  if (dishes.isNotEmpty)
                    ...dishes.map((d) {
                      final dishId = (d['dishId'] ?? 0) as int;
                      final expanded = _expanded[dishId] ?? false;
                      // Flatten items across steps
                      final steps =
                          (d['steps'] as List<dynamic>?)
                              ?.cast<Map<String, dynamic>>() ??
                          const <Map<String, dynamic>>[];
                      final items = <Map<String, dynamic>>[];
                      for (final s in steps) {
                        final its =
                            (s['items'] as List<dynamic>?)
                                ?.cast<Map<String, dynamic>>() ??
                            const <Map<String, dynamic>>[];
                        items.addAll(its);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                onTap: () => setState(
                                  () => _expanded[dishId] = !expanded,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Dish #${d['dishId']}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  _formatVnd(
                                                    (d['price'] ?? 0) as int,
                                                  ),
                                                  style: const TextStyle(
                                                    color: primary,
                                                    fontWeight: FontWeight.w800,
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
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            const SizedBox(height: 6),
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
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      AnimatedRotation(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        turns: expanded ? 0.5 : 0,
                                        child: const Icon(
                                          Icons.keyboard_arrow_down,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedCrossFade(
                                duration: const Duration(milliseconds: 200),
                                crossFadeState: expanded
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                firstChild: const SizedBox.shrink(),
                                secondChild: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    12,
                                  ),
                                  child: Column(
                                    children: [
                                      for (final it in items)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  it['menuItemName']
                                                          as String? ??
                                                      'Item',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text('x${it['quantity'] ?? 1}'),
                                              const SizedBox(width: 12),
                                              Text(
                                                _formatVnd(
                                                  (it['price'] ?? 0) as int,
                                                ),
                                                style: const TextStyle(
                                                  color: primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  // Promotion picker
                  InkWell(
                    onTap: _openPromotionPicker,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer, color: Colors.black54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedPromotion == null
                                      ? 'Add promotion'
                                      : (_selectedPromotion!['name']
                                                as String? ??
                                            'Promotion'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (_selectedPromotion != null) ...[
                                  Text(
                                    'Code: ${_selectedPromotion!['code']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Builder(
                                    builder: (_) {
                                      final type =
                                          (_selectedPromotion!['discountType']
                                              as String?) ??
                                          '';
                                      final value =
                                          (_selectedPromotion!['discountValue'] ??
                                                  0)
                                              as int;
                                      final est =
                                          type.toUpperCase() == 'PERCENT'
                                          ? '- ${_formatVnd(((subtotal * value) / 100).floor())} (${value}%)'
                                          : '- ${_formatVnd(value)}';
                                      return Text(
                                        'Giảm: $est',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.redAccent,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Payment Methods
                  InkWell(
                    onTap: () => _openPaymentMethodPicker(payments),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payment method',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  () {
                                    final sel = payments.firstWhere(
                                      (e) => e['id'] == _selectedPaymentId,
                                      orElse: () => const {},
                                    );
                                    final name = sel['name'] as String?;
                                    final desc = sel['description'] as String?;
                                    if (name == null)
                                      return 'Choose payment method';
                                    return desc == null || desc.isEmpty
                                        ? name
                                        : '$name — $desc';
                                  }(),
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Order total
                  Container(
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
                            const Text(
                              'Subtotal',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Text(_formatVnd(subtotal)),
                          ],
                        ),
                        if (discount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Promotion${_selectedPromotion?['code'] != null ? ' (${_selectedPromotion!['code']})' : ''}',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '- ${_formatVnd(discount)}',
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_orderCal(order)} cal',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatVnd(total),
                                  style: const TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Bottom confirm bar
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
                    child: ElevatedButton(
                      onPressed: _selectedPaymentId == null || _confirming
                          ? null
                          : () async {
                              await _onConfirm(order);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: Text(_confirming ? 'Confirming…' : 'Confirm'),
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

  Future<void> _onConfirm(Map<String, dynamic>? order) async {
    const primary = Color(0xFF86C144);
    if (order == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No current order')));
      return;
    }
    final orderId = _extractOrderId(order);
    final paymentId = _selectedPaymentId;
    if (paymentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose payment method')),
      );
      return;
    }
    if (orderId == null || orderId <= 0) {
      try {
        debugPrint('Could not determine orderId from order:');
        debugPrint(jsonEncode(order));
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot confirm: Invalid order id')),
      );
      return;
    }
    setState(() => _confirming = true);
    try {
      final headers = await AuthService().authHeaders();
      if (headers.isEmpty || !headers.containsKey('Authorization')) {
        throw Exception('Missing access token');
      }
      final uri = Uri.parse(
        'https://chickenkitchen.milize-lena.space/api/orders/confirm',
      );
      final payload = <String, dynamic>{
        'orderId': orderId,
        'paymentMethodId': paymentId,
        'promotionId': _selectedPromotion?['id'], // can be null
        'channel': 'app',
      };
      // Log request for troubleshooting 404
      try {
        debugPrint('CONFIRM API -> POST $uri');
        debugPrint('Headers(safe): ${jsonEncode(_maskHeaders(headers))}');
        debugPrint('Body: ${jsonEncode(payload)}');
      } catch (_) {}
      final resp = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      );
      if (!mounted) return;
      try {
        debugPrint('CONFIRM API <- HTTP ${resp.statusCode}');
        debugPrint('Response body: ${resp.body}');
      } catch (_) {}
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Confirm failed: HTTP ${resp.statusCode}')),
        );
        return;
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final statusCode = json['statusCode'] as int? ?? resp.statusCode;
      final message = json['message'] as String?;
      if (statusCode != 200) {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message ?? 'Confirm failed')));
        return;
      }
      final data = json['data'];
      final url = data is String ? data : (data?['url'] as String?);
      try {
        debugPrint('Payment URL: ${url ?? '(none)'}');
      } catch (_) {}
      if (url == null || url.isEmpty) {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No payment URL received')),
        );
        return;
      }
      // Launch VNPAY URL in external browser
      final launchUri = Uri.parse(url);
      final ok = await launchUrl(
        launchUri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open payment URL')),
        );
        return;
      }
      // Keep confirming spinner shown until we get callback back or user returns
      // Optionally, we could stop loading now; for UX, stop it.
      setState(() => _confirming = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Confirm error: $e')));
    }
  }

  int? _extractOrderId(Map<String, dynamic> order) {
    dynamic tryParse(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    // Direct keys
    for (final k in const ['id', 'orderId', 'orderID', 'order_id']) {
      final val = tryParse(order[k]);
      if (val != null && val > 0) return val;
    }

    // Nested under 'order'
    final nested = order['order'];
    if (nested is Map<String, dynamic>) {
      for (final k in const ['id', 'orderId', 'orderID', 'order_id']) {
        final val = tryParse(nested[k]);
        if (val != null && val > 0) return val;
      }
    }

    return null;
  }

  Map<String, String> _maskHeaders(Map<String, String> headers) {
    final m = Map<String, String>.from(headers);
    final auth = m['Authorization'];
    if (auth != null) {
      final parts = auth.split(' ');
      if (parts.length == 2) {
        final token = parts[1];
        final masked = token.length <= 8
            ? '***'
            : '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
        m['Authorization'] = '${parts[0]} $masked';
      } else {
        m['Authorization'] = '***';
      }
    }
    return m;
  }
}

class _ConfirmData {
  final Map<String, dynamic>? order;
  final List<Map<String, dynamic>> payments;
  final Map<String, dynamic>? store; // selected store info (name, address)
  const _ConfirmData({
    required this.order,
    required this.payments,
    required this.store,
  });
}
