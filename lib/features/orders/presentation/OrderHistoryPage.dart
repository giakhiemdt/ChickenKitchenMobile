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
  String _selectedStatus = 'ALL';
  String _selectedDateRange = 'ALL'; // ALL, TODAY, WEEK
  String _sortMode = 'NEWEST'; // NEWEST or OLDEST
  bool _cancelling = false;
  int? _feedbackSendingOrderId; // orderId currently sending feedback
  final Map<int, _FeedbackResult> _feedbackCache = {}; // orderId -> feedback
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: 1 + _filteredOrders().length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                  if (i == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusFilter(),
                        const SizedBox(height: 10),
                        _buildDateFilter(),
                        const SizedBox(height: 10),
                        _buildSortBar(),
                      ],
                    );
                  }
                  final it = _filteredOrders()[i - 1];
                          final orderId = it['orderId'] ?? it['id'] ?? 0;
                          final status = (it['status'] as String? ?? 'CONFIRMED').toUpperCase();
                          final total = (it['totalPrice'] ?? it['total'] ?? 0) as int;
                          final createdAt = (it['createdAt'] as String?) ?? '';
                          final pickupTime = (it['pickupTime'] as String?) ?? '';

                          final steps = _stepsForStatus(status);
                          final cancelled = status == 'CANCELLED' || status == 'FAILED';
                  final statusColor = _statusColor(status);

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
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                        ),
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
                          _MiniProgress(
                            steps: steps,
                            primary: statusColor,
                            cancelled: cancelled,
                          ),
                          const SizedBox(height: 10),
                          if (status == 'COMPLETED' || status == 'DELIVERED')
                            _buildFeedbackDisplay(orderId as int),
                          if (_canCancel(status))
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _cancelling
                                    ? null
                                    : () => _promptCancel(orderId as int),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFB71C1C),
                                  side: const BorderSide(
                                    color: Color(0xFFB71C1C),
                                  ),
                                  minimumSize: const Size.fromHeight(40),
                                ),
                                child: Text(
                                  _cancelling ? 'Cancelling…' : 'Cancel order',
                                ),
                              ),
                            ),
                          if ((status == 'COMPLETED' ||
                                  status == 'DELIVERED') &&
                              _feedbackCache.containsKey(orderId) &&
                              !_hasFeedback(orderId as int)) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _feedbackSendingOrderId == orderId
                                    ? null
                                    : () => _promptFeedback(orderId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB71C1C),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(42),
                                ),
                                icon: const Icon(Icons.rate_review_outlined),
                                label: Text(
                                  _feedbackSendingOrderId == orderId
                                      ? 'Sending feedback…'
                                      : 'Rate this order',
                                ),
                              ),
                            ),
                          ],
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
    final list = _orders.where((o) {
      final id = (o['orderId'] ?? o['id'] ?? '').toString().toLowerCase();
      final status = (o['status'] as String? ?? '').toLowerCase();
      final matchesKeyword =
          _keyword.isEmpty ||
          id.contains(_keyword) ||
          status.contains(_keyword);
      final matchesStatus =
          _selectedStatus == 'ALL' || status.toUpperCase() == _selectedStatus;
      final createdAtIso = (o['createdAt'] as String?) ?? '';
      bool matchesDate = true;
      if (_selectedDateRange != 'ALL' && createdAtIso.isNotEmpty) {
        final dt = DateTime.tryParse(createdAtIso)?.toLocal();
        if (dt != null) {
          final now = DateTime.now();
          switch (_selectedDateRange) {
            case 'TODAY':
              matchesDate =
                  dt.year == now.year &&
                  dt.month == now.month &&
                  dt.day == now.day;
              break;
            case 'WEEK':
              final startOfWeek = now.subtract(
                Duration(days: now.weekday - 1),
              ); // Monday
              final endOfWeek = startOfWeek.add(const Duration(days: 7));
              matchesDate =
                  dt.isAfter(
                    startOfWeek.subtract(const Duration(milliseconds: 1)),
                  ) &&
                  dt.isBefore(endOfWeek);
              break;
          }
        }
      }
      return matchesKeyword && matchesStatus && matchesDate;
    }).toList();
    list.sort((a, b) {
      final aIso = (a['createdAt'] as String?) ?? '';
      final bIso = (b['createdAt'] as String?) ?? '';
      final aDt = DateTime.tryParse(aIso)?.toLocal();
      final bDt = DateTime.tryParse(bIso)?.toLocal();
      int cmp;
      if (aDt == null && bDt == null)
        cmp = 0;
      else if (aDt == null)
        cmp = -1;
      else if (bDt == null)
        cmp = 1;
      else
        cmp = aDt.compareTo(bDt);
      return _sortMode == 'NEWEST' ? -cmp : cmp; // NEWEST = descending
    });
    return list;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  // UI: Status filter chips (ALL + statuses)
  Widget _buildStatusFilter() {
    final available = _availableStatuses();
    if (available.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in available)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(_displayStatus(s)),
                selected: _selectedStatus == s,
                selectedColor: _statusColor(s).withOpacity(0.18),
                labelStyle: TextStyle(
                  color: _selectedStatus == s
                      ? _statusColor(s)
                      : Colors.black87,
                  fontWeight: _selectedStatus == s
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                side: BorderSide(color: _statusColor(s).withOpacity(0.5)),
                onSelected: (_) => setState(() => _selectedStatus = s),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    const dates = ['ALL', 'TODAY', 'WEEK'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final d in dates) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(_displayDateRange(d)),
                selected: _selectedDateRange == d,
                selectedColor: Colors.indigo.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: _selectedDateRange == d
                      ? Colors.indigo.shade700
                      : Colors.black87,
                  fontWeight: _selectedDateRange == d
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                side: BorderSide(
                  color:
                      (_selectedDateRange == d ? Colors.indigo : Colors.black26)
                          .withOpacity(0.5),
                ),
                onSelected: (_) => setState(() => _selectedDateRange = d),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _displayDateRange(String d) {
    switch (d) {
      case 'TODAY':
        return 'Today';
      case 'WEEK':
        return 'This Week';
      case 'ALL':
      default:
        return 'All Dates';
    }
  }

  Widget _buildSortBar() {
    return Row(
      children: [
        const Icon(Icons.sort, size: 18, color: Colors.black54),
        const SizedBox(width: 6),
        DropdownButton<String>(
          value: _sortMode,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 'NEWEST', child: Text('Newest first')),
            DropdownMenuItem(value: 'OLDEST', child: Text('Oldest first')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _sortMode = v);
          },
        ),
        const Spacer(),
        Text(
          '${_filteredOrders().length} orders',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  List<String> _availableStatuses() {
    // Merge statuses from API and from actual orders; ensure 'ALL' at start
    final set = <String>{..._statuses.map((e) => e.toUpperCase())};
    for (final o in _orders) {
      final s = (o['status'] as String? ?? '').toUpperCase();
      if (s.isNotEmpty) set.add(s);
    }
    final list = ['ALL', ...set.toList()..sort()];
    return list;
  }

  String _displayStatus(String s) {
    if (s == 'ALL') return 'All';
    final lower = s.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'FAILED':
        return Colors.red.shade600;
      case 'CONFIRMED':
      case 'NEW':
        return Colors.blue.shade700;
      case 'PROCESSING':
      case 'PREPARING':
        return Colors.orange.shade700;
      case 'READY':
        return Colors.green.shade700;
      case 'COMPLETED':
      case 'DELIVERED':
        return Colors.teal.shade700;
      case 'CANCELLED':
        return Colors.grey.shade600;
      default:
        return Colors.black87;
    }
  }

  bool _canCancel(String status) {
    // Hide cancel when order is COMPLETED or already CANCELLED
    final s = status.toUpperCase();
    return s != 'COMPLETED' && s != 'CANCELLED';
  }

  Future<void> _promptCancel(int orderId) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        const primary = Color(0xFFB71C1C);
        return AlertDialog(
          title: const Text('Cancel order'),
          content: TextField(
            controller: ctrl,
            cursorColor: primary,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: primary, width: 2),
              ),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: primary),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('Confirm cancel'),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    await _sendCancel(orderId, reason);
  }

  Future<void> _sendCancel(int orderId, String reason) async {
    try {
      setState(() => _cancelling = true);
      final headers = await AuthService().authHeaders();
      if (headers.isEmpty || !headers.containsKey('Authorization')) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Missing token')));
        setState(() => _cancelling = false);
        return;
      }
      final uri = Uri.parse(
        'https://chickenkitchen.milize-lena.space/api/orders/cancel',
      );
      final body = jsonEncode(<String, dynamic>{
        'orderId': orderId,
        'reason': reason.isEmpty ? 'Remove out the cart' : reason,
      });
      final resp = await http.post(uri, headers: headers, body: body);
      if (!mounted) return;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order cancelled')));
        await _fetch();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cancel failed: HTTP ${resp.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cancel error: $e')));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _promptFeedback(int orderId) async {
    int rating = 0; // 0 = not selected
    final msgCtrl = TextEditingController();
    final result = await showDialog<_FeedbackResult>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            Widget buildStar(int value) {
              final filled = rating >= value;
              return GestureDetector(
                onTap: () => setLocalState(() => rating = value),
                child: Icon(
                  filled ? Icons.star : Icons.star_border,
                  size: 30,
                  color: filled ? const Color(0xFFB71C1C) : Colors.black26,
                ),
              );
            }

            return AlertDialog(
              title: const Text('Rate Order'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [for (int v = 1; v <= 5; v++) buildStar(v)],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: msgCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Message (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB71C1C),
                  ),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: rating == 0
                      ? null
                      : () => Navigator.of(ctx).pop(
                          _FeedbackResult(
                            rating: rating,
                            message: msgCtrl.text.trim(),
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;
    await _sendFeedback(orderId, result.rating, result.message);
  }

  Future<void> _sendFeedback(int orderId, int rating, String message) async {
    try {
      setState(() => _feedbackSendingOrderId = orderId);
      final headers = await AuthService().authHeaders();
      if (headers.isEmpty || !headers.containsKey('Authorization')) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Missing token')));
        setState(() => _feedbackSendingOrderId = null);
        return;
      }
      final uri = Uri.parse(
        'https://chickenkitchen.milize-lena.space/api/orders/$orderId/feedback',
      );
      final body = jsonEncode(<String, dynamic>{
        'rating': rating,
        'message': message,
      });
      final resp = await http.post(uri, headers: headers, body: body);
      if (!mounted) return;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
        // Reload orders (as requested) then fetch and cache feedback for this order
        await _fetch();
        await _fetchFeedbackSingle(orderId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feedback failed: HTTP ${resp.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending feedback: $e')));
    } finally {
      if (mounted) setState(() => _feedbackSendingOrderId = null);
    }
  }

  Widget _buildFeedbackDisplay(int orderId) {
    final feedback = _feedbackCache[orderId];
    // Lazy load if missing
    if (feedback == null) {
      // Trigger fetch without rebuilding infinitely
      Future.microtask(() async {
        await _fetchFeedbackSingle(orderId);
      });
      return const Padding(
        padding: EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Loading feedback…',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );
    }
    // If fetched but no feedback, show nothing
    if (feedback.rating == 0 && feedback.message.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (int i = 1; i <= 5; i++)
                Icon(
                  i <= feedback.rating ? Icons.star : Icons.star_border,
                  size: 18,
                  color: const Color(0xFFB71C1C),
                ),
              const SizedBox(width: 8),
              Text(
                '${feedback.rating}/5',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (feedback.message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              feedback.message,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _fetchFeedbackSingle(int orderId) async {
    try {
      final headers = await AuthService().authHeaders();
      if (headers.isEmpty || !headers.containsKey('Authorization')) return;
      final uri = Uri.parse(
        'https://chickenkitchen.milize-lena.space/api/orders/$orderId/feedback',
      );
      final resp = await http.get(uri, headers: headers);
      int rating = 0;
      String message = '';
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>?;
        if (data != null) {
          rating = (data['rating'] as num?)?.toInt() ?? 0;
          message = (data['message'] as String?)?.trim() ?? '';
        }
      } else {
        // Treat non-200 as no feedback so UI can decide to show Rate button
        rating = 0;
        message = '';
      }
      if (!mounted) return;
      setState(() {
        _feedbackCache[orderId] = _FeedbackResult(
          rating: rating,
          message: message,
        );
      });
    } catch (_) {
      // On error, mark as no feedback so the button can appear instead of spinner
      if (!mounted) return;
      setState(() {
        _feedbackCache[orderId] = const _FeedbackResult(rating: 0, message: '');
      });
    }
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

  bool _hasFeedback(int orderId) {
    final fb = _feedbackCache[orderId];
    return fb != null && fb.rating > 0;
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

class _FeedbackResult {
  final int rating;
  final String message;
  const _FeedbackResult({required this.rating, required this.message});
}
