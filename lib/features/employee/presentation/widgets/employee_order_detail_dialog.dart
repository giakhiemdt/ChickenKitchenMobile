import 'package:flutter/material.dart';
import 'package:mobiletest/features/employee/domain/employee_models.dart';

class EmployeeOrderDetailDialog extends StatelessWidget {
  final EmployeeOrderSummary order;
  const EmployeeOrderDetailDialog({super.key, required this.order});

  static const String _fallbackItemImage =
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=400&auto=format&fit=crop';

  static const String _fallbackIngredientImage =
      'https://images.unsplash.com/photo-1512621776951-5f5b6f8a3e38?q=80&w=400&auto=format&fit=crop';

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order #${order.orderId}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(order.customerName ?? 'Khách vãng lai',
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(order.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: order.dishes.length,
                itemBuilder: (context, i) {
                  final d = order.dishes[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name.isNotEmpty ? d.name : 'Dish #${d.dishId}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('${_formatCurrency(d.price)} • ${d.cal} cal',
                              style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 8),
                          for (final st in d.steps) ...[
                            for (final it in st.items) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      (it.imageUrl.isNotEmpty ? it.imageUrl : _fallbackItemImage),
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Image.asset(
                                        'assets/images/Logo.png',
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(it.menuItemName,
                                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                                            ),
                                            Text('x${it.quantity}',
                                                style: const TextStyle(fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        if (it.ingredients.isNotEmpty)
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              for (final ing in it.ingredients)
                                                SizedBox(
                                                  width: 180,
                                                  child: Row(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius: BorderRadius.circular(6),
                                                        child: (ing.imageUrl != null && ing.imageUrl!.isNotEmpty)
                                                            ? Image.network(
                                                                ing.imageUrl!,
                                                                width: 28,
                                                                height: 28,
                                                                fit: BoxFit.cover,
                                                                errorBuilder: (_, __, ___) => Image.asset(
                                                                  'assets/images/Logo.png',
                                                                  width: 28,
                                                                  height: 28,
                                                                  fit: BoxFit.cover,
                                                                ),
                                                              )
                                                            : Image.asset(
                                                                'assets/images/Logo.png',
                                                                width: 28,
                                                                height: 28,
                                                                fit: BoxFit.cover,
                                                              ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(ing.name,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(fontSize: 12)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tổng: ${_formatCurrency(order.totalPrice)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

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
