import 'package:flutter/material.dart';
import 'package:mobiletest/features/employee/domain/employee_models.dart';
import 'package:mobiletest/features/employee/presentation/widgets/time_display.dart';

class EmployeeOrderCard extends StatelessWidget {
  final EmployeeOrderSummary order;
  final VoidCallback? onAccept;
  final VoidCallback? onCancel;
  final VoidCallback? onTap;
  const EmployeeOrderCard({
    super.key,
    required this.order,
    this.onAccept,
    this.onCancel,
    this.onTap,
  });

  bool get _showActions {
    final s = order.status.toUpperCase();
    return s != 'FAILED' && s != 'COMPLETED' && s != 'CANCELLED';
  }

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
    final card = Container(
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
                backgroundColor: Colors.grey.shade200,
                child: ClipOval(
                  child: Image.network(
                    avatarUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/Logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
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
              Text(
                TimeDisplay.format(order.createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          // Price highlighted
          Row(
            children: [
              const Icon(Icons.payments, size: 16, color: Color(0xFFB71C1C)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatCurrency(order.totalPrice),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFB71C1C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dishes with inner scrolling; fixed height area
          if (order.dishes.isNotEmpty)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    primary: false,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: order.dishes.length,
                    itemBuilder: (context, i) {
                      final d = order.dishes[i];
                      final title = (d.name.isNotEmpty
                              ? d.name
                              : (d.note.isNotEmpty ? d.note : 'Dish #${d.dishId}')) +
                          (d.isCustom ? ' (custom)' : '');
                      // Gộp toàn bộ item từ các step và hiển thị dạng hàng: ảnh + tên (trái), số lượng (phải)
                      final allItems = [
                        for (final st in d.steps) ...st.items,
                      ];
                      return Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                          childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                          title: Text(title,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          subtitle: Text('${_formatCurrency(d.price)} • ${d.cal} cal',
                              style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          children: [
                            for (final it in allItems)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        (it.imageUrl.isNotEmpty ? it.imageUrl : _fallbackItemImage),
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Image.asset(
                                          'assets/images/Logo.png',
                                          width: 36,
                                          height: 36,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        it.menuItemName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Text('x${it.quantity}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Bottom action bar (ẩn với FAILED/COMPLETED/CANCELLED)
          if (_showActions)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel ?? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cancelled order')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept ?? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Accepted order')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      order.status.toUpperCase() == 'PROCESSING'
                          ? 'Ready'
                          : (order.status.toUpperCase() == 'READY' ? 'Complete' : 'Accept'),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
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
