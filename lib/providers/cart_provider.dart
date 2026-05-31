// lib/providers/cart_provider.dart
// Estado del carrito de ventas — Notifier con List<CartItem>.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/cart_item.dart';
import '../data/models/product.dart';

part 'cart_provider.g.dart';

// ---------------------------------------------------------------------------
// CartNotifier
// Estado: List<CartItem> (inmutable — siempre reconstruye lista)
// Métodos: addItem, removeItem, updateQuantity, clear
// Getters: total, profit, itemCount
// ---------------------------------------------------------------------------

@riverpod
class Cart extends _$Cart {
  @override
  List<CartItem> build() => const [];

  // ── Mutaciones ────────────────────────────────────────────────────────────

  /// Agrega un producto al carrito.
  /// Si ya existe, incrementa la cantidad en [quantity] (por defecto 1).
  void addItem(Product product, {int quantity = 1}) {
    assert(quantity > 0, 'La cantidad debe ser mayor a cero');

    final index = _indexOf(product.id);
    if (index != -1) {
      // Producto ya en el carrito → incrementr cantidad
      final updated = state[index].copyWith(
        quantity: state[index].quantity + quantity,
      );
      state = [
        ...state.sublist(0, index),
        updated,
        ...state.sublist(index + 1),
      ];
    } else {
      // Producto nuevo → agregar al final
      state = [
        ...state,
        CartItem(
          productId: product.id,
          productName: product.name,
          quantity: quantity,
          unitPrice: product.salePrice,
          unitCost: product.costPrice,
        ),
      ];
    }
  }

  /// Elimina completamente un item del carrito por productId.
  void removeItem(String productId) {
    state = state.where((item) => item.productId != productId).toList();
  }

  /// Actualiza la cantidad de un item.
  /// Si [quantity] <= 0, elimina el item del carrito.
  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    final index = _indexOf(productId);
    if (index == -1) return;

    final updated = state[index].copyWith(quantity: quantity);
    state = [
      ...state.sublist(0, index),
      updated,
      ...state.sublist(index + 1),
    ];
  }

  /// Vacía el carrito completamente.
  void clear() => state = const [];

  // ── Getters ───────────────────────────────────────────────────────────────

  /// Total a cobrar: suma de (quantity × unitPrice) por cada item.
  double get total =>
      state.fold(0.0, (sum, item) => sum + item.lineTotal);

  /// Ganancia estimada: suma de (quantity × (unitPrice - unitCost)) por item.
  double get profit =>
      state.fold(0.0, (sum, item) => sum + item.lineProfit);

  /// Cantidad total de unidades en el carrito.
  int get itemCount =>
      state.fold(0, (sum, item) => sum + item.quantity);

  // ── Helpers privados ──────────────────────────────────────────────────────

  int _indexOf(String productId) =>
      state.indexWhere((item) => item.productId == productId);
}
