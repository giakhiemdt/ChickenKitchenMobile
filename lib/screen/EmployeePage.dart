import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobiletest/models/KitchenOrder.dart';
import 'package:mobiletest/screen/OrderDetailPage.dart';

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
  
  OrderTypeFilter _typeFilter = OrderTypeFilter.all;
  OrderStatusFilter _statusFilter = OrderStatusFilter.all;
  bool _sortByPriority = true;
  
  // Sidebar state
  String _selectedTab = 'orders'; // 'orders' or 'history'

  @override
  void initState() {
    super.initState();
    // Lock to landscape when this page is shown
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _loadOrders();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadOrders());
    // Update elapsed time every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
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
          _buildSidebar(),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                _buildTopBar(),
                // Filter Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Text('Loại: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      // make chips scrollable so they don't overflow
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...[
                                ('Tất cả', OrderTypeFilter.all),
                                ('Tại chỗ', OrderTypeFilter.dineIn),
                                ('Mang đi', OrderTypeFilter.takeaway),
                                ('Giao hàng', OrderTypeFilter.delivery),
                              ].map((item) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: FilterChip(
                                  label: Text(item.$1),
                                  selected: _typeFilter == item.$2,
                                  onSelected: (selected) {
                                    setState(() => _typeFilter = item.$2);
                                  },
                                  selectedColor: const Color(0xFFB71C1C).withOpacity(0.2),
                                  checkmarkColor: const Color(0xFFB71C1C),
                                ),
                              )),
                              const SizedBox(width: 24),
                              const Text('Trạng thái: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              ...[
                                ('Tất cả', OrderStatusFilter.all),
                                ('Mới', OrderStatusFilter.pending),
                                ('Đang làm', OrderStatusFilter.preparing),
                              ].map((item) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: FilterChip(
                                  label: Text(item.$1),
                                  selected: _statusFilter == item.$2,
                                  onSelected: (selected) {
                                    setState(() => _statusFilter = item.$2);
                                  },
                                  selectedColor: const Color(0xFFB71C1C).withOpacity(0.2),
                                  checkmarkColor: const Color(0xFFB71C1C),
                                ),
                              )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Sort Toggle
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _sortByPriority = !_sortByPriority);
                        },
                        icon: Icon(_sortByPriority ? Icons.priority_high : Icons.access_time),
                        label: Text(_sortByPriority ? 'Ưu tiên' : 'Thời gian'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFB71C1C)),
                      ),
                    ],
                  ),
                ),
                // Orders Grid or History
                Expanded(
                  child: _selectedTab == 'history'
                      ? _buildHistoryView()
                      : _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? Center(child: Text('Lỗi: $_error', style: const TextStyle(color: Colors.red)))
                              : _filteredOrders.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Không có đơn hàng nào',
                                        style: TextStyle(fontSize: 18, color: Colors.black54),
                                      ),
                                    )
                                  : GridView.builder(
                                      padding: const EdgeInsets.all(16),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        childAspectRatio: 0.75,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                      itemCount: _filteredOrders.length,
                                      itemBuilder: (context, index) {
                                        return _OrderCard(
                                          order: _filteredOrders[index],
                                          onStatusUpdate: _updateStatus,
                                        );
                                      },
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
                const Text(
                  'Chicken Kitchen Binh Thanh',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black38,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '720A Điện Biên Phủ, Phường 22, Bình Thạnh, Thành phố Hồ Chí Minh',
                  style: TextStyle(
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
          // Employee Info & Logout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nguyễn Văn A',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Chi nhánh Quận 1',
                            style: TextStyle(
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Show logout confirmation
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
                              onPressed: () {
                                Navigator.pop(context); // Close dialog
                                Navigator.pop(context); // Go back to previous screen
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
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Log out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB71C1C),
                      side: const BorderSide(color: Color(0xFFB71C1C)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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
          Text(
            _selectedTab == 'orders' ? 'Kitchen Display System' : 'Order History',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Text(
            _TimeDisplay.format(DateTime.now()),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Làm mới',
            color: const Color(0xFFB71C1C),
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

class _TimeDisplay {
  static String format(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
