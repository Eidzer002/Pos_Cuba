class CartItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double unitCost;

  const CartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
  });

  double get lineTotal => quantity * unitPrice;
  double get lineProfit => quantity * (unitPrice - unitCost);

  CartItem copyWith({
    String? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? unitCost,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCost: unitCost ?? this.unitCost,
    );
  }
}
