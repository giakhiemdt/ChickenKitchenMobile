import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobiletest/features/auth/data/auth_service.dart';
import 'package:mobiletest/features/employee/domain/employee_models.dart';

class EmployeeOrderDetailDialog extends StatefulWidget {
  final EmployeeOrderSummary order;
  const EmployeeOrderDetailDialog({super.key, required this.order});

  @override
  State<EmployeeOrderDetailDialog> createState() =>
      _EmployeeOrderDetailDialogState();
}

class _EmployeeOrderDetailDialogState extends State<EmployeeOrderDetailDialog> {
  bool _feedbackLoading = false;
  int _feedbackRating = 0;
  String _feedbackMessage = '';

  @override
  void initState() {
    super.initState();
    if (_isFeedbackStatus(widget.order.status)) {
      _fetchFeedback();
    }
  }

  static const String _fallbackItemImage =
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=400&auto=format&fit=crop';

  // Removed unused _fallbackIngredientImage to satisfy linter.

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(widget.order.status);
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
                        Text(
                          'Order #${widget.order.orderId}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          widget.order.customerName ?? 'Khách vãng lai',
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
                    child: Text(
                      widget.order.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: widget.order.dishes.length,
                itemBuilder: (context, i) {
                  final d = widget.order.dishes[i];
                  final dishTitle = d.name.isNotEmpty
                      ? d.name
                      : 'Dish #${d.dishId}';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dishTitle +
                                          (d.isCustom ? ' (custom)' : ''),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatCurrency(d.price)} • ${d.cal} cal',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (int si = 0; si < d.steps.length; si++) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border.all(color: Colors.black12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  // step order number
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: _stepColor(
                                      si,
                                      d.steps[si].stepName,
                                    ).withOpacity(.15),
                                    child: Text(
                                      '${si + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _stepColor(
                                          si,
                                          d.steps[si].stepName,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // semantic icon per step
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _stepColor(
                                        si,
                                        d.steps[si].stepName,
                                      ).withOpacity(.10),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _stepIcon(d.steps[si].stepName, si),
                                      size: 18,
                                      color: _stepColor(
                                        si,
                                        d.steps[si].stepName,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // step name label
                                  Expanded(
                                    child: Text(
                                      d.steps[si].stepName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _stepColor(
                                          si,
                                          d.steps[si].stepName,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${d.steps[si].items.length} item(s)',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
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
                                        width: 46,
                                        height: 46,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Image.asset(
                                              'assets/images/Logo.png',
                                              width: 46,
                                              height: 46,
                                              fit: BoxFit.cover,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  it.menuItemName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
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
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_formatCurrency(it.price)} • ${it.cal} cal',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          if (it.ingredients.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 8,
                                              children: [
                                                for (final ing
                                                    in it.ingredients)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.black12,
                                                      ),
                                                    ),
                                                    constraints:
                                                        const BoxConstraints(
                                                          maxWidth: 200,
                                                        ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                          child:
                                                              (ing.imageUrl !=
                                                                      null &&
                                                                  ing
                                                                      .imageUrl!
                                                                      .isNotEmpty)
                                                              ? Image.network(
                                                                  ing.imageUrl!,
                                                                  width: 26,
                                                                  height: 26,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  errorBuilder:
                                                                      (
                                                                        _,
                                                                        __,
                                                                        ___,
                                                                      ) => Image.asset(
                                                                        'assets/images/Logo.png',
                                                                        width:
                                                                            26,
                                                                        height:
                                                                            26,
                                                                        fit: BoxFit
                                                                            .cover,
                                                                      ),
                                                                )
                                                              : Image.asset(
                                                                  'assets/images/Logo.png',
                                                                  width: 26,
                                                                  height: 26,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                ),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Flexible(
                                                          child: Text(
                                                            ing.name,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 11,
                                                                ),
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
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isFeedbackStatus(widget.order.status))
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    const Text(
                      'Customer feedback',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    if (_feedbackLoading)
                      Row(
                        children: const [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Loading feedback…',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      )
                    else if (_feedbackRating <= 0 && _feedbackMessage.isEmpty)
                      const Text(
                        'No customer feedback',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          for (int i = 1; i <= 5; i++)
                            Icon(
                              i <= _feedbackRating
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16,
                              color: const Color(0xFFB71C1C),
                            ),
                          const SizedBox(width: 6),
                          Text(
                            '${_feedbackRating}/5',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (_feedbackMessage.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _feedbackMessage,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tổng: ${_formatCurrency(widget.order.totalPrice)}',
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
    // fallback palette cycling
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
    // fallback sequence icons
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

  bool _isFeedbackStatus(String status) {
    final s = status.toUpperCase();
    return s == 'COMPLETED' || s == 'DELIVERED';
  }

  Future<void> _fetchFeedback() async {
    try {
      setState(() => _feedbackLoading = true);
      final headers = await AuthService().authHeaders();
      if (headers.isEmpty || !headers.containsKey('Authorization')) {
        setState(() {
          _feedbackRating = 0;
          _feedbackMessage = '';
        });
        return;
      }
      final uri = Uri.parse(
        'https://chickenkitchen.milize-lena.space/api/orders/${widget.order.orderId}/feedback',
      );
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>?;
        final rating = (data?['rating'] as num?)?.toInt() ?? 0;
        final message = (data?['message'] as String?)?.trim() ?? '';
        if (!mounted) return;
        setState(() {
          _feedbackRating = rating;
          _feedbackMessage = message;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _feedbackRating = 0;
          _feedbackMessage = '';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedbackRating = 0;
        _feedbackMessage = '';
      });
    } finally {
      if (mounted) setState(() => _feedbackLoading = false);
    }
  }
}
