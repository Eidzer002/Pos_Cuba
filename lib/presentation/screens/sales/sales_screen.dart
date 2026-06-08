// lib/presentation/screens/sales/sales_screen.dart
// Pantalla de ventas — grilla de productos, búsqueda, carrito y recibo.
// Material Design 3. Textos en español.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/cart_item.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/sale_item.dart';
import '../../../data/models/sale_result.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/sale_provider.dart';
import '../../../services/powersync_service.dart';
import '../../widgets/common/product_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SalesScreen
// ─────────────────────────────────────────────────────────────────────────────

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filter(List<Product> all) {
    var filtered = all;
    if (_selectedCategoryId != null) {
      filtered = filtered.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((p) => p.name.toLowerCase().contains(q)).toList();
    }
    return filtered;
  }

  void _addToCart(Product product) {
    if (product.isOutOfStock) return;
    final cartNotifier = ref.read(cartProvider.notifier);
    final currentQty = ref.read(cartProvider)
        .firstWhere((i) => i.productId == product.id,
            orElse: () => CartItem(productId: '', productName: '', quantity: 0, unitPrice: 0, unitCost: 0))
        .quantity;
    if (product.trackStock && currentQty >= product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No puedes agregar más de la cantidad en stock.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    cartNotifier.addItem(product);
  }

  void _openCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CartBottomSheet(onSaleCompleted: _onSaleCompleted),
    );
  }

  /// Muestra el recibo. Al cerrarlo, muestra alertas de stock bajo si aplica.
  void _onSaleCompleted(SaleResult result) {
    final businessId = ref.read(selectedBusinessIdProvider);
    if (businessId == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ReceiptSheet(saleId: result.saleId, businessId: businessId),
    ).then((_) {
      // Mostrar alerta de stock bajo después de que el usuario cierra el recibo
      if (!mounted || !result.hasLowStockAlerts) return;
      _showLowStockAlert(result.lowStockProducts);
    });
  }

  /// Dialog de alertas de stock bajo post-venta.
  void _showLowStockAlert(List<LowStockProduct> products) {
    if (products.isEmpty) return;
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.inventory_2_outlined,
          color: Colors.orange,
          size: 36,
        ),
        title: Text(
          products.length == 1 ? 'Stock bajo' : 'Alertas de stock',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              products.length == 1
                  ? 'Este producto necesita reposición:'
                  : 'Los siguientes productos necesitan reposición:',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            ...products.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(
                        p.isOutOfStock
                            ? Icons.remove_shopping_cart
                            : Icons.warning_amber_rounded,
                        size: 18,
                        color: p.isOutOfStock ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: p.isOutOfStock
                              ? Colors.red.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: p.isOutOfStock
                                ? Colors.red.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Text(
                          p.isOutOfStock
                              ? 'Sin stock'
                              : '${p.stock} / ${p.minStock}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: p.isOutOfStock
                                ? Colors.red.shade700
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar resultado de venta
    ref.listen<AsyncValue<SaleResult?>>(saleProcessorProvider, (_, next) {
      next.whenData((result) {
        if (result != null) _onSaleCompleted(result);
      });
      if (next.hasError) {
        final err = next.error;
        final msg = err is ProviderException ? err.error.toString() : err.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al procesar venta: $msg'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    });

    final productsAsync   = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(currentBusinessCategoriesProvider);
    final itemCount = ref.watch(
        cartProvider.select((c) => c.fold(0, (s, i) => s + i.quantity)));

    return Scaffold(
      appBar: AppBar(title: const Text('Vender'), centerTitle: false),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Buscar producto por nombre…',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Limpiar',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
              onChanged: (v) => setState(() => _searchQuery = v),
              elevation: const WidgetStatePropertyAll(1),
            ),
          ),
          _CategoryChips(
            categoriesAsync: categoriesAsync,
            selectedCategoryId: _selectedCategoryId,
            onSelected: (id) => setState(() => _selectedCategoryId = id),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (products) {
                final filtered = _filter(products);
                if (filtered.isEmpty) {
                  return _EmptyProducts(
                      hasFilters: _searchQuery.isNotEmpty || _selectedCategoryId != null);
                }
                return _ProductGrid(products: filtered, onAddToCart: _addToCart);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCart,
        tooltip: 'Ver carrito',
        child: Badge(
          label: Text('$itemCount'),
          isLabelVisible: itemCount > 0,
          child: const Icon(Icons.shopping_cart_outlined),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReceiptSheet — Recibo de venta
// ─────────────────────────────────────────────────────────────────────────────

class _ReceiptSheet extends ConsumerWidget {
  final String saleId;
  final String businessId;

  const _ReceiptSheet({required this.saleId, required this.businessId});

  Future<Map<String, dynamic>?> _loadSaleData(String businessId) async {
    final db = PowerSyncService.db;
    final saleRows = await db.execute(
      'SELECT * FROM sales WHERE id = ? AND business_id = ?',
      [saleId, businessId],
    );
    if (saleRows.isEmpty) return null;
    final sale = Sale.fromRow(saleRows.first);

    final itemRows = await db.execute(
      'SELECT * FROM sale_items WHERE sale_id = ? ORDER BY created_at ASC',
      [saleId],
    );
    final items = itemRows.map(SaleItem.fromRow).toList();

    return {'sale': sale, 'items': items};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency     = ref.watch(currencySymbolProvider);
    final businessAsync = ref.watch(currentBusinessProvider);
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: Colors.green.shade50,
              child: Column(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 48, color: Colors.green.shade700),
                  const SizedBox(height: 6),
                  Text('¡Venta completada!',
                      style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800)),
                ],
              ),
            ),

            Expanded(
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _loadSaleData(businessId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Center(child: Text('No se pudo cargar el recibo.'));
                  }

                  final sale  = snapshot.data!['sale'] as Sale;
                  final items = snapshot.data!['items'] as List<SaleItem>;
                  final businessName =
                      businessAsync.valueOrNull?.name ?? 'POS Cuba';

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: Text(businessName,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold)),
                      ),
                      Center(
                        child: Text(
                          DateFormatter.formatDateTime(sale.createdAt),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.outline),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text('Recibo #${sale.id.substring(0, 8).toUpperCase()}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: cs.outline)),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),

                      ...items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.productName} x${item.quantity}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(item.lineTotal, currency),
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          )),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),

                      if (sale.discountAmount > 0) ...[
                        _ReceiptRow(
                            label: 'Subtotal',
                            value: CurrencyFormatter.format(sale.subtotal, currency)),
                        _ReceiptRow(
                            label: 'Descuento',
                            value: '- ${CurrencyFormatter.format(sale.discountAmount, currency)}',
                            valueColor: Colors.green.shade700),
                      ],

                      _ReceiptRow(
                        label: 'TOTAL',
                        value: CurrencyFormatter.format(sale.total, currency),
                        bold: true,
                        large: true,
                      ),

                      const SizedBox(height: 8),

                      Center(
                        child: Chip(
                          avatar: Icon(
                            sale.paymentMethod == PaymentMethod.cash
                                ? Icons.payments_outlined
                                : Icons.credit_card,
                            size: 16,
                          ),
                          label: Text(
                            sale.paymentMethod == PaymentMethod.cash
                                ? 'Efectivo'
                                : 'Transferencia',
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Listo'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReceiptRow — fila de totales en el recibo
// ─────────────────────────────────────────────────────────────────────────────

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool large;
  final Color? valueColor;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.large = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = large
        ? theme.textTheme.titleLarge?.copyWith(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: valueColor)
        : theme.textTheme.bodyLarge?.copyWith(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: valueColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: large
                  ? theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)
                  : theme.textTheme.bodyLarge),
          Text(value, style: style),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CartBottomSheet
// ─────────────────────────────────────────────────────────────────────────────

class _CartBottomSheet extends ConsumerWidget {
  final ValueChanged<SaleResult> onSaleCompleted;
  const _CartBottomSheet({required this.onSaleCompleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency     = ref.watch(currencySymbolProvider);
    final cart         = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final total        = cartNotifier.total;
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart, color: cs.primary),
                  const SizedBox(width: 10),
                  Text('Carrito de venta',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (cart.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => ref.read(cartProvider.notifier).clear(),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text('Vaciar'),
                      style: TextButton.styleFrom(foregroundColor: cs.error),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: cart.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 56, color: cs.outlineVariant),
                          const SizedBox(height: 12),
                          Text('El carrito está vacío.',
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: cart.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (_, index) {
                        final item = cart[index];
                        return _CartItemTile(
                          item: item,
                          currency: currency,
                          onDecrement: () => ref.read(cartProvider.notifier)
                              .updateQuantity(item.productId, item.quantity - 1),
                          onIncrement: () => ref.read(cartProvider.notifier)
                              .updateQuantity(item.productId, item.quantity + 1),
                          onRemove: () => ref.read(cartProvider.notifier)
                              .removeItem(item.productId),
                        );
                      },
                    ),
            ),
            if (cart.isNotEmpty)
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border(
                        top: BorderSide(color: cs.outlineVariant, width: 0.5)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total a pagar:', style: theme.textTheme.titleMedium),
                          Text(
                            CurrencyFormatter.format(total, currency),
                            style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _showPaymentDialog(context, ref),
                          icon: const Icon(Icons.point_of_sale_outlined),
                          label: const Text('Finalizar venta'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Método de pago'),
        content: const Text('¿Cómo se realiza el pago?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          OutlinedButton.icon(
            icon: const Icon(Icons.credit_card),
            label: const Text('Transferencia'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              ref.read(paymentMethodProvider.notifier).set(PaymentMethod.transfer);
              ref.read(saleProcessorProvider.notifier).process(
                    workerId: null, cashSessionId: null, worker: null);
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Efectivo'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              ref.read(paymentMethodProvider.notifier).set(PaymentMethod.cash);
              ref.read(saleProcessorProvider.notifier).process(
                    workerId: null, cashSessionId: null, worker: null);
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CategoryChips, _ProductGrid, _EmptyProducts, _CartItemTile
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final AsyncValue<List<Category>> categoriesAsync;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  const _CategoryChips({
    required this.categoriesAsync,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: categoriesAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (categories) {
          if (categories.isEmpty) return const SizedBox.shrink();
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: const Text('Todos'),
                  selected: selectedCategoryId == null,
                  onSelected: (_) => onSelected(null),
                ),
              ),
              ...categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(cat.name),
                      selected: selectedCategoryId == cat.id,
                      onSelected: (selected) =>
                          onSelected(selected ? cat.id : null),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onAddToCart;

  const _ProductGrid({required this.products, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          onTap: product.isOutOfStock ? null : () => onAddToCart(product),
        );
      },
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  final bool hasFilters;
  const _EmptyProducts({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.inventory_2_outlined,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No se encontraron productos.' : 'No hay productos disponibles.',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 8),
            Text('Intenta con otra búsqueda o categoría.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final String currency;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.currency,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(item.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${CurrencyFormatter.format(item.unitPrice, currency)} c/u → ${CurrencyFormatter.format(item.lineTotal, currency)}',
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              item.quantity == 1 ? Icons.delete_outline : Icons.remove_circle_outline,
              size: 20,
              color: item.quantity == 1 ? cs.error : cs.onSurfaceVariant,
            ),
            onPressed: item.quantity == 1 ? onRemove : onDecrement,
            tooltip: item.quantity == 1 ? 'Quitar' : 'Reducir cantidad',
          ),
          Container(
            width: 28,
            alignment: Alignment.center,
            child: Text('${item.quantity}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.add_circle_outline, size: 20, color: cs.primary),
            onPressed: onIncrement,
            tooltip: 'Aumentar cantidad',
          ),
        ],
      ),
    );
  }
}
