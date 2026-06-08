// lib/data/models/sale_result.dart
// Resultado del procesamiento de una venta, incluyendo alertas de stock bajo.

/// Producto que quedó con stock bajo o agotado tras una venta.
class LowStockProduct {
  final String id;
  final String name;
  final int stock;    // Stock actual (post-venta)
  final int minStock; // Mínimo configurado

  const LowStockProduct({
    required this.id,
    required this.name,
    required this.stock,
    required this.minStock,
  });

  /// True si el stock se agotó completamente.
  bool get isOutOfStock => stock <= 0;
}

/// Resultado de procesar una venta exitosa.
class SaleResult {
  final String saleId;

  /// Productos con track_stock=true cuyo stock cayó a minStock o menos.
  final List<LowStockProduct> lowStockProducts;

  const SaleResult({
    required this.saleId,
    this.lowStockProducts = const [],
  });

  bool get hasLowStockAlerts => lowStockProducts.isNotEmpty;
}
