// lib/presentation/widgets/common/product_card.dart
// Tarjeta de producto reutilizable para la pantalla de ventas.
// BUG-04: currencySymbol siempre viene del businessProvider, nunca hardcodeado.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product.dart';
import '../../../providers/business_provider.dart';

/// Tarjeta de producto para la grilla de ventas.
///
/// - Muestra imagen local [Image.file] si [product.imagePath] no es null,
///   de lo contrario muestra un icono genérico.
/// - Precio formateado con [currencySymbol] del negocio (BUG-04).
/// - Stock agotado: opacidad 50%, [onTap] deshabilitado.
/// - Stock bajo: texto "Stock bajo: N" en naranja.
/// - Área táctil mínima 48×48 px (accesibilidad).
class ProductCard extends ConsumerWidget {
  final Product product;

  /// Callback al pulsar la tarjeta. Si es null se deshabilita el toque.
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencySymbol = ref.watch(currencySymbolProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bool outOfStock = product.stock <= 0;
    final bool isLowStock = product.isLowStock && !outOfStock;

    // Desactiva el tap si no hay stock o si el padre no pasó callback.
    final VoidCallback? effectiveTap = outOfStock ? null : onTap;

    Widget card = Card(
      elevation: outOfStock ? 0 : 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLowStock
            ? BorderSide(color: Colors.orange.shade400, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: effectiveTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Imagen / Ícono ─────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: _buildImage(context, cs),
            ),

            // ── Info inferior ──────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    // Precio
                    Text(
                      CurrencyFormatter.format(product.salePrice, currencySymbol),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: outOfStock ? cs.outline : cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Stock badges
                    _buildStockBadge(context, outOfStock, isLowStock),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Opacidad al 50% cuando no hay stock.
    if (outOfStock) {
      card = Opacity(opacity: 0.5, child: card);
    }

    // Área táctil mínima 48×48 px.
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: card,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildImage(BuildContext context, ColorScheme cs) {
    final imagePath = product.imagePath;

    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultIcon(cs),
      );
    }
    return _defaultIcon(cs);
  }

  Widget _defaultIcon(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 40,
          color: cs.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildStockBadge(
    BuildContext context,
    bool outOfStock,
    bool isLowStock,
  ) {
    if (outOfStock) {
      return Text(
        'Sin stock',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.red.shade600,
              fontWeight: FontWeight.w600,
            ),
      );
    }

    if (isLowStock) {
      return Text(
        'Stock bajo: ${product.stock}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w600,
            ),
      );
    }

    if (product.trackStock) {
      return Text(
        'Stock: ${product.stock}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.green.shade700,
            ),
      );
    }

    return const SizedBox.shrink();
  }
}
