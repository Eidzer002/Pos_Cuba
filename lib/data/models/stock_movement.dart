import 'package:powersync/powersync.dart';

class StockMovement {
  final String id;
  final String businessId;
  final String productId;
  final String movementType;
  final int quantityChange;
  final int stockAfter;
  final String? referenceId;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;

  const StockMovement({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.movementType,
    required this.quantityChange,
    required this.stockAfter,
    this.referenceId,
    this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory StockMovement.fromRow(ResultRow row) {
    return StockMovement(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      productId: row['product_id'] as String,
      movementType: row['movement_type'] as String,
      quantityChange: row['quantity_change'] as int,
      stockAfter: row['stock_after'] as int,
      referenceId: row['reference_id'] as String?,
      notes: row['notes'] as String?,
      createdBy: row['created_by'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  StockMovement copyWith({
    String? id,
    String? businessId,
    String? productId,
    String? movementType,
    int? quantityChange,
    int? stockAfter,
    String? referenceId,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return StockMovement(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      productId: productId ?? this.productId,
      movementType: movementType ?? this.movementType,
      quantityChange: quantityChange ?? this.quantityChange,
      stockAfter: stockAfter ?? this.stockAfter,
      referenceId: referenceId ?? this.referenceId,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
