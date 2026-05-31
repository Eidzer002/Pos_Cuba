// lib/presentation/screens/inventory/inventory_screen.dart
// Pantalla de inventario con lista de productos.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/product_provider.dart';

/// Pantalla de inventario.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencySymbolProvider);
    final productsAsync = ref.watch(productsProvider);
    final lowStockAsync = ref.watch(lowStockProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.inventory),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push(AppRoutes.inventoryNew),
          ),
        ],
      ),
      body: Column(
        children: [
          // Alerta de stock bajo
          lowStockAsync.when(
            data: (products) => products.isEmpty
                ? const SizedBox.shrink()
                : _LowStockBanner(count: products.length),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Buscador
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: AppStrings.search,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.read(productSearchProvider.notifier).search(value);
              },
            ),
          ),
          // Lista de productos
          Expanded(
            child: productsAsync.when(
              data: (products) => _buildProductList(products, ref, currency),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(List<Product> products, WidgetRef ref, String currency) {
    if (products.isEmpty) {
      return const Center(
        child: Text('No hay productos en el inventario'),
      );
    }

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductListTile(
          product: product,
          currency: currency,
          onTap: () => context.push(AppRoutes.productEditPath(product.id)),
        );
      },
    );
  }
}

/// Banner de alerta de stock bajo.
class _LowStockBanner extends StatelessWidget {
  final int count;

  const _LowStockBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count ${AppStrings.lowStockAlert}',
              style: TextStyle(color: Colors.orange.shade800),
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: Filtrar solo productos con stock bajo
            },
            child: const Text('Ver'),
          ),
        ],
      ),
    );
  }
}

/// Tile de producto en lista.
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
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: product.isOutOfStock
            ? Colors.red.shade100
            : product.isLowStock
                ? Colors.orange.shade100
                : Colors.green.shade100,
        child: Icon(
          Icons.inventory,
          color: product.isOutOfStock
              ? Colors.red
              : product.isLowStock
                  ? Colors.orange
                  : Colors.green,
        ),
      ),
      title: Text(product.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(CurrencyFormatter.format(product.salePrice, currency)),
          if (product.trackStock)
            Text(
              'Stock: ${product.stock}',
              style: TextStyle(
                color: product.isOutOfStock
                    ? Colors.red
                    : product.isLowStock
                        ? Colors.orange
                        : Colors.green,
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
