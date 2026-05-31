import 'package:powersync/powersync.dart';

class CashMovement {
  final String id;
  final String businessId;
  final String cashSessionId;
  final String movementType;
  final double amount;
  final String description;
  final DateTime createdAt;

  const CashMovement({
    required this.id,
    required this.businessId,
    required this.cashSessionId,
    required this.movementType,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  factory CashMovement.fromRow(ResultRow row) {
    return CashMovement(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      cashSessionId: row['cash_session_id'] as String,
      movementType: row['movement_type'] as String,
      amount: (row['amount'] as num).toDouble(),
      description: row['description'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  CashMovement copyWith({
    String? id,
    String? businessId,
    String? cashSessionId,
    String? movementType,
    double? amount,
    String? description,
    DateTime? createdAt,
  }) {
    return CashMovement(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      cashSessionId: cashSessionId ?? this.cashSessionId,
      movementType: movementType ?? this.movementType,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
