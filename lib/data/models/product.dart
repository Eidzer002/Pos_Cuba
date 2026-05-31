// lib/data/models/product.dart
import 'package:powersync/powersync.dart';

class Product {
  final String id;
  final String businessId;
  final String? categoryId; // NULLABLE — un producto puede no tener categoría
  final String name;
  final String? description;
  final double salePrice;
  final double costPrice;
  final int stock;
  final int minStock;
  final String? barcode;
  final String? imagePath;
  final bool trackStock;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Ganancia unitaria calculada
  double get profit => salePrice - costPrice;

  // Stock agotado (track_stock activo Y stock == 0)
  bool get isOutOfStock => trackStock && stock <= 0;

  // Stock bajo pero no agotado
  bool get isLowStock => trackStock && stock > 0 && stock <= minStock;

  const Product({
    required this.id,
    required this.businessId,
    this.categoryId, // nullable por defecto
    required this.name,
    this.description,
    required this.salePrice,
    required this.costPrice,
    required this.stock,
    required this.minStock,
    this.barcode,
    this.imagePath,
    required this.trackStock,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromRow(ResultRow row) {
    return Product(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      categoryId: row['category_id'] as String?, // cast nullable — no lanzar si es null
      name: row['name'] as String,
      description: row['description'] as String?,
      salePrice: (row['sale_price'] as num).toDouble(),
      costPrice: (row['cost_price'] as num).toDouble(),
      stock: (row['stock'] as num).toInt(),
      minStock: (row['min_stock'] as num).toInt(),
      barcode: row['barcode'] as String?,
      imagePath: row['image_path'] as String?,
      trackStock: (row['track_stock'] as int) == 1,
      isActive: (row['is_active'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Product copyWith({
    String? id,
    String? businessId,
    Object? categoryId = _sentinel, // Object? para poder pasar null explícitamente
    String? name,
    Object? description = _sentinel,
    double? salePrice,
    double? costPrice,
    int? stock,
    int? minStock,
    Object? barcode = _sentinel,
    Object? imagePath = _sentinel,
    bool? trackStock,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      categoryId: categoryId == _sentinel ? this.categoryId : categoryId as String?,
      name: name ?? this.name,
      description: description == _sentinel ? this.description : description as String?,
      salePrice: salePrice ?? this.salePrice,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      barcode: barcode == _sentinel ? this.barcode : barcode as String?,
      imagePath: imagePath == _sentinel ? this.imagePath : imagePath as String?,
      trackStock: trackStock ?? this.trackStock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Sentinel para distinguir null explícito de "no pasado" en copyWith
const Object _sentinel = Object();
