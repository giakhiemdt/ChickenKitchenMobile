class KitchenOrder {
  final int id;
  final String orderNumber;
  final String? tableName;
  final String customerName;
  final String staffName;
  final DateTime createdAt;
  final String orderType; // 'dine-in', 'takeaway', 'delivery'
  final String status; // 'pending', 'preparing', 'completed'
  final List<KitchenOrderItem> items;
  final String? specialNote;

  KitchenOrder({
    required this.id,
    required this.orderNumber,
    this.tableName,
    required this.customerName,
    required this.staffName,
    required this.createdAt,
    required this.orderType,
    required this.status,
    required this.items,
    this.specialNote,
  });

  factory KitchenOrder.fromJson(Map<String, dynamic> json) {
    return KitchenOrder(
      id: json['id'] as int,
      orderNumber: json['orderNumber'] as String,
      tableName: json['tableName'] as String?,
      customerName: json['customerName'] as String,
      staffName: json['staffName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      orderType: json['orderType'] as String,
      status: json['status'] as String,
      items: (json['items'] as List)
          .map((item) => KitchenOrderItem.fromJson(item))
          .toList(),
      specialNote: json['specialNote'] as String?,
    );
  }

  // Calculate elapsed time in minutes
  int get elapsedMinutes {
    return DateTime.now().difference(createdAt).inMinutes;
  }

  // Calculate elapsed time in seconds
  int get elapsedSeconds {
    return DateTime.now().difference(createdAt).inSeconds;
  }

  // Get formatted elapsed time as MM:SS
  String get formattedElapsedTime {
    final seconds = elapsedSeconds;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Get priority color based on elapsed time
  OrderPriority get priority {
    if (elapsedMinutes < 10) return OrderPriority.normal;
    if (elapsedMinutes < 15) return OrderPriority.warning;
    return OrderPriority.urgent;
  }
}

class KitchenOrderItem {
  final int id;
  final String name;
  final int quantity;
  final List<String> customizations;
  final String? specialRequest;
  final List<String>? steps; // Các bước làm món (step by step)

  KitchenOrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.customizations,
    this.specialRequest,
    this.steps,
  });

  factory KitchenOrderItem.fromJson(Map<String, dynamic> json) {
    return KitchenOrderItem(
      id: json['id'] as int,
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      customizations: (json['customizations'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      specialRequest: json['specialRequest'] as String?,
      steps: (json['steps'] as List?)
              ?.map((e) => e.toString())
              .toList(),
    );
  }
}

enum OrderPriority {
  normal,
  warning,
  urgent,
}

enum OrderTypeFilter {
  all,
  dineIn,
  takeaway,
  delivery,
}

enum OrderStatusFilter {
  all,
  pending,
  preparing,
}
