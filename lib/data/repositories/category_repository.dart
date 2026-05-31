import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';

import '../models/category.dart';

class CategoryRepository {
  final PowerSyncDatabase db;

  CategoryRepository(this.db);

  Stream<List<Category>> watchCategories(String businessId) {
    try {
      return db.watch(
        'SELECT * FROM categories WHERE business_id = ? AND deleted_at IS NULL ORDER BY sort_order ASC',
        parameters: [businessId],
      ).map((results) => results.map((row) => Category.fromRow(row)).toList());
    } catch (e, stack) {
      debugPrint('CategoryRepository.watchCategories: $e\n$stack');
      rethrow;
    }
  }

  Future<void> createCategory(Category category) async {
    try {
      final now = DateTime.now().toIso8601String();
      await db.execute('''
        INSERT INTO categories (id, business_id, name, color_hex, sort_order, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [
        category.id,
        category.businessId,
        category.name,
        category.colorHex,
        category.sortOrder,
        now,
        now,
      ]);
    } catch (e, stack) {
      debugPrint('CategoryRepository.createCategory: $e\n$stack');
      rethrow;
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      final now = DateTime.now().toIso8601String();
      await db.execute('''
        UPDATE categories 
        SET name = ?, color_hex = ?, sort_order = ?, updated_at = ?
        WHERE id = ? AND business_id = ?
      ''', [
        category.name,
        category.colorHex,
        category.sortOrder,
        now,
        category.id,
        category.businessId,
      ]);
    } catch (e, stack) {
      debugPrint('CategoryRepository.updateCategory: $e\n$stack');
      rethrow;
    }
  }

  Future<void> deleteCategory(String id, String businessId) async {
    try {
      final countResult = await db.getOptional(
        'SELECT COUNT(*) as count FROM products WHERE category_id = ? AND business_id = ? AND is_active = 1',
        parameters: [id, businessId],
      );
      
      final count = countResult?['count'] as int? ?? 0;
      if (count > 0) {
        throw Exception('No se puede eliminar la categoría porque tiene productos activos.');
      }

      final now = DateTime.now().toIso8601String();
      await db.execute(
        'UPDATE categories SET deleted_at = ?, updated_at = ? WHERE id = ? AND business_id = ?',
        [now, now, id, businessId],
      );
    } catch (e, stack) {
      debugPrint('CategoryRepository.deleteCategory: $e\n$stack');
      rethrow;
    }
  }
}
