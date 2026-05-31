import 'package:powersync/powersync.dart';

class Category {
  final String id;
  final String businessId;
  final String name;
  final String? colorHex;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Category({
    required this.id,
    required this.businessId,
    required this.name,
    this.colorHex,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Category.fromRow(ResultRow row) {
    return Category(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      name: row['name'] as String,
      colorHex: row['color_hex'] as String?,
      sortOrder: row['sort_order'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: row['deleted_at'] != null ? DateTime.parse(row['deleted_at'] as String) : null,
    );
  }

  Category copyWith({
    String? id,
    String? businessId,
    String? name,
    String? colorHex,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Category(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
