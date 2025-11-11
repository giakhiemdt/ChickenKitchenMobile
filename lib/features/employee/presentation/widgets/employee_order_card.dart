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

  // Feedback UI removed from list cards; feedback is shown only in detail dialog.

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
          // Feedback intentionally not shown here to avoid repeated fetching and list clutter.
          const SizedBox(height: 8),
          // Dishes with full step breakdown
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
                      final dishTitle =
                          (d.name.isNotEmpty
                              ? d.name
                              : (d.note.isNotEmpty ? d.note : 'Dish #${d.dishId}')) +
                          (d.isCustom ? ' (custom)' : '');
                      return Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                          childrenPadding: const EdgeInsets.only(
                            left: 8,
                            right: 8,
                            bottom: 12,
                          ),
                          title: Text(
                            dishTitle,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          subtitle: Text('${_formatCurrency(d.price)} • ${d.cal} cal',
                              style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          children: [
                            for (int si = 0; si < d.steps.length; si++) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Row(
                                  children: [
                                    // step order number
                                    CircleAvatar(
                                      radius: 11,
                                      backgroundColor: _stepColor(
                                        si,
                                        d.steps[si].stepName,
                                      ).withOpacity(.15),
                                      child: Text(
                                        '${si + 1}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _stepColor(
                                            si,
                                            d.steps[si].stepName,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // semantic icon per step
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: _stepColor(
                                          si,
                                          d.steps[si].stepName,
                                        ).withOpacity(.10),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _stepIcon(d.steps[si].stepName, si),
                                        size: 16,
                                        color: _stepColor(
                                          si,
                                          d.steps[si].stepName,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // step name label
                                    Expanded(
                                      child: Text(
                                        d.steps[si].stepName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: _stepColor(
                                            si,
                                            d.steps[si].stepName,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${d.steps[si].items.length} item(s)',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...d.steps[si].items.map(
                                (it) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6.0,
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          (it.imageUrl.isNotEmpty
                                              ? it.imageUrl
                                              : _fallbackItemImage),
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Image.asset(
                                                'assets/images/Logo.png',
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              it.menuItemName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_formatCurrency(it.price)} • ${it.cal} cal',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'x${it.quantity}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
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
                      // Changed from green to brand red per request
                      backgroundColor: const Color(0xFFB71C1C),
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

  

  Color _stepColor(int index, String name) {
    final lower = name.toLowerCase();
    if (lower.contains('prep') || lower.contains('chuẩn')) {
      return Colors.blue.shade700;
    } else if (lower.contains('cook') || lower.contains('nấu')) {
      return Colors.orange.shade700;
    } else if (lower.contains('grill') ||
        lower.contains('chiên') ||
        lower.contains('rán')) {
      return Colors.red.shade600;
    } else if (lower.contains('pack') || lower.contains('đóng')) {
      return Colors.purple.shade700;
    } else if (lower.contains('serve') ||
        lower.contains('phục') ||
        lower.contains('finish') ||
        lower.contains('xong')) {
      return Colors.green.shade700;
    }
    final palette = [
      Colors.indigo.shade600,
      Colors.cyan.shade700,
      Colors.deepOrange.shade600,
      Colors.deepPurple.shade600,
      Colors.teal.shade700,
    ];
    return palette[index % palette.length];
  }

  IconData _stepIcon(String name, int index) {
    final lower = name.toLowerCase();
    if (lower.contains('prep') || lower.contains('chuẩn'))
      return Icons.build_outlined;
    if (lower.contains('cook') || lower.contains('nấu'))
      return Icons.local_fire_department_outlined;
    if (lower.contains('grill') ||
        lower.contains('chiên') ||
        lower.contains('rán'))
      return Icons.outdoor_grill_outlined;
    if (lower.contains('mix') || lower.contains('trộn'))
      return Icons.restaurant_outlined;
    if (lower.contains('pack') || lower.contains('đóng'))
      return Icons.inventory_2_outlined;
    if (lower.contains('serve') || lower.contains('phục'))
      return Icons.room_service_outlined;
    if (lower.contains('finish') ||
        lower.contains('xong') ||
        lower.contains('done'))
      return Icons.check_circle_outline;
    const seq = [
      Icons.layers_outlined,
      Icons.tune_outlined,
      Icons.timelapse_outlined,
      Icons.assignment_turned_in_outlined,
      Icons.flag_outlined,
    ];
    return seq[index % seq.length];
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

 
