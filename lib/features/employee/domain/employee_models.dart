import 'package:flutter/foundation.dart';

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

  const EmployeeDetail({
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

  const EmployeeOrderSummary({
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
        count += st.items.fold<int>(0, (acc, it) => acc + it.quantity);
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

  const DishSummary({
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

  const DishStepSummary({
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
  final List<IngredientSummary> ingredients;

  const DishItemSummary({
    required this.menuItemId,
    required this.menuItemName,
    required this.imageUrl,
    required this.quantity,
    required this.price,
    required this.cal,
    this.ingredients = const [],
  });

  factory DishItemSummary.fromJson(Map<String, dynamic> j) => DishItemSummary(
        menuItemId: (j['menuItemId'] ?? 0) as int,
        menuItemName: (j['menuItemName'] ?? '') as String,
        imageUrl: (j['imageUrl'] ?? '') as String,
        quantity: (j['quantity'] ?? 0) as int,
        price: (j['price'] ?? 0) as int,
        cal: (j['cal'] ?? 0) as int,
        ingredients: ((j['ingredients'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(IngredientSummary.fromJson)
            .toList(),
      );

}

class IngredientSummary {
  final int id;
  final String name;
  final String? description;
  final String? baseUnit;
  final String? imageUrl;

  const IngredientSummary({
    required this.id,
    required this.name,
    this.description,
    this.baseUnit,
    this.imageUrl,
  });

  factory IngredientSummary.fromJson(Map<String, dynamic> j) => IngredientSummary(
        id: (j['id'] ?? 0) as int,
        name: (j['name'] ?? '') as String,
        description: j['description'] as String?,
        baseUnit: j['baseUnit'] as String?,
        imageUrl: j['imageUrl'] as String?,
      );
}
