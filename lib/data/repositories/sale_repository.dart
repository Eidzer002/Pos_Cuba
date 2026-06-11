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

  Stream<List<Sale>> watchTodaySales() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day, 0, 0, 0);
    final end   = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);
    return db.watch('''
      SELECT * FROM sales 
      WHERE business_id = ? 
        AND status = 'completed'
        AND created_at BETWEEN ? AND ?
      ORDER BY created_at DESC
    ''', parameters: [businessId, start.toIso8601String(), end.toIso8601String()]).map(
      (rs) => rs.map(Sale.fromRow).toList(),
    );
  }

  Stream<List<Sale>> watchSalesByDateRange(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day, 0, 0, 0);
    final end   = DateTime(to.year,   to.month,   to.day,   23, 59, 59, 999);
    return db.watch('''
      SELECT * FROM sales 
      WHERE business_id = ? 
        AND status = 'completed'
        AND created_at BETWEEN ? AND ?
      ORDER BY created_at DESC
    ''', parameters: [businessId, start.toIso8601String(), end.toIso8601String()]).map(
      (rs) => rs.map(Sale.fromRow).toList(),
    );
  }

  Stream<Sale?> watchSaleWithItems(String saleId) {
    return db.watch('''
      SELECT * FROM sales WHERE id = ? AND business_id = ?
    ''', parameters: [saleId, businessId]).map(
      (rs) => rs.isEmpty ? null : Sale.fromRow(rs.first),
    );
  }

  // ============================================
  // Consultas puntuales (Future)
  // ============================================

  /// Obtiene una venta por ID. Retorna null si no existe.
  /// FIX ARCH-1: expuesto para que _ReceiptSheetState no acceda a db directamente.
  Future<Sale?> getSale(String saleId) async {
    try {
      final results = await db.execute(
        'SELECT * FROM sales WHERE id = ? AND business_id = ?',
        [saleId, businessId],
      );
      return results.isEmpty ? null : Sale.fromRow(results.first);
    } catch (e, stack) {
      debugPrint('SaleRepository.getSale: \$e\n\$stack');
      rethrow;
    }
  }

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
      debugPrint('SaleRepository.getSaleItems: \$e\n\$stack');
      rethrow;
    }
  }

  // ============================================
  // Operaciones de escritura
  // ============================================

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
    final now    = DateTime.now().toIso8601String();

    final subtotal   = items.fold<double>(0, (s, i) => s + i.lineTotal);
    final total      = subtotal - discountAmount;
    final profit     = items.fold<double>(0, (s, i) => s + i.lineProfit) - discountAmount;
    final commission = _calcCommission(worker, total);

    final lowStockProducts = <LowStockProduct>[];

    try {
      await db.writeTransaction((tx) async {
        // PASO 1: verificar y descontar stock
        for (final item in items) {
          final rows = await tx.execute('''
            SELECT stock, name FROM products WHERE id = ? AND business_id = ?
          ''', [item.productId, businessId]);

          if (rows.isEmpty) {
            throw SaleException('Producto no encontrado: \${item.productName}');
          }
          final currentStock = rows.first['stock'] as int;
          if (currentStock < item.quantity) {
            throw SaleException(
              'Stock insuficiente para "\${item.productName}". '
              'Disponible: \$currentStock, solicitado: \${item.quantity}',
            );
          }
          await tx.execute('''
            UPDATE products SET stock = stock - ?, updated_at = ?
            WHERE id = ? AND business_id = ?
          ''', [item.quantity, now, item.productId, businessId]);
        }

        // PASO 2: insertar venta
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

        // PASO 3: insertar sale_items
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

        // PASO 4: stock_movements + alertas de stock bajo
        for (final item in items) {
          final stockRows = await tx.execute('''
            SELECT stock, min_stock, track_stock, name
            FROM products WHERE id = ? AND business_id = ?
          ''', [item.productId, businessId]);

          final newStock    = stockRows.first['stock']       as int;
          final minStock    = stockRows.first['min_stock']   as int;
          final trackStock  = (stockRows.first['track_stock'] as int) == 1;
          final productName = stockRows.first['name']        as String;

          await tx.execute('''
            INSERT INTO stock_movements (
              id, business_id, product_id, movement_type, quantity_change,
              stock_after, reference_id, notes, created_by, created_at
            ) VALUES (?, ?, ?, 'sale', ?, ?, ?, 'Venta', ?, ?)
          ''', [
            const Uuid().v4(), businessId, item.productId,
            -item.quantity, newStock, saleId, workerId ?? 'system', now,
          ]);

          if (trackStock && newStock <= minStock) {
            lowStockProducts.add(LowStockProduct(
              id: item.productId, name: productName,
              stock: newStock, minStock: minStock,
            ));
          }
        }
      });

      return SaleResult(saleId: saleId, lowStockProducts: lowStockProducts);
    } catch (e, stack) {
      debugPrint('SaleRepository.processSale: \$e\n\$stack');
      rethrow;
    }
  }

  Future<void> cancelSale(String saleId, String reason) async {
    final now = DateTime.now().toIso8601String();
    try {
      await db.writeTransaction((tx) async {
        final items = await tx.execute(
          'SELECT * FROM sale_items WHERE sale_id = ? AND business_id = ?',
          [saleId, businessId],
        );
        for (final item in items) {
          final qty       = item['quantity']   as int;
          final productId = item['product_id'] as String;
          await tx.execute('''
            UPDATE products SET stock = stock + ?, updated_at = ?
            WHERE id = ? AND business_id = ?
          ''', [qty, now, productId, businessId]);
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
            'Cancelacion: \$reason', now,
          ]);
        }
        await tx.execute('''
          UPDATE sales
          SET status = 'cancelled', cancelled_at = ?, cancelled_reason = ?, updated_at = ?
          WHERE id = ? AND business_id = ?
        ''', [now, reason, now, saleId, businessId]);
      });
    } catch (e, stack) {
      debugPrint('SaleRepository.cancelSale: \$e\n\$stack');
      rethrow;
    }
  }

  double _calcCommission(Worker? worker, double total) {
    if (worker == null) return 0;
    return worker.commissionType == CommissionType.percentage
        ? total * (worker.commissionValue / 100)
        : worker.commissionValue;
  }
}
