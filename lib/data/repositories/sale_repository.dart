// lib/data/repositories/sale_repository.dart
// Repositorio para operaciones de ventas (procesar, cancelar, consultar).

import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/sale_result.dart';
import '../models/worker.dart';
import '../models/cart_item.dart';

/// Excepcion especifica para errores de venta.
class SaleException implements Exception {
  final String message;
  SaleException(this.message);
  @override
  String toString() => message;
}

/// Repositorio para gestionar ventas.
class SaleRepository {
  final PowerSyncDatabase db;
  final String businessId;

  const SaleRepository({
    required this.db,
    required this.businessId,
  });

  // ============================================
  // Consultas reactivas (Streams)
  // ============================================

  /// Stream de ventas del dia actual (completadas).
  Stream<List<Sale>> watchTodaySales() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day, 0, 0, 0);
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

    return db.watch('''
      SELECT * FROM sales 
      WHERE business_id = ? 
        AND status = 'completed'
        AND created_at BETWEEN ? AND ?
      ORDER BY created_at DESC
    ''', parameters: [businessId, start.toIso8601String(), end.toIso8601String()]).map(
      (resultSet) => resultSet.map(Sale.fromRow).toList(),
    );
  }

  /// Stream de ventas por rango de fechas.
  Stream<List<Sale>> watchSalesByDateRange(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day, 0, 0, 0);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);

    return db.watch('''
      SELECT * FROM sales 
      WHERE business_id = ? 
        AND status = 'completed'
        AND created_at BETWEEN ? AND ?
      ORDER BY created_at DESC
    ''', parameters: [businessId, start.toIso8601String(), end.toIso8601String()]).map(
      (resultSet) => resultSet.map(Sale.fromRow).toList(),
    );
  }

  /// Stream de una venta especifica con sus items.
  Stream<Sale?> watchSaleWithItems(String saleId) {
    return db.watch('''
      SELECT * FROM sales 
      WHERE id = ? AND business_id = ?
    ''', parameters: [saleId, businessId]).map(
      (resultSet) => resultSet.isEmpty ? null : Sale.fromRow(resultSet.first),
    );
  }

  // ============================================
  // Consultas puntuales (Future)
  // ============================================

  /// Obtiene los items de una venta.
  Future<List<SaleItem>> getSaleItems(String saleId) async {
    try {
      final results = await db.execute('''
        SELECT * FROM sale_items 
        WHERE sale_id = ? AND business_id = ?
        ORDER BY created_at ASC
      ''', [saleId, businessId]);
      return results.map(SaleItem.fromRow).toList();
    } catch (e, stack) {
      debugPrint('SaleRepository.getSaleItems: $e\n$stack');
      rethrow;
    }
  }

  // ============================================
  // Operaciones de escritura
  // ============================================

  /// Procesa una venta atomicamente.
  ///
  /// Devuelve [SaleResult] con el id de la venta y la lista de productos
  /// cuyo stock cayó a su mínimo configurado o menos (alertas de reposición).
  ///
  /// Pasos:
  /// 1. Verificar y descontar stock (dentro de TX)
  /// 2. Insertar la venta
  /// 3. Insertar sale_items
  /// 4. Log de stock_movements + detectar stock bajo
  Future<SaleResult> processSale({
    required String? workerId,
    required String? cashSessionId,
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    double discountAmount = 0,
    Worker? worker,
    String? notes,
  }) async {
    final saleId = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    // Calcular totales ANTES de la transaccion
    final subtotal = items.fold<double>(0, (s, i) => s + i.lineTotal);
    final total = subtotal - discountAmount;
    final profit = items.fold<double>(0, (s, i) => s + i.lineProfit) - discountAmount;
    final commission = _calcCommission(worker, total);

    // Productos que caen a stock bajo tras esta venta
    final lowStockProducts = <LowStockProduct>[];

    try {
      await db.writeTransaction((tx) async {
        // PASO 1: Verificar y descontar stock (dentro de TX para evitar race condition)
        for (final item in items) {
          final rows = await tx.execute('''
            SELECT stock, name FROM products 
            WHERE id = ? AND business_id = ?
          ''', [item.productId, businessId]);

          if (rows.isEmpty) {
            throw SaleException('Producto no encontrado: ${item.productName}');
          }

          final currentStock = rows.first['stock'] as int;
          if (currentStock < item.quantity) {
            throw SaleException(
              'Stock insuficiente para "${item.productName}". '
              'Disponible: $currentStock, solicitado: ${item.quantity}',
            );
          }

          await tx.execute('''
            UPDATE products 
            SET stock = stock - ?, updated_at = ? 
            WHERE id = ? AND business_id = ?
          ''', [item.quantity, now, item.productId, businessId]);
        }

        // PASO 2: Insertar la venta
        await tx.execute('''
          INSERT INTO sales (
            id, business_id, worker_id, cash_session_id,
            total, subtotal, discount_amount, profit, worker_commission,
            payment_method, notes, status, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'completed', ?, ?)
        ''', [
          saleId, businessId, workerId, cashSessionId,
          total, subtotal, discountAmount, profit, commission,
          paymentMethod.name, notes, now, now,
        ]);

        // PASO 3: Insertar sale_items
        for (final item in items) {
          await tx.execute('''
            INSERT INTO sale_items (
              id, business_id, sale_id, product_id, product_name,
              quantity, unit_price, unit_cost, line_total, line_profit, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            const Uuid().v4(), businessId, saleId, item.productId, item.productName,
            item.quantity, item.unitPrice, item.unitCost, item.lineTotal, item.lineProfit, now,
          ]);
        }

        // PASO 4: Log de stock_movements + detectar stock bajo
        for (final item in items) {
          // Obtener stock post-venta junto a min_stock, track_stock y name
          // para registrar movimiento Y detectar alertas en una sola query.
          final stockRows = await tx.execute('''
            SELECT stock, min_stock, track_stock, name
            FROM products
            WHERE id = ? AND business_id = ?
          ''', [item.productId, businessId]);

          final newStock    = stockRows.first['stock']       as int;
          final minStock    = stockRows.first['min_stock']   as int;
          final trackStock  = (stockRows.first['track_stock'] as int) == 1;
          final productName = stockRows.first['name']        as String;

          // Registrar movimiento de stock
          await tx.execute('''
            INSERT INTO stock_movements (
              id, business_id, product_id, movement_type, quantity_change,
              stock_after, reference_id, notes, created_by, created_at
            ) VALUES (?, ?, ?, 'sale', ?, ?, ?, 'Venta', ?, ?)
          ''', [
            const Uuid().v4(), businessId, item.productId,
            -item.quantity, newStock, saleId, workerId ?? 'system', now,
          ]);

          // Detectar stock bajo: track_stock activo Y stock cayó a mínimo o menos
          if (trackStock && newStock <= minStock) {
            lowStockProducts.add(LowStockProduct(
              id: item.productId,
              name: productName,
              stock: newStock,
              minStock: minStock,
            ));
          }
        }
      });

      return SaleResult(saleId: saleId, lowStockProducts: lowStockProducts);
    } catch (e, stack) {
      debugPrint('SaleRepository.processSale: $e\n$stack');
      rethrow;
    }
  }

  /// Cancela una venta y restaura el stock.
  Future<void> cancelSale(String saleId, String reason) async {
    final now = DateTime.now().toIso8601String();

    try {
      await db.writeTransaction((tx) async {
        // Obtener items de la venta
        final items = await tx.execute(
          'SELECT * FROM sale_items WHERE sale_id = ? AND business_id = ?',
          [saleId, businessId],
        );

        // Restaurar stock de cada producto
        for (final item in items) {
          final qty       = item['quantity']   as int;
          final productId = item['product_id'] as String;

          await tx.execute('''
            UPDATE products 
            SET stock = stock + ?, updated_at = ? 
            WHERE id = ? AND business_id = ?
          ''', [qty, now, productId, businessId]);

          // Log restauracion
          final stockRows = await tx.execute(
            'SELECT stock FROM products WHERE id = ? AND business_id = ?',
            [productId, businessId],
          );

          await tx.execute('''
            INSERT INTO stock_movements (
              id, business_id, product_id, movement_type, quantity_change,
              stock_after, reference_id, notes, created_by, created_at
            ) VALUES (?, ?, ?, 'return', ?, ?, ?, ?, 'system', ?)
          ''', [
            const Uuid().v4(), businessId, productId,
            qty, stockRows.first['stock'] as int, saleId,
            'Cancelacion: $reason', now,
          ]);
        }

        // Marcar venta como cancelada
        await tx.execute('''
          UPDATE sales
          SET status = 'cancelled', cancelled_at = ?, cancelled_reason = ?, updated_at = ?
          WHERE id = ? AND business_id = ?
        ''', [now, reason, now, saleId, businessId]);
      });
    } catch (e, stack) {
      debugPrint('SaleRepository.cancelSale: $e\n$stack');
      rethrow;
    }
  }

  /// Calcula la comision para un trabajador.
  double _calcCommission(Worker? worker, double total) {
    if (worker == null) return 0;
    if (worker.commissionType == CommissionType.percentage) {
      return total * (worker.commissionValue / 100);
    }
    return worker.commissionValue; // Monto fijo
  }
}
