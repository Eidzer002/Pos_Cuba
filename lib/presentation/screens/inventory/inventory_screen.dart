// lib/presentation/screens/inventory/inventory_screen.dart
// Pantalla de inventario con lista de productos, búsqueda,
// importación y exportación CSV.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_movement_repository.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../services/powersync_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InventoryScreen
// ─────────────────────────────────────────────────────────────────────────────

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  bool _isProcessingCsv = false;

  // ── Exportar CSV ──────────────────────────────────────────────────────────

  Future<void> _exportCsv(List<Product> products, String currency) async {
    if (products.isEmpty) {
      _showSnack('No hay productos para exportar.', isError: true);
      return;
    }
    setState(() => _isProcessingCsv = true);
    try {
      final buffer = StringBuffer();
      // Encabezado
      buffer.writeln(
          'nombre,descripcion,precio_venta,costo,stock,stock_minimo,codigo_barras,rastrear_stock,activo');
      // Filas
      for (final p in products) {
        final row = [
          _csvField(p.name),
          _csvField(p.description ?? ''),
          p.salePrice.toStringAsFixed(2),
          p.costPrice.toStringAsFixed(2),
          p.stock.toString(),
          p.minStock.toString(),
          _csvField(p.barcode ?? ''),
          p.trackStock ? '1' : '0',
          p.isActive ? '1' : '0',
        ].join(',');
        buffer.writeln(row);
      }

      // Guardar archivo temporal
      final dir = await getTemporaryDirectory();
      final filename =
          'inventario_${DateFormatter.formatForFilename(DateTime.now())}.csv';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(buffer.toString(), encoding: utf8);

      // Compartir
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Inventario POS Cuba — $filename',
      );
    } catch (e) {
      if (mounted) _showSnack('Error al exportar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessingCsv = false);
    }
  }

  // ── Importar CSV ──────────────────────────────────────────────────────────

  Future<void> _importCsv() async {
    final business = ref.read(currentBusinessProvider).valueOrNull;
    if (business == null) return;

    // Advertencia previa
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Importar desde CSV'),
        content: const Text(
          'Se agregarán los productos del archivo CSV. '
          'Los productos existentes NO se modificarán.\n\n'
          'El CSV debe tener las columnas:\n'
          'nombre, descripcion, precio_venta, costo, '
          'stock, stock_minimo, codigo_barras, rastrear_stock, activo',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Seleccionar archivo')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isProcessingCsv = true);
    try {
      // Seleccionar archivo
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isProcessingCsv = false);
        return;
      }

      final bytes = result.files.first.bytes;
      if (bytes == null) throw Exception('No se pudo leer el archivo');

      final csvContent = utf8.decode(bytes);
      final lines = csvContent
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      if (lines.length < 2) throw Exception('El archivo está vacío o no tiene datos');

      // Saltar encabezado
      int imported = 0;
      int skipped = 0;
      final repo = ProductRepository(PowerSyncService.db);
      final stockRepo = StockMovementRepository(PowerSyncService.db);
      final now = DateTime.now();

      for (int i = 1; i < lines.length; i++) {
        final cols = _parseCsvLine(lines[i]);
        if (cols.length < 4) { skipped++; continue; }

        final name = cols[0].trim();
        if (name.isEmpty) { skipped++; continue; }

        final salePrice = double.tryParse(cols[2]) ?? 0;
        final costPrice = double.tryParse(cols[3]) ?? 0;
        final stock = int.tryParse(cols.length > 4 ? cols[4] : '0') ?? 0;
        final minStock = int.tryParse(cols.length > 5 ? cols[5] : '0') ?? 0;
        final barcode = cols.length > 6 ? cols[6].trim() : null;
        final trackStock = (cols.length > 7 ? cols[7].trim() : '1') != '0';

        final product = Product(
          id: const Uuid().v4(),
          businessId: business.id,
          categoryId: null,
          name: name,
          description: cols.length > 1 && cols[1].trim().isNotEmpty
              ? cols[1].trim()
              : null,
          salePrice: salePrice,
          costPrice: costPrice,
          stock: stock,
          minStock: minStock,
          barcode: barcode?.isEmpty == true ? null : barcode,
          trackStock: trackStock,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        await repo.createProduct(product);

        if (stock > 0 && trackStock) {
          await stockRepo.recordAdjustment(
            businessId: business.id,
            productId: product.id,
            quantityChange: stock,
            stockAfter: stock,
            notes: 'Stock inicial — importado desde CSV',
            createdBy: 'owner',
          );
        }
        imported++;
      }

      if (mounted) {
        _showSnack(
          'Importación completada: $imported productos. '
          '${skipped > 0 ? "$skipped filas omitidas." : ""}',
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Error al importar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessingCsv = false);
    }
  }

  // ── Helpers CSV ───────────────────────────────────────────────────────────

  /// Envuelve un campo en comillas si contiene coma o comillas.
  String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Parsea una línea CSV respetando campos entre comillas.
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        result.add(sb.toString());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    result.add(sb.toString());
    return result;
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError
          ? Theme.of(context).colorScheme.error
          : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencySymbolProvider);
    final productsAsync = ref.watch(productsProvider);
    final lowStockAsync = ref.watch(lowStockProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.inventory),
        actions: [
          // Menú CSV
          if (_isProcessingCsv)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Opciones',
              onSelected: (value) {
                if (value == 'import') _importCsv();
                if (value == 'export') {
                  productsAsync.whenData(
                      (p) => _exportCsv(p, currency));
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.upload_file_outlined),
                    title: Text('Importar CSV'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.download_outlined),
                    title: Text('Exportar CSV'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          // Agregar producto
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo producto',
            onPressed: () => context.push(AppRoutes.inventoryNew),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de stock bajo
          lowStockAsync.when(
            data: (products) => products.isEmpty
                ? const SizedBox.shrink()
                : _LowStockBanner(count: products.length),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: AppStrings.search,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) =>
                  ref.read(productSearchProvider.notifier).search(value),
            ),
          ),

          const SizedBox(height: 8),

          // Lista de productos
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (products) {
                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        const Text('No hay productos en el inventario.'),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => context.push(AppRoutes.inventoryNew),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar producto'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: products.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72, endIndent: 16),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _ProductListTile(
                      product: product,
                      currency: currency,
                      onTap: () =>
                          context.push(AppRoutes.productEditPath(product.id)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LowStockBanner
// ─────────────────────────────────────────────────────────────────────────────

class _LowStockBanner extends StatelessWidget {
  final int count;
  const _LowStockBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined, color: Colors.orange.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count ${AppStrings.lowStockAlert}',
              style: TextStyle(color: Colors.orange.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProductListTile
// ─────────────────────────────────────────────────────────────────────────────

class _ProductListTile extends StatelessWidget {
  final Product product;
  final String currency;
  final VoidCallback onTap;

  const _ProductListTile({
    required this.product,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockColor = product.isOutOfStock
        ? Colors.red
        : product.isLowStock
            ? Colors.orange
            : Colors.green;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: stockColor.withOpacity(0.12),
        child: Icon(Icons.inventory_2_outlined, color: stockColor, size: 20),
      ),
      title: Text(product.name,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(CurrencyFormatter.format(product.salePrice, currency),
              style: theme.textTheme.bodySmall),
          if (product.trackStock)
            Text(
              'Stock: ${product.stock}'
              '${product.isOutOfStock ? " — Agotado" : product.isLowStock ? " — Stock bajo" : ""}',
              style: theme.textTheme.bodySmall?.copyWith(color: stockColor),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      isThreeLine: product.trackStock,
      onTap: onTap,
    );
  }
}
