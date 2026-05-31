// lib/data/repositories/report_repository.dart
// Repositorio para consultas de reportes y dashboard.
// REGLA: Los totales SIEMPRE vienen de la BD — nunca de variables en memoria.

import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import '../../core/utils/pos_date_utils.dart';

// ---------------------------------------------------------------------------
// Modelos de datos
// ---------------------------------------------------------------------------

/// KPIs del dashboard (hoy o rango de fechas).
class DashboardData {
  final double totalSales;
  final double totalProfit;
  final double totalCommission;
  final double totalTransfers;
  final double totalCash;
  final double totalDiscounts;
  final int transactionCount;

  const DashboardData({
    required this.totalSales,
    required this.totalProfit,
    required this.totalCommission,
    required this.totalTransfers,
    required this.totalCash,
    this.totalDiscounts = 0,
    required this.transactionCount,
  });

  factory DashboardData.empty() => const DashboardData(
        totalSales: 0,
        totalProfit: 0,
        totalCommission: 0,
        totalTransfers: 0,
        totalCash: 0,
        totalDiscounts: 0,
        transactionCount: 0,
      );

  factory DashboardData.fromRow(ResultRow row) {
    return DashboardData(
      totalSales: (row['total_sales'] as num?)?.toDouble() ?? 0,
      totalProfit: (row['total_profit'] as num?)?.toDouble() ?? 0,
      totalCommission: (row['total_commission'] as num?)?.toDouble() ?? 0,
      totalTransfers: (row['total_transfers'] as num?)?.toDouble() ?? 0,
      totalCash: (row['total_cash'] as num?)?.toDouble() ?? 0,
      totalDiscounts: (row['total_discounts'] as num?)?.toDouble() ?? 0,
      transactionCount: (row['transaction_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Datos diarios para la gráfica de 7 días.
class DailySalesData {
  final String saleDate; // 'YYYY-MM-DD'
  final double dailyTotal;
  final double dailyProfit;
  final int transactionCount;

  const DailySalesData({
    required this.saleDate,
    required this.dailyTotal,
    required this.dailyProfit,
    required this.transactionCount,
  });

  factory DailySalesData.fromRow(ResultRow row) {
    return DailySalesData(
      saleDate: row['sale_date'] as String,
      dailyTotal: (row['daily_total'] as num?)?.toDouble() ?? 0,
      dailyProfit: (row['daily_profit'] as num?)?.toDouble() ?? 0,
      transactionCount: (row['transaction_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Top 10 productos más vendidos.
class TopProductData {
  final String productName;
  final int totalQuantity;
  final double totalRevenue;
  final double totalProfit;

  const TopProductData({
    required this.productName,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.totalProfit,
  });

  factory TopProductData.fromRow(ResultRow row) {
    return TopProductData(
      productName: row['product_name'] as String,
      totalQuantity: (row['total_quantity'] as num?)?.toInt() ?? 0,
      totalRevenue: (row['total_revenue'] as num?)?.toDouble() ?? 0,
      totalProfit: (row['total_profit'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Resumen de ventas por trabajador.
class WorkerSalesData {
  final String workerId;
  final String workerName;
  final int transactionCount;
  final double totalSales;
  final double totalCommission;

  const WorkerSalesData({
    required this.workerId,
    required this.workerName,
    required this.transactionCount,
    required this.totalSales,
    required this.totalCommission,
  });

  factory WorkerSalesData.fromRow(ResultRow row) {
    return WorkerSalesData(
      workerId: row['worker_id'] as String? ?? '',
      workerName: row['worker_name'] as String? ?? 'Sin asignar',
      transactionCount: (row['transaction_count'] as num?)?.toInt() ?? 0,
      totalSales: (row['total_sales'] as num?)?.toDouble() ?? 0,
      totalCommission: (row['total_commission'] as num?)?.toDouble() ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Repositorio
// ---------------------------------------------------------------------------

class ReportRepository {
  final PowerSyncDatabase db;
  final String businessId;

  const ReportRepository({
    required this.db,
    required this.businessId,
  });

  // ==========================================================================
  // Dashboard — hoy
  // ==========================================================================

  /// Stream reactivo de KPIs del día actual.
  /// Se actualiza automáticamente con cada venta nueva (PowerSync).
  Stream<DashboardData> watchTodayStats() {
    final range = POSDateUtils.getToday();
    return db.watch('''
      SELECT
        COALESCE(SUM(total), 0.0)            AS total_sales,
        COALESCE(SUM(profit), 0.0)           AS total_profit,
        COALESCE(SUM(worker_commission), 0.0) AS total_commission,
        COALESCE(SUM(CASE WHEN payment_method = 'transfer' THEN total ELSE 0 END), 0.0) AS total_transfers,
        COALESCE(SUM(CASE WHEN payment_method = 'cash'     THEN total ELSE 0 END), 0.0) AS total_cash,
        COALESCE(SUM(discount_amount), 0.0)  AS total_discounts,
        COUNT(*) AS transaction_count
      FROM sales
      WHERE business_id = ?
        AND status = 'completed'
        AND created_at BETWEEN ? AND ?
    ''', parameters: [businessId, range.start, range.end]).map(
      (rs) => rs.isEmpty ? DashboardData.empty() : DashboardData.fromRow(rs.first),
    );
  }

  /// Datos para la gráfica de barras de los últimos 7 días.
  Future<List<DailySalesData>> getLast7DaysData() async {
    try {
      final results = await db.execute('''
        SELECT
          date(created_at) AS sale_date,
          COALESCE(SUM(total), 0.0)  AS daily_total,
          COALESCE(SUM(profit), 0.0) AS daily_profit,
          COUNT(*) AS transaction_count
        FROM sales
        WHERE business_id = ?
          AND status = 'completed'
          AND created_at >= date('now', '-6 days')
        GROUP BY date(created_at)
        ORDER BY sale_date ASC
      ''', [businessId]);
      return results.map(DailySalesData.fromRow).toList();
    } catch (e, stack) {
      debugPrint('ReportRepository.getLast7DaysData: $e\n$stack');
      rethrow;
    }
  }

  // ==========================================================================
  // Reportes por rango de fechas
  // ==========================================================================

  /// Resumen financiero completo por rango de fechas.
  /// [paymentMethod] null = todos, 'cash' | 'transfer' para filtrar.
  Future<DashboardData> getReportByDateRange(
    DateTime from,
    DateTime to, {
    String? paymentMethod,
  }) async {
    try {
      final range = POSDateUtils.getDateRange(from, to);
      final paymentClause =
          paymentMethod != null ? "AND payment_method = '$paymentMethod'" : '';

      final results = await db.execute('''
        SELECT
          COALESCE(SUM(total), 0.0)             AS total_sales,
          COALESCE(SUM(profit), 0.0)            AS total_profit,
          COALESCE(SUM(worker_commission), 0.0) AS total_commission,
          COALESCE(SUM(CASE WHEN payment_method = 'transfer' THEN total ELSE 0 END), 0.0) AS total_transfers,
          COALESCE(SUM(CASE WHEN payment_method = 'cash'     THEN total ELSE 0 END), 0.0) AS total_cash,
          COALESCE(SUM(discount_amount), 0.0)   AS total_discounts,
          COUNT(*) AS transaction_count
        FROM sales
        WHERE business_id = ?
          AND status = 'completed'
          AND created_at BETWEEN ? AND ?
          $paymentClause
      ''', [businessId, range.start, range.end]);

      return results.isEmpty ? DashboardData.empty() : DashboardData.fromRow(results.first);
    } catch (e, stack) {
      debugPrint('ReportRepository.getReportByDateRange: $e\n$stack');
      rethrow;
    }
  }

  /// Top 10 productos más vendidos en el rango.
  Future<List<TopProductData>> getTopProducts(DateTime from, DateTime to) async {
    try {
      final range = POSDateUtils.getDateRange(from, to);
      final results = await db.execute('''
        SELECT
          si.product_name,
          SUM(si.quantity)    AS total_quantity,
          SUM(si.line_total)  AS total_revenue,
          SUM(si.line_profit) AS total_profit
        FROM sale_items si
        INNER JOIN sales s ON s.id = si.sale_id
        WHERE s.business_id = ?
          AND s.status = 'completed'
          AND s.created_at BETWEEN ? AND ?
        GROUP BY si.product_name
        ORDER BY total_quantity DESC
        LIMIT 10
      ''', [businessId, range.start, range.end]);
      return results.map(TopProductData.fromRow).toList();
    } catch (e, stack) {
      debugPrint('ReportRepository.getTopProducts: $e\n$stack');
      rethrow;
    }
  }

  /// Ventas por categoría → para gráfica de torta.
  Future<Map<String, double>> getSalesByCategory(DateTime from, DateTime to) async {
    try {
      final range = POSDateUtils.getDateRange(from, to);
      final results = await db.execute('''
        SELECT
          COALESCE(c.name, 'Sin Categoría') AS category_name,
          SUM(si.line_total) AS total_sales
        FROM sale_items si
        INNER JOIN sales s ON s.id = si.sale_id
        LEFT JOIN products p ON p.id = si.product_id
        LEFT JOIN categories c ON c.id = p.category_id
        WHERE s.business_id = ?
          AND s.status = 'completed'
          AND s.created_at BETWEEN ? AND ?
        GROUP BY c.name
        ORDER BY total_sales DESC
      ''', [businessId, range.start, range.end]);

      return Map.fromEntries(
        results.map((row) => MapEntry(
              row['category_name'] as String,
              (row['total_sales'] as num).toDouble(),
            )),
      );
    } catch (e, stack) {
      debugPrint('ReportRepository.getSalesByCategory: $e\n$stack');
      rethrow;
    }
  }

  /// Ventas por trabajador en el rango.
  Future<List<WorkerSalesData>> getSalesByWorker(DateTime from, DateTime to) async {
    try {
      final range = POSDateUtils.getDateRange(from, to);
      final results = await db.execute('''
        SELECT
          s.worker_id,
          COALESCE(w.name, 'Sin asignar') AS worker_name,
          COUNT(*) AS transaction_count,
          SUM(s.total) AS total_sales,
          SUM(s.worker_commission) AS total_commission
        FROM sales s
        LEFT JOIN workers w ON w.id = s.worker_id
        WHERE s.business_id = ?
          AND s.status = 'completed'
          AND s.created_at BETWEEN ? AND ?
        GROUP BY s.worker_id
        ORDER BY total_sales DESC
      ''', [businessId, range.start, range.end]);
      return results.map(WorkerSalesData.fromRow).toList();
    } catch (e, stack) {
      debugPrint('ReportRepository.getSalesByWorker: $e\n$stack');
      rethrow;
    }
  }

  // ==========================================================================
  // Exportación CSV
  // ==========================================================================

  /// Genera string CSV de ventas en el rango. Guardar o compartir con Share.
  Future<String> exportSalesToCsv(DateTime from, DateTime to) async {
    try {
      final range = POSDateUtils.getDateRange(from, to);
      final rows = await db.execute('''
        SELECT
          s.id,
          s.created_at,
          s.total,
          s.subtotal,
          s.discount_amount,
          s.profit,
          s.worker_commission,
          s.payment_method,
          s.status,
          COALESCE(w.name, 'Sin asignar') AS worker_name,
          GROUP_CONCAT(si.product_name || ' (x' || si.quantity || ')', '; ') AS items
        FROM sales s
        LEFT JOIN workers w ON w.id = s.worker_id
        LEFT JOIN sale_items si ON si.sale_id = s.id
        WHERE s.business_id = ?
          AND s.created_at BETWEEN ? AND ?
        GROUP BY s.id
        ORDER BY s.created_at DESC
      ''', [businessId, range.start, range.end]);

      final buffer = StringBuffer();
      // Encabezado
      buffer.writeln(
          'ID,Fecha,Trabajador,Productos,Total,Subtotal,Descuento,Ganancia,Comisión,Método,Estado');
      // Filas
      for (final row in rows) {
        final items = (row['items'] as String? ?? '').replaceAll('"', '""');
        buffer.writeln([
          row['id'],
          '"${row['created_at']}"',
          '"${row['worker_name']}"',
          '"$items"',
          (row['total'] as num).toStringAsFixed(2),
          (row['subtotal'] as num).toStringAsFixed(2),
          (row['discount_amount'] as num?)?.toStringAsFixed(2) ?? '0.00',
          (row['profit'] as num).toStringAsFixed(2),
          (row['worker_commission'] as num?)?.toStringAsFixed(2) ?? '0.00',
          row['payment_method'],
          row['status'],
        ].join(','));
      }
      return buffer.toString();
    } catch (e, stack) {
      debugPrint('ReportRepository.exportSalesToCsv: $e\n$stack');
      rethrow;
    }
  }
}
