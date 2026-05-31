import 'package:powersync/powersync.dart';

class CashSession {
  final String id;
  final String businessId;
  final String workerId;
  final double openingAmount;
  final double? closingAmount;
  final double? expectedAmount;
  final double? difference;
  final String status;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? notes;
  final DateTime updatedAt;

  const CashSession({
    required this.id,
    required this.businessId,
    required this.workerId,
    required this.openingAmount,
    this.closingAmount,
    this.expectedAmount,
    this.difference,
    required this.status,
    required this.openedAt,
    this.closedAt,
    this.notes,
    required this.updatedAt,
  });

  factory CashSession.fromRow(ResultRow row) {
    return CashSession(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      workerId: row['worker_id'] as String,
      openingAmount: (row['opening_amount'] as num).toDouble(),
      closingAmount: (row['closing_amount'] as num?)?.toDouble(),
      expectedAmount: (row['expected_amount'] as num?)?.toDouble(),
      difference: (row['difference'] as num?)?.toDouble(),
      status: row['status'] as String,
      openedAt: DateTime.parse(row['opened_at'] as String),
      closedAt: row['closed_at'] != null ? DateTime.parse(row['closed_at'] as String) : null,
      notes: row['notes'] as String?,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  CashSession copyWith({
    String? id,
    String? businessId,
    String? workerId,
    double? openingAmount,
    double? closingAmount,
    double? expectedAmount,
    double? difference,
    String? status,
    DateTime? openedAt,
    DateTime? closedAt,
    String? notes,
    DateTime? updatedAt,
  }) {
    return CashSession(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      workerId: workerId ?? this.workerId,
      openingAmount: openingAmount ?? this.openingAmount,
      closingAmount: closingAmount ?? this.closingAmount,
      expectedAmount: expectedAmount ?? this.expectedAmount,
      difference: difference ?? this.difference,
      status: status ?? this.status,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
