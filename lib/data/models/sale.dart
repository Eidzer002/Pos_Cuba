import 'package:powersync/powersync.dart';

enum PaymentMethod { cash, transfer }

class Sale {
  final String id;
  final String businessId;
  final String? workerId;
  final String? cashSessionId;
  final double total;
  final double subtotal;
  final double discountAmount;
  final double profit;
  final double workerCommission;
  final PaymentMethod paymentMethod;
  final String? notes;
  final String status;
  final DateTime? cancelledAt;
  final String? cancelledReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Sale({
    required this.id,
    required this.businessId,
    this.workerId,
    this.cashSessionId,
    required this.total,
    required this.subtotal,
    required this.discountAmount,
    required this.profit,
    required this.workerCommission,
    required this.paymentMethod,
    this.notes,
    required this.status,
    this.cancelledAt,
    this.cancelledReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Sale.fromRow(ResultRow row) {
    return Sale(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      workerId: row['worker_id'] as String?,
      cashSessionId: row['cash_session_id'] as String?,
      total: (row['total'] as num).toDouble(),
      subtotal: (row['subtotal'] as num).toDouble(),
      discountAmount: (row['discount_amount'] as num).toDouble(),
      profit: (row['profit'] as num).toDouble(),
      workerCommission: (row['worker_commission'] as num).toDouble(),
      paymentMethod: (row['payment_method'] as String) == 'transfer' ? PaymentMethod.transfer : PaymentMethod.cash,
      notes: row['notes'] as String?,
      status: row['status'] as String,
      cancelledAt: row['cancelled_at'] != null ? DateTime.parse(row['cancelled_at'] as String) : null,
      cancelledReason: row['cancelled_reason'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Sale copyWith({
    String? id,
    String? businessId,
    String? workerId,
    String? cashSessionId,
    double? total,
    double? subtotal,
    double? discountAmount,
    double? profit,
    double? workerCommission,
    PaymentMethod? paymentMethod,
    String? notes,
    String? status,
    DateTime? cancelledAt,
    String? cancelledReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Sale(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      workerId: workerId ?? this.workerId,
      cashSessionId: cashSessionId ?? this.cashSessionId,
      total: total ?? this.total,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      profit: profit ?? this.profit,
      workerCommission: workerCommission ?? this.workerCommission,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledReason: cancelledReason ?? this.cancelledReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
