import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';

class ProductRepository {
  final PowerSyncDatabase db;

  ProductRepository(this.db);

  Stream<List<Product>> watchActiveProducts(String businessId) {
    try {
      return db.watch(
        'SELECT * FROM products WHERE business_id = ? AND is_active = 1 ORDER BY name ASC',
        parameters: [businessId],
      ).map((results) => results.map((row) => Product.fromRow(row)).toList());
    } catch (e, stack) {
      debugPrint('ProductRepository.watchActiveProducts: $e\n$stack');
      rethrow;
    }
  }

  Stream<List<Product>> watchLowStockProducts(String businessId) {
    try {
      return db.watch(
        'SELECT * FROM products WHERE business_id = ? AND is_active = 1 AND track_stock = 1 AND stock <= min_stock ORDER BY name ASC',
        parameters: [businessId],
      ).map((results) => results.map((row) => Product.fromRow(row)).toList());
    } catch (e, stack) {
      debugPrint('ProductRepository.watchLowStockProducts: $e\n$stack');
      rethrow;
    }
  }

  Future<Product?> getProductById(String id, String businessId) async {
    try {
      final row = await db.getOptional(
        'SELECT * FROM products WHERE id = ? AND business_id = ?',
        parameters: [id, businessId],
      );
      return row != null ? Product.fromRow(row) : null;
    } catch (e, stack) {
      debugPrint('ProductRepository.getProductById: $e\n$stack');
      rethrow;
    }
  }

  Future<Product?> getProductByBarcode(String barcode, String businessId) async {
    try {
      final row = await db.getOptional(
        'SELECT * FROM products WHERE barcode = ? AND business_id = ? AND is_active = 1',
        parameters: [barcode, businessId],
      );
      return row != null ? Product.fromRow(row) : null;
    } catch (e, stack) {
      debugPrint('ProductRepository.getProductByBarcode: $e\n$stack');
      rethrow;
    }
  }

  Future<void> createProduct(Product product) async {
    try {
      final now = DateTime.now().toIso8601String();
      await db.execute('''
        INSERT INTO products (
          id, business_id, category_id, name, description, sale_price, cost_price,
          stock, min_stock, barcode, image_path, track_stock, is_active, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        product.id,
        product.businessId,
        product.categoryId,
        product.name,
        product.description,
        product.salePrice,
        product.costPrice,
        product.stock,
        product.minStock,
        product.barcode,
        product.imagePath,
        product.trackStock ? 1 : 0,
        product.isActive ? 1 : 0,
        now,
        now,
      ]);
    } catch (e, stack) {
      debugPrint('ProductRepository.createProduct: $e\n$stack');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      final now = DateTime.now().toIso8601String();
      await db.execute('''
        UPDATE products SET
          category_id = ?, name = ?, description = ?, sale_price = ?, cost_price = ?,
          stock = ?, min_stock = ?, barcode = ?, image_path = ?, track_stock = ?,
          is_active = ?, updated_at = ?
        WHERE id = ? AND business_id = ?
      ''', [
        product.categoryId,
        product.name,
        product.description,
        product.salePrice,
        product.costPrice,
        product.stock,
        product.minStock,
        product.barcode,
        product.imagePath,
        product.trackStock ? 1 : 0,
        product.isActive ? 1 : 0,
        now,
        product.id,
        product.businessId,
      ]);
    } catch (e, stack) {
      debugPrint('ProductRepository.updateProduct: $e\n$stack');
      rethrow;
    }
  }

  Stream<Product?> watchProduct(String productId, String businessId) {
    try {
      return db.watch(
        'SELECT * FROM products WHERE id = ? AND business_id = ? LIMIT 1',
        parameters: [productId, businessId],
      ).map((results) => results.isEmpty ? null : Product.fromRow(results.first));
    } catch (e, stack) {
      debugPrint('ProductRepository.watchProduct: $e\n$stack');
      rethrow;
    }
  }

  Future<List<Product>> searchProducts(String query, String businessId) async {
    try {
      final results = await db.execute(
        "SELECT * FROM products WHERE business_id = ? AND is_active = 1 AND name LIKE ? ORDER BY name ASC",
        [businessId, '%$query%'],
      );
      return results.map(Product.fromRow).toList();
    } catch (e, stack) {
      debugPrint('ProductRepository.searchProducts: $e\n$stack');
      rethrow;
    }
  }

  Future<void> deactivateProduct({
    required String productId,
    required String businessId,
    required String workerId,
  }) async {
    try {
      await db.writeTransaction((tx) async {
        final now = DateTime.now().toIso8601String();

        final productRow = await tx.get(
          'SELECT stock FROM products WHERE id = ? AND business_id = ?',
          [productId, businessId],
        );
        final currentStock = productRow['stock'] as int;

        await tx.execute(
          'UPDATE products SET is_active = 0, updated_at = ? WHERE id = ? AND business_id = ?',
          [now, productId, businessId],
        );

        final movementId = const Uuid().v4();
        await tx.execute('''
          INSERT INTO stock_movements (
            id, business_id, product_id, movement_type, quantity_change,
            stock_after, created_at, created_by, notes
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          movementId,
          businessId,
          productId,
          'adjustment_out',
          0,
          currentStock,
          now,
          workerId,
          'Desactivación de producto',
        ]);
      });
    } catch (e, stack) {
      debugPrint('ProductRepository.deactivateProduct: $e\n$stack');
      rethrow;
    }
  }
}
