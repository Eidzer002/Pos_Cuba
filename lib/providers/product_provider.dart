// lib/providers/product_provider.dart
// Providers para productos e inventario.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/product.dart';
import '../data/repositories/product_repository.dart';
import '../services/powersync_service.dart';
import 'business_provider.dart';

part 'product_provider.g.dart';

// ---------------------------------------------------------------------------
// Repositorio singleton — toma businessId del negocio actual.
// ---------------------------------------------------------------------------

@riverpod
ProductRepository productRepository(ProductRepositoryRef ref) {
  return ProductRepository(PowerSyncService.db);
}

// ---------------------------------------------------------------------------
// activeProductsProvider(businessId)
// Stream reactivo de productos activos filtrado por negocio.
// ---------------------------------------------------------------------------

@riverpod
Stream<List<Product>> activeProducts(
  ActiveProductsRef ref,
  String businessId,
) {
  return ref
      .watch(productRepositoryProvider)
      .watchActiveProducts(businessId);
}

// ---------------------------------------------------------------------------
// lowStockProductsProvider(businessId)
// Stream reactivo de productos con stock <= min_stock y track_stock = 1.
// ---------------------------------------------------------------------------

@riverpod
Stream<List<Product>> lowStockProducts(
  LowStockProductsRef ref,
  String businessId,
) {
  return ref
      .watch(productRepositoryProvider)
      .watchLowStockProducts(businessId);
}

// ---------------------------------------------------------------------------
// Accesos convenientes derivados del negocio actual (sin pasar businessId).
// ---------------------------------------------------------------------------

/// Todos los productos activos del negocio autenticado.
@riverpod
Stream<List<Product>> products(ProductsRef ref) {
  final businessAsync = ref.watch(currentBusinessProvider);
  final businessId = businessAsync.valueOrNull?.id ?? '';
  if (businessId.isEmpty) return Stream.value([]);

  return ref
      .watch(productRepositoryProvider)
      .watchActiveProducts(businessId);
}

/// Productos con stock bajo del negocio autenticado.
@riverpod
Stream<List<Product>> lowStock(LowStockRef ref) {
  final businessAsync = ref.watch(currentBusinessProvider);
  final businessId = businessAsync.valueOrNull?.id ?? '';
  if (businessId.isEmpty) return Stream.value([]);

  return ref
      .watch(productRepositoryProvider)
      .watchLowStockProducts(businessId);
}

/// Stream de un producto específico por ID.
@riverpod
Stream<Product?> product(ProductRef ref, String productId) {
  final businessAsync = ref.watch(currentBusinessProvider);
  final businessId = businessAsync.valueOrNull?.id ?? '';
  if (businessId.isEmpty) return Stream.value(null);

  return ref
      .watch(productRepositoryProvider)
      .watchProduct(productId, businessId);
}

// ---------------------------------------------------------------------------
// ProductSearch — búsqueda one-shot con AsyncValue.
// ---------------------------------------------------------------------------

@riverpod
class ProductSearch extends _$ProductSearch {
  @override
  Future<List<Product>> build() async => [];

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final businessId =
          ref.read(currentBusinessProvider).valueOrNull?.id ?? '';
      final results = await ref
          .read(productRepositoryProvider)
          .searchProducts(query, businessId);
      state = AsyncValue.data(results);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void clear() => state = const AsyncValue.data([]);
}

// ---------------------------------------------------------------------------
// ScannedProduct — producto encontrado por código de barras.
// ---------------------------------------------------------------------------

@riverpod
class ScannedProduct extends _$ScannedProduct {
  @override
  Future<Product?> build() async => null;

  Future<void> scan(String barcode) async {
    state = const AsyncValue.loading();
    try {
      final businessId =
          ref.read(currentBusinessProvider).valueOrNull?.id ?? '';
      final product = await ref
          .read(productRepositoryProvider)
          .getProductByBarcode(barcode, businessId);
      state = AsyncValue.data(product);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void reset() => state = const AsyncValue.data(null);
}
