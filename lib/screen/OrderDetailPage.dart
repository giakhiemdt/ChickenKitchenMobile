import 'package:flutter/material.dart';
import 'package:mobiletest/models/KitchenOrder.dart';

class OrderDetailPage extends StatefulWidget {
  final KitchenOrder order;
  final Function(int orderId, String newStatus) onStatusUpdate;

  const OrderDetailPage({
    super.key,
    required this.order,
    required this.onStatusUpdate,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late KitchenOrder _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  Color get _typeColor {
    switch (_currentOrder.orderType) {
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
    switch (_currentOrder.orderType) {
      case 'dine-in':
        return 'Tại chỗ';
      case 'takeaway':
        return 'Pick Up';
      case 'delivery':
        return 'Delivery';
      default:
        return 'Unknown';
    }
  }

  Color get _priorityBorderColor {
    switch (_currentOrder.priority) {
      case OrderPriority.normal:
        return Colors.grey;
      case OrderPriority.warning:
        return Colors.orange;
      case OrderPriority.urgent:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        title: Text('Chi tiết đơn ${_currentOrder.orderNumber}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Order Number - Centered
                  Text(
                    _currentOrder.orderNumber,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFB71C1C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Type and Timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _typeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _typeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _priorityBorderColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _currentOrder.formattedElapsedTime,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _priorityBorderColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  // Customer Info
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: Colors.black54, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _currentOrder.customerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  if (_currentOrder.tableName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.table_restaurant, color: Colors.black54, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _currentOrder.tableName!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Items Section
            const Text(
              'Món ăn',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            
            // Items List
            ..._currentOrder.items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item name and quantity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB71C1C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.quantity}x',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Customizations
                  if (item.customizations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...item.customizations.map((custom) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: Color(0xFF2196F3)),
                          const SizedBox(width: 6),
                          Text(
                            custom,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                  
                  // Steps
                  if (item.steps != null && item.steps!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Các bước thực hiện:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...item.steps!.map((step) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              step,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                  
                  // Special Request
                  if (item.specialRequest != null && item.specialRequest!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.specialRequest!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            )),
            
            // Special Note for Order
            if (_currentOrder.specialNote != null && _currentOrder.specialNote!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB71C1C), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ghi chú đặc biệt',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFB71C1C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentOrder.specialNote!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 100), // Space for bottom button
          ],
        ),
      ),
      
      // Bottom Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                // Mark as completed
                widget.onStatusUpdate(_currentOrder.id, 'completed');
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã hoàn thành đơn ${_currentOrder.orderNumber}'),
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Completed - Hoàn thành',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
