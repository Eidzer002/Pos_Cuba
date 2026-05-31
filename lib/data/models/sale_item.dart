import 'package:powersync/powersync.dart';

class SaleItem {
  final String id;
  final String businessId;
  final String saleId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double unitCost;
  final double lineTotal;
  final double lineProfit;
  final DateTime createdAt;

  const SaleItem({
    required this.id,
    required this.businessId,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.lineTotal,
    required this.lineProfit,
    required this.createdAt,
  });

  factory SaleItem.fromRow(ResultRow row) {
    return SaleItem(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      saleId: row['sale_id'] as String,
      productId: row['product_id'] as String,
      productName: row['product_name'] as String,
      quantity: row['quantity'] as int,
      unitPrice: (row['unit_price'] as num).toDouble(),
      unitCost: (row['unit_cost'] as num).toDouble(),
      lineTotal: (row['line_total'] as num).toDouble(),
      lineProfit: (row['line_profit'] as num).toDouble(),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  SaleItem copyWith({
    String? id,
    String? businessId,
    String? saleId,
    String? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? unitCost,
    double? lineTotal,
    double? lineProfit,
    DateTime? createdAt,
  }) {
    return SaleItem(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCost: unitCost ?? this.unitCost,
      lineTotal: lineTotal ?? this.lineTotal,
      lineProfit: lineProfit ?? this.lineProfit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
