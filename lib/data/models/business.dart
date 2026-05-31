import 'package:powersync/powersync.dart';

class Business {
  final String id;
  final String ownerId;
  final String name;
  final String currencySymbol;
  final String? address;
  final String? phone;
  final String? logoPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.currencySymbol,
    this.address,
    this.phone,
    this.logoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Business.fromRow(ResultRow row) {
    return Business(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      name: row['name'] as String,
      currencySymbol: row['currency_symbol'] as String,
      address: row['address'] as String?,
      phone: row['phone'] as String?,
      logoPath: row['logo_path'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Business copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? currencySymbol,
    String? address,
    String? phone,
    String? logoPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Business(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logoPath: logoPath ?? this.logoPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
