// lib/data/repositories/stock_movement_repository.dart
// Registra movimientos de stock (ajustes manuales, ventas, devoluciones).
// La ProductRepository ya maneja los movimientos de venta en la transacción
// de SaleRepository. Este repositorio es solo para ajustes manuales del owner.

import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

class StockMovementRepository {
  final PowerSyncDatabase db;

  StockMovementRepository(this.db);

  /// Registra un ajuste manual de stock (desde el formulario de producto).
  /// quantityChange puede ser positivo (entrada) o negativo (salida).
  Future<void> recordAdjustment({
    required String businessId,
    required String productId,
    required int quantityChange,
    required int stockAfter,
    required String notes,
    required String createdBy,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final type = quantityChange >= 0 ? 'adjustment_in' : 'adjustment_out';

      await db.execute('''
        INSERT INTO stock_movements (
          id, business_id, product_id, movement_type,
          quantity_change, stock_after, reference_id,
          notes, created_by, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?)
      ''', [
        const Uuid().v4(),
        businessId,
        productId,
        type,
        quantityChange,
        stockAfter,
        notes,
        createdBy,
        now,
      ]);
    } catch (e, stack) {
      debugPrint('StockMovementRepository.recordAdjustment: $e\n$stack');
      rethrow;
    }
  }

  /// Historial de movimientos de un producto, del más reciente al más antiguo.
  Future<List<Map<String, dynamic>>> getProductHistory({
    required String productId,
    required String businessId,
    int limit = 50,
  }) async {
    try {
      final rows = await db.execute('''
        SELECT
          id,
          movement_type,
          quantity_change,
          stock_after,
          notes,
          created_by,
          created_at
        FROM stock_movements
        WHERE product_id = ? AND business_id = ?
        ORDER BY created_at DESC
        LIMIT ?
      ''', [productId, businessId, limit]);

      return rows
          .map((r) => {
                'id': r['id'],
                'movement_type': r['movement_type'],
                'quantity_change': r['quantity_change'],
                'stock_after': r['stock_after'],
                'notes': r['notes'],
                'created_by': r['created_by'],
                'created_at': r['created_at'],
              })
          .toList();
    } catch (e, stack) {
      debugPrint('StockMovementRepository.getProductHistory: $e\n$stack');
      rethrow;
    }
  }
}
