import 'package:powersync/powersync.dart';

enum CommissionType { percentage, fixed }

class Worker {
  final String id;
  final String businessId;
  final String name;
  final String pinHash;
  final CommissionType commissionType;
  final double commissionValue;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Worker({
    required this.id,
    required this.businessId,
    required this.name,
    required this.pinHash,
    required this.commissionType,
    required this.commissionValue,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Worker.fromRow(ResultRow row) {
    return Worker(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      name: row['name'] as String,
      pinHash: row['pin_hash'] as String,
      commissionType: (row['commission_type'] as String) == 'fixed' 
          ? CommissionType.fixed 
          : CommissionType.percentage,
      commissionValue: (row['commission_value'] as num).toDouble(),
      isActive: (row['is_active'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Worker copyWith({
    String? id,
    String? businessId,
    String? name,
    String? pinHash,
    CommissionType? commissionType,
    double? commissionValue,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Worker(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      pinHash: pinHash ?? this.pinHash,
      commissionType: commissionType ?? this.commissionType,
      commissionValue: commissionValue ?? this.commissionValue,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
