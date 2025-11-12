// ignore_for_file: unused_element, unused_field
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobiletest/features/orders/domain/KitchenOrder.dart';
import 'package:mobiletest/features/orders/presentation/OrderDetailPage.dart';
import 'package:mobiletest/features/auth/data/auth_service.dart';
import 'package:mobiletest/features/auth/presentation/SignInWidget.dart';
import 'package:mobiletest/features/employee/domain/employee_models.dart';
import 'package:mobiletest/features/employee/presentation/widgets/employee_order_card.dart';
import 'package:mobiletest/features/employee/presentation/widgets/employee_sidebar.dart';
import 'package:mobiletest/features/employee/presentation/widgets/time_display.dart';
import 'package:mobiletest/features/employee/presentation/widgets/employee_order_detail_dialog.dart';

// Enum filters
enum OrderTypeFilter { all, dineIn, takeaway, delivery }
enum OrderStatusFilter { all, pending, preparing }

class EmployeePage extends StatefulWidget {
  const EmployeePage({super.key});

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  List<KitchenOrder> _orders = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  Timer? _clockTimer;
  // Track status update in progress per order
  final Map<int, bool> _updatingStatus = <int, bool>{};
  
  OrderTypeFilter _typeFilter = OrderTypeFilter.all;
  OrderStatusFilter _statusFilter = OrderStatusFilter.all;
  bool _sortByPriority = true;
  
  // Sidebar state
  String _selectedTab = 'orders'; // 'orders' or 'history'

  // ============== Employee detail (from API) ==============
  EmployeeDetail? _employee;
  bool _employeeLoading = false;
  String? _employeeError;

  // ============== Orders from API by status ==============
  final List<String> _statusOptions = const [
    'FAILED', 'CONFIRMED', 'PROCESSING', 'READY', 'COMPLETED', 'CANCELLED',
  ];
  String _selectedApiStatus = 'CONFIRMED';
  List<EmployeeOrderSummary> _apiOrders = [];
  bool _ordersApiLoading = false;
  String? _ordersApiError;
  // Paging for API orders
  int _pageNumber = 1;
  static const int _pageSize = 6; // lấy 6 item mỗi trang
  bool _hasNextPage = false;

  @override
  void initState() {
    super.initState();
    // Lock to landscape when this page is shown
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _loadOrders(); // legacy demo data (kept for History view)
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchOrdersByStatus(_selectedApiStatus);
    });
    // Update elapsed time every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Fetch employee detail and first page of orders by status
    _fetchEmployeeDetail();
    _fetchOrdersByStatus(_selectedApiStatus);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    // Restore to portrait orientations when leaving this page
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _fetchEmployeeDetail() async {
    setState(() {
      _employeeLoading = true;
      _employeeError = null;
    });
    try {
      final headers = await AuthService().authHeaders();
      final uri = Uri.parse('https://chickenkitchen.milize-lena.space/api/orders/employee/me');
      final resp = await http.get(uri, headers: {
        ...headers,
        'Accept': 'application/json',
      });
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (json['statusCode'] != 200) {
        throw Exception('API error: ${json['message']}');
      }
      final data = json['data'] as Map<String, dynamic>;
      setState(() {
        _employee = EmployeeDetail.fromJson(data);
        _employeeLoading = false;
      });
    } catch (e) {
      setState(() {
        _employeeError = e.toString();
        _employeeLoading = false;
      });
    }
  }

  Future<void> _fetchOrdersByStatus(String status, {int? pageNumber}) async {
    setState(() {
      _selectedApiStatus = status;
      _ordersApiLoading = true;
      _ordersApiError = null;
    });
    try {
      final headers = await AuthService().authHeaders();
      final page = pageNumber ?? _pageNumber;
      final uri = Uri.parse(
          'https://chickenkitchen.milize-lena.space/api/orders/employee?status=$status&pageNumber=$page&size=$_pageSize');
      final resp = await http.get(uri, headers: {
        ...headers,
        'Accept': 'application/json',
      });
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (json['statusCode'] != 200) {
        throw Exception('API error: ${json['message']}');
      }
      final data = json['data'] as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(EmployeeOrderSummary.fromJson)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // oldest first (more delayed first)
      setState(() {
        _apiOrders = items;
        _pageNumber = page;
        _hasNextPage = items.length >= _pageSize; // naive next check
        _ordersApiLoading = false;
      });
    } catch (e) {
      setState(() {
        _ordersApiError = e.toString();
        _ordersApiLoading = false;
      });
    }
  }

  Future<EmployeeOrderSummary?> _fetchOrderDetailById(int orderId) async {
    try {
      final headers = await AuthService().authHeaders();
      final uri = Uri.parse('https://chickenkitchen.milize-lena.space/api/orders/employee/detail/$orderId');
      final resp = await http.get(uri, headers: {
        ...headers,
        'Accept': 'application/json',
      });
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      if (map['statusCode'] != 200) {
        throw Exception('API error: ${map['message']}');
      }
      final data = map['data'] as Map<String, dynamic>;
      return EmployeeOrderSummary.fromJson(data);
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải chi tiết đơn: $e')),
      );
      return null;
    }
  }

  Future<void> _openOrderDetail(EmployeeOrderSummary summary) async {
    // Hiển thị loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final detail = await _fetchOrderDetailById(summary.orderId);
    if (!mounted) return;
    Navigator.of(context).pop(); // close loading
    if (detail == null) return;
    showDialog(
      context: context,
      builder: (_) => EmployeeOrderDetailDialog(order: detail),
    );
  }

  Future<void> _changeOrderStatus(int orderId, String endpoint, String newStatus, {bool removeWhenDone = false}) async {
    if (_updatingStatus[orderId] == true) return;
    setState(() { _updatingStatus[orderId] = true; });
    final idx = _apiOrders.indexWhere((o) => o.orderId == orderId);
    EmployeeOrderSummary? previous;
    if (idx != -1) {
      previous = _apiOrders[idx];
      _apiOrders[idx] = EmployeeOrderSummary(
        orderId: previous.orderId,
        status: newStatus,
        totalPrice: previous.totalPrice,
        createdAt: previous.createdAt,
        pickupTime: previous.pickupTime,
        customerName: previous.customerName,
        customerImageUrl: previous.customerImageUrl,
        itemsCount: previous.itemsCount,
        dishes: previous.dishes,
      );
    }
    try {
      final headers = await AuthService().authHeaders();
      final uri = Uri.parse('https://chickenkitchen.milize-lena.space/api/orders/employee/$endpoint/$orderId');
      final resp = await http.post(uri, headers: {
        ...headers,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 8));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đơn #$orderId -> $newStatus')),
      );
      if (removeWhenDone) {
        setState(() { _apiOrders.removeWhere((o) => o.orderId == orderId); });
      }
    } catch (e) {
      if (previous != null && mounted) {
        setState(() { _apiOrders[idx] = previous!; });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật #$orderId: $e')),
        );
      }
    } finally {
      if (mounted) setState(() { _updatingStatus[orderId] = false; });
    }
  }

  void _advanceOrder(EmployeeOrderSummary o) {
    final s = o.status.toUpperCase();
    if (s == 'CONFIRMED') {
      _changeOrderStatus(o.orderId, 'accept', 'PROCESSING');
    } else if (s == 'PROCESSING') {
      _changeOrderStatus(o.orderId, 'ready', 'READY');
    } else if (s == 'READY') {
      _changeOrderStatus(o.orderId, 'complete', 'COMPLETED', removeWhenDone: true);
    }
  }

  void _cancelOrder(EmployeeOrderSummary o) {
    _changeOrderStatus(o.orderId, 'cancel', 'CANCELLED', removeWhenDone: true);
  }

  Future<void> _loadOrders() async {
    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _orders = _getSampleOrders();
        _loading = false;
        _error = null;
      });
      // Play sound for new urgent orders
      _checkUrgentOrders(_orders);
    }
  }

  // Sample data - code cứng
  List<KitchenOrder> _getSampleOrders() {
    final now = DateTime.now();
    return [
      KitchenOrder(
        id: 125,
        orderNumber: '#125',
        tableName: 'Bàn 07',
        customerName: 'Anh Minh',
        staffName: 'Hạnh',
        createdAt: now.subtract(const Duration(minutes: 5)),
        orderType: 'dine-in',
        status: 'pending',
        specialNote: null,
        items: [
          KitchenOrderItem(
            id: 1,
            name: 'Cơm Gà Xối Mỡ',
            quantity: 2,
            customizations: ['70% Đường', 'Ít đá'],
            specialRequest: 'Làm riêng nước sốt',
            steps: [
              '1. Luộc gà',
              '2. Xé gà',
              '3. Nấu cơm',
              '4. Làm nước sốt',
              '5. Plating & trang trí',
            ],
          ),
          KitchenOrderItem(
            id: 2,
            name: 'Phở Gà Nước',
            quantity: 1,
            customizations: ['Không hành'],
            specialRequest: null,
            steps: [
              '1. Nấu nước dùng',
              '2. Chần bánh phở',
              '3. Luộc thịt gà',
              '4. Plating',
            ],
          ),
        ],
      ),
      KitchenOrder(
        id: 126,
        orderNumber: '#126',
        tableName: null,
        customerName: 'Chị Lan',
        staffName: 'Tú',
        createdAt: now.subtract(const Duration(minutes: 12)),
        orderType: 'takeaway',
        status: 'preparing',
        specialNote: 'Khách đợi ở quầy',
        items: [
          KitchenOrderItem(
            id: 3,
            name: 'Cơm Gà Nướng',
            quantity: 3,
            customizations: ['Thêm Trân châu', 'Cay cấp độ 3'],
            specialRequest: null,
            steps: [
              '1. Ướp gà',
              '2. Nướng gà',
              '3. Nấu cơm',
              '4. Làm nước chấm',
              '5. Plating',
            ],
          ),
        ],
      ),
      KitchenOrder(
        id: 127,
        orderNumber: '#127',
        tableName: 'Bàn 12',
        customerName: 'Anh Khoa',
        staffName: 'Mai',
        createdAt: now.subtract(const Duration(minutes: 18)),
        orderType: 'dine-in',
        status: 'pending',
        specialNote: null,
        items: [
          KitchenOrderItem(
            id: 4,
            name: 'Xôi Gà',
            quantity: 1,
            customizations: [],
            specialRequest: 'Ra sau món khai vị',
            steps: [
              '1. Hấp xôi',
              '2. Luộc gà',
              '3. Làm nước mắm gừng',
              '4. Plating',
            ],
          ),
          KitchenOrderItem(
            id: 5,
            name: 'Salad Gà',
            quantity: 2,
            customizations: ['Không Hành Tây'],
            specialRequest: null,
            steps: [
              '1. Luộc gà',
              '2. Rửa rau',
              '3. Làm dressing',
              '4. Trộn salad',
            ],
          ),
        ],
      ),
      KitchenOrder(
        id: 128,
        orderNumber: '#128',
        tableName: null,
        customerName: 'Anh Tùng',
        staffName: 'Hương',
        createdAt: now.subtract(const Duration(minutes: 7)),
        orderType: 'delivery',
        status: 'preparing',
        specialNote: 'Giao nhanh - Khách gấp',
        items: [
          KitchenOrderItem(
            id: 6,
            name: 'Burger Gà Giòn',
            quantity: 2,
            customizations: ['Thêm phô mai', 'Không dưa chua'],
            specialRequest: null,
            steps: [
              '1. Chiên gà',
              '2. Nướng bánh burger',
              '3. Chuẩn bị rau',
              '4. Ráp burger',
            ],
          ),
          KitchenOrderItem(
            id: 7,
            name: 'Khoai Tây Chiên',
            quantity: 1,
            customizations: [],
            specialRequest: null,
            steps: [
              '1. Cắt khoai tây',
              '2. Chiên giòn',
              '3. Rắc muối',
            ],
          ),
        ],
      ),
      KitchenOrder(
        id: 129,
        orderNumber: '#129',
        tableName: 'Bàn 03',
        customerName: 'Chị Hà',
        staffName: 'Linh',
        createdAt: now.subtract(const Duration(minutes: 3)),
        orderType: 'dine-in',
        status: 'pending',
        specialNote: null,
        items: [
          KitchenOrderItem(
            id: 8,
            name: 'Mì Ý Gà',
            quantity: 1,
            customizations: ['Ít muối'],
            specialRequest: null,
            steps: [
              '1. Luộc mì',
              '2. Áp chảo gà',
              '3. Làm sốt',
              '4. Trộn đều & plating',
            ],
          ),
        ],
      ),
      KitchenOrder(
        id: 130,
        orderNumber: '#130',
        tableName: null,
        customerName: 'Anh Đạt',
        staffName: 'Hạnh',
        createdAt: now.subtract(const Duration(minutes: 16)),
        orderType: 'takeaway',
        status: 'pending',
        specialNote: null,
        items: [
          KitchenOrderItem(
            id: 9,
            name: 'Gà Rán Giòn',
            quantity: 4,
            customizations: ['Cay vừa'],
            specialRequest: 'Gói riêng từng phần',
          ),
        ],
      ),
    ];
  }

  void _checkUrgentOrders(List<KitchenOrder> orders) {
    final hasUrgent = orders.any((o) => o.priority == OrderPriority.urgent);
    if (hasUrgent) {
      // Play alert sound (placeholder - would use audioplayers package)
      SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<void> _updateStatus(int orderId, String status) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (mounted) {
      setState(() {
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          if (status == 'completed') {
            // Remove completed order from list
            _orders.removeAt(index);
          } else {
            // Update status to preparing
            final order = _orders[index];
            _orders[index] = KitchenOrder(
              id: order.id,
              orderNumber: order.orderNumber,
              tableName: order.tableName,
              customerName: order.customerName,
              staffName: order.staffName,
              createdAt: order.createdAt,
              orderType: order.orderType,
              status: status,
              items: order.items,
              specialNote: order.specialNote,
            );
          }
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'completed' ? 'Đã hoàn thành đơn #$orderId' : 'Đã bắt đầu làm đơn #$orderId'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  List<KitchenOrder> get _filteredOrders {
    var filtered = _orders.where((order) {
      // Type filter
      if (_typeFilter != OrderTypeFilter.all) {
        final typeMatch = (_typeFilter == OrderTypeFilter.dineIn && order.orderType == 'dine-in') ||
            (_typeFilter == OrderTypeFilter.takeaway && order.orderType == 'takeaway') ||
            (_typeFilter == OrderTypeFilter.delivery && order.orderType == 'delivery');
        if (!typeMatch) return false;
      }
      
      // Status filter
      if (_statusFilter != OrderStatusFilter.all) {
        final statusMatch = (_statusFilter == OrderStatusFilter.pending && order.status == 'pending') ||
            (_statusFilter == OrderStatusFilter.preparing && order.status == 'preparing');
        if (!statusMatch) return false;
      }
      
      return true;
    }).toList();

    // Sort by priority or time
    if (_sortByPriority) {
      filtered.sort((a, b) {
        final priorityCompare = b.priority.index.compareTo(a.priority.index);
        if (priorityCompare != 0) return priorityCompare;
        return b.createdAt.compareTo(a.createdAt);
      });
    } else {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return filtered;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildHistoryView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.black26),
          SizedBox(height: 16),
          Text(
            'Order History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Lịch sử đơn hàng sẽ hiển thị ở đây',
            style: TextStyle(fontSize: 14, color: Colors.black38),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(
        children: [
          // Sidebar
          EmployeeSidebar(
            selectedTab: _selectedTab,
            onSelectTab: (tab) => setState(() => _selectedTab = tab),
            employee: _employee,
            employeeLoading: _employeeLoading,
            employeeError: _employeeError,
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top utility bar with logout (moved up for tablet reachability)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedTab == 'orders'
                              ? 'Kitchen Display'
                              : 'Order History',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // Logout button elevated higher per user request
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _confirmLogout,
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Logout'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB71C1C),
                            side: const BorderSide(color: Color(0xFFB71C1C)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status bar (calls API by status)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Trạng thái: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final s in _statusOptions)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: ChoiceChip(
                                    label: Text(s),
                                    selected: _selectedApiStatus == s,
                                    onSelected: (_) => _fetchOrdersByStatus(s, pageNumber: 1),
                                    selectedColor: const Color(0xFFB71C1C).withOpacity(0.2),
                                    labelStyle: TextStyle(
                                      color: _selectedApiStatus == s
                                          ? const Color(0xFFB71C1C)
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => _fetchOrdersByStatus(_selectedApiStatus),
                        color: const Color(0xFFB71C1C),
                        tooltip: 'Làm mới danh sách',
                      ),
                    ],
                  ),
                ),
                // Orders Grid or History
                Expanded(
                  child: _selectedTab == 'history'
                      ? _buildHistoryView()
                      : _ordersApiLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _ordersApiError != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text('Lỗi tải đơn: $_ordersApiError',
                                        style: const TextStyle(color: Colors.red)),
                                  ),
                                )
                              : _apiOrders.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Không có đơn với trạng thái này',
                                        style: TextStyle(fontSize: 18, color: Colors.black54),
                                      ),
                                    )
                                  : Column(
                                      children: [
                            // Pagination controls (moved above grid for easier reach)
                                        Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 12,
                                bottom: 8,
                              ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Trang $_pageNumber', style: const TextStyle(fontWeight: FontWeight.w600)),
                                              Row(
                                                children: [
                                                  TextButton.icon(
                                                    onPressed: _pageNumber > 1 && !_ordersApiLoading
                                                        ? () => _fetchOrdersByStatus(_selectedApiStatus, pageNumber: _pageNumber - 1)
                                                        : null,
                                                    icon: const Icon(Icons.chevron_left),
                                                    label: const Text('Trước'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFFB71C1C,
                                          ),
                                        ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  TextButton(
                                                    onPressed: _hasNextPage && !_ordersApiLoading
                                                        ? () => _fetchOrdersByStatus(_selectedApiStatus, pageNumber: _pageNumber + 1)
                                                        : null,
                                                    child: const Row(
                                                      children: [
                                                        Text('Sau'),
                                                        SizedBox(width: 4),
                                                        Icon(Icons.chevron_right),
                                                      ],
                                                    ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFFB71C1C,
                                          ),
                                        ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                            // Grid of vertical rectangular cards
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent:
                                            360, // slightly wider cards
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio:
                                            0.66, // a bit taller for bottom actions
                                      ),
                                  itemCount: _apiOrders.length,
                                  itemBuilder: (context, i) => EmployeeOrderCard(
                                    order: _apiOrders[i],
                                    isUpdating: _updatingStatus[_apiOrders[i].orderId] == true,
                                    onTap: () => _openOrderDetail(_apiOrders[i]),
                                    onAccept: () => _advanceOrder(_apiOrders[i]),
                                    onCancel: () => _cancelOrder(_apiOrders[i]),
                                  ),
                                ),
                              ),
                            ),
                                      ],
                                    ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo (centered image with label below)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo image
                Image.asset(
                  'assets/images/Logo.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Chicken Kitchen',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFB71C1C),
                  ),
                ),
              ],
            ),
          ),
          // Store Info (above tabs)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _employeeLoading
                      ? 'Đang tải cửa hàng...'
                      : (_employee?.storeName ?? 'Cửa hàng'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black38,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _employee?.storeAddress ?? 'Địa chỉ...',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black26,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Tabs
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildSidebarTab(
                  icon: Icons.receipt_long,
                  label: 'Orders',
                  value: 'orders',
                  isSelected: _selectedTab == 'orders',
                ),
                const SizedBox(height: 8),
                _buildSidebarTab(
                  icon: Icons.history,
                  label: 'History',
                  value: 'history',
                  isSelected: _selectedTab == 'history',
                ),
              ],
            ),
          ),
          const Spacer(),
          // Date and Time row (above employee)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  _formatTime(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          // Employee Info (logout moved to top bar)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFB71C1C).withOpacity(0.1),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFFB71C1C),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _employee?.userFullName ?? 'Nhân viên',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _employee?.storeName ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTab({
    required IconData icon,
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = value;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB71C1C).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: const Color(0xFFB71C1C).withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFB71C1C) : Colors.black54,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? const Color(0xFFB71C1C) : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Top bar for main content area
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Title + employee/store brief
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedTab == 'orders' ? 'Kitchen Display System' : 'Order History',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                if (_employeeLoading)
                  const Text('Đang tải thông tin nhân viên...',
                      style: TextStyle(fontSize: 12, color: Colors.black45))
                else if (_employeeError != null)
                  Text('Lỗi: $_employeeError',
                      style: const TextStyle(fontSize: 12, color: Colors.red))
                else if (_employee != null)
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.badge, size: 16, color: Colors.black45),
                          const SizedBox(width: 4),
                          Text(
                            '${_employee!.userFullName} • ${_employee!.position}',
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.store_mall_directory, size: 16, color: Colors.black45),
                          const SizedBox(width: 4),
                          Text(
                            _employee!.storeName,
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ],
                      ),
                      if (_employee!.storePhone != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone, size: 16, color: Colors.black45),
                            const SizedBox(width: 4),
                            Text(
                              _employee!.storePhone!,
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
          ),
          // clock + refresh
          Text(
            TimeDisplay.format(DateTime.now()),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchEmployeeDetail();
              _fetchOrdersByStatus(_selectedApiStatus);
            },
            tooltip: 'Làm mới',
            color: const Color(0xFFB71C1C),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final auth = AuthService();
              await auth.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SignInWidget()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  
}

class _OrderCard extends StatelessWidget {
  final KitchenOrder order;
  final Function(int orderId, String status) onStatusUpdate;

  const _OrderCard({
    required this.order,
    required this.onStatusUpdate,
  });

  Color get _priorityColor {
    switch (order.priority) {
      case OrderPriority.normal:
        return Colors.white;
      case OrderPriority.warning:
        return Colors.orange.shade50;
      case OrderPriority.urgent:
        return Colors.red.shade50;
    }
  }

  Color get _priorityBorderColor {
    switch (order.priority) {
      case OrderPriority.normal:
        return Colors.grey.shade300;
      case OrderPriority.warning:
        return Colors.orange.shade400;
      case OrderPriority.urgent:
        return Colors.red.shade600;
    }
  }

  Color get _typeColor {
    switch (order.orderType) {
      case 'dine-in':
        return const Color(0xFF4CAF50);
      case 'takeaway':
        return const Color(0xFFFF9800);
      case 'delivery':
        return const Color(0xFF2196F3);
      default:
        return Colors.grey;
    }
  }

  String get _typeLabel {
    switch (order.orderType) {
      case 'dine-in':
        return 'Tại chỗ';
      case 'takeaway':
        return 'Mang đi';
      case 'delivery':
        return 'Giao hàng';
      default:
        return order.orderType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _priorityBorderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: _priorityBorderColor.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Order number centered at top
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _priorityColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Center(
              child: Text(
                order.orderNumber,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Order type (left) and elapsed time (right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _typeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _typeColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _priorityBorderColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.formattedElapsedTime,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _priorityBorderColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 3. Customer name
                Text(
                  order.customerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                // 4. Divider
                Divider(color: Colors.grey.shade300, thickness: 1),
                const SizedBox(height: 8),
                // Items list
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên món bên trái, số lượng bên phải
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            '${item.quantity}x',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFB71C1C),
                            ),
                          ),
                        ],
                      ),
                      // Steps (nếu có)
                      if (item.steps != null && item.steps!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ...item.steps!.map((step) => Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Text(
                            step,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              height: 1.3,
                            ),
                          ),
                        )),
                      ],
                    ],
                  ),
                )),
                // 5. Note section
                if (order.specialNote != null && order.specialNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Divider(color: Colors.grey.shade300, thickness: 1),
                  const SizedBox(height: 8),
                  const Text(
                    'Note',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFB71C1C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.specialNote!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // 6. Two buttons in a row: Cancel (gray) and Started (green)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            // Cancel logic (could remove or mark cancelled)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã hủy đơn ${order.orderNumber}')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            if (order.status == 'pending') {
                              // Navigate to Order Detail page
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => OrderDetailPage(
                                    order: order,
                                    onStatusUpdate: onStatusUpdate,
                                  ),
                                ),
                              );
                            } else {
                              onStatusUpdate(order.id, 'completed');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            order.status == 'pending' ? 'Started' : 'Complete',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
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
}

/* Moved to widgets/employee_order_card.dart
class EmployeeOrderCard extends StatelessWidget {
  final EmployeeOrderSummary order;
  const EmployeeOrderCard({super.key, required this.order});

  static const String _fallbackAvatar =
      'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?q=80&w=400&auto=format&fit=crop';
  static const String _fallbackItemImage =
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=400&auto=format&fit=crop';

  Color _statusColor(String s) {
    switch (s) {
      case 'FAILED':
        return Colors.red.shade600;
      case 'CONFIRMED':
        return Colors.blue.shade700;
      case 'PROCESSING':
        return Colors.orange.shade700;
      case 'READY':
        return Colors.green.shade700;
      case 'COMPLETED':
        return Colors.teal.shade700;
      case 'CANCELLED':
        return Colors.grey.shade600;
      default:
        return Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    final avatarUrl = (order.customerImageUrl ?? '').isNotEmpty
        ? order.customerImageUrl!
        : _fallbackAvatar;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with avatar, order id, status
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(avatarUrl),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${order.orderId}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(order.customerName ?? 'Khách vãng lai',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(order.status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Meta row
          Row(
            children: [
              const Icon(Icons.shopping_basket, size: 14, color: Colors.black45),
              const SizedBox(width: 4),
              Text('${order.itemsCount} món',
                  style: const TextStyle(fontSize: 12, color: Colors.black87)),
              const SizedBox(width: 12),
              const Icon(Icons.schedule, size: 14, color: Colors.black45),
              const SizedBox(width: 4),
              Text(TimeDisplay.format(order.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.black87)),
              const Spacer(),
              Text('Tổng: ${_formatCurrency(order.totalPrice)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          // Dishes with inner scrolling; fixed height area
          if (order.dishes.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox(
                height: 160,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    primary: false,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: order.dishes.length,
                    itemBuilder: (context, i) {
                      final d = order.dishes[i];
                      final title = (d.name.isNotEmpty ? d.name : (d.note.isNotEmpty ? d.note : 'Dish #${d.dishId}')) + (d.isCustom ? ' (custom)' : '');
                      return Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                          childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                          title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          subtitle: Text('${_formatCurrency(d.price)} • ${d.cal} cal',
                              style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          children: [
                            // Steps and their items
                            for (final st in d.steps) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 6, bottom: 4),
                                child: Text(st.stepName,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final it in st.items)
                                    SizedBox(
                                      width: 130,
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.network(
                                              (it.imageUrl.isNotEmpty ? it.imageUrl : _fallbackItemImage),
                                              width: 36,
                                              height: 36,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                width: 36,
                                                height: 36,
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.image_not_supported, size: 16, color: Colors.black38),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  it.menuItemName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                ),
                                                Text('x${it.quantity}',
                                                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCurrency(num n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      buf.write(s[i]);
      if (idx > 1 && idx % 3 == 1) buf.write(',');
    }
    return '${buf.toString()} ₫';
  }
}

class EmployeeDetail {
  final int id;
  final String position;
  final bool isActive;
  final String storeName;
  final String storeAddress;
  final String? storePhone;
  final String userFullName;
  final String userEmail;
  final String? userImageUrl;

  EmployeeDetail({
    required this.id,
    required this.position,
    required this.isActive,
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    required this.userFullName,
    required this.userEmail,
    required this.userImageUrl,
  });

  factory EmployeeDetail.fromJson(Map<String, dynamic> j) {
    final store = (j['store'] ?? {}) as Map<String, dynamic>;
    final user = (j['user'] ?? {}) as Map<String, dynamic>;
    return EmployeeDetail(
      id: j['id'] as int,
      position: (j['position'] ?? '') as String,
      isActive: (j['isActive'] ?? false) as bool,
      storeName: (store['name'] ?? '') as String,
      storeAddress: (store['address'] ?? '') as String,
      storePhone: store['phone'] as String?,
      userFullName: (user['fullName'] ?? '') as String,
      userEmail: (user['email'] ?? '') as String,
      userImageUrl: user['imageURL'] as String?,
    );
  }
}

class EmployeeOrderSummary {
  final int orderId;
  final String status;
  final int totalPrice;
  final DateTime createdAt;
  final DateTime? pickupTime;
  final String? customerName;
  final String? customerImageUrl;
  final int itemsCount;
  final List<DishSummary> dishes;

  EmployeeOrderSummary({
    required this.orderId,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
    required this.pickupTime,
    required this.customerName,
    required this.customerImageUrl,
    required this.itemsCount,
    required this.dishes,
  });

  factory EmployeeOrderSummary.fromJson(Map<String, dynamic> j) {
    final dishesList = (j['dishes'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(DishSummary.fromJson)
        .toList();
    int count = 0;
    for (final d in dishesList) {
      for (final st in d.steps) {
        count += st.items.fold<int>(0, (acc, it) => acc + (it.quantity));
      }
    }
    String? customerName;
    String? customerImg;
    final customer = j['customer'] as Map<String, dynamic>?;
    if (customer != null) {
      customerName = customer['fullName'] as String?;
      customerImg = customer['imageURL'] as String?;
    }
    return EmployeeOrderSummary(
      orderId: (j['orderId'] ?? 0) as int,
      status: (j['status'] ?? '') as String,
      totalPrice: (j['totalPrice'] ?? 0) as int,
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      pickupTime: DateTime.tryParse(j['pickupTime'] as String? ?? ''),
      customerName: customerName,
      customerImageUrl: customerImg,
      itemsCount: count,
      dishes: dishesList,
    );
  }
}

class DishSummary {
  final int dishId;
  final String name;
  final bool isCustom;
  final String note;
  final int price;
  final int cal;
  final List<DishStepSummary> steps;

  DishSummary({
    required this.dishId,
    required this.name,
    required this.isCustom,
    required this.note,
    required this.price,
    required this.cal,
    required this.steps,
  });

  factory DishSummary.fromJson(Map<String, dynamic> j) {
    final steps = (j['steps'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(DishStepSummary.fromJson)
        .toList();
    return DishSummary(
      dishId: (j['dishId'] ?? 0) as int,
      name: (j['name'] ?? '') as String,
      isCustom: (j['isCustom'] ?? false) as bool,
      note: (j['note'] ?? '') as String,
      price: (j['price'] ?? 0) as int,
      cal: (j['cal'] ?? 0) as int,
      steps: steps,
    );
  }
}

class DishStepSummary {
  final int stepId;
  final String stepName;
  final List<DishItemSummary> items;

  DishStepSummary({
    required this.stepId,
    required this.stepName,
    required this.items,
  });

  factory DishStepSummary.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(DishItemSummary.fromJson)
        .toList();
    return DishStepSummary(
      stepId: (j['stepId'] ?? 0) as int,
      stepName: (j['stepName'] ?? '') as String,
      items: items,
    );
  }
}

class DishItemSummary {
  final int menuItemId;
  final String menuItemName;
  final String imageUrl;
  final int quantity;
  final int price;
  final int cal;

  DishItemSummary({
    required this.menuItemId,
    required this.menuItemName,
    required this.imageUrl,
    required this.quantity,
    required this.price,
    required this.cal,
  });

  factory DishItemSummary.fromJson(Map<String, dynamic> j) => DishItemSummary(
        menuItemId: (j['menuItemId'] ?? 0) as int,
        menuItemName: (j['menuItemName'] ?? '') as String,
        imageUrl: (j['imageUrl'] ?? '') as String,
        quantity: (j['quantity'] ?? 0) as int,
        price: (j['price'] ?? 0) as int,
        cal: (j['cal'] ?? 0) as int,
      );

*/
/* class _TimeDisplay {
  static String format(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
} */
