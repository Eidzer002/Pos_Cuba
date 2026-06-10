// lib/providers/sale_provider.dart
// Providers para ventas y carrito.

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/sale.dart' as sale_models;
import '../data/models/sale_result.dart';
import 'cart_provider.dart';

import '../data/repositories/sale_repository.dart';
import '../data/repositories/worker_repository.dart';
import '../services/powersync_service.dart';
import 'business_provider.dart';

part 'sale_provider.g.dart';

/// Repositorio de ventas para el negocio actual.
@riverpod
SaleRepository saleRepository(SaleRepositoryRef ref) {
  final businessId = ref.watch(selectedBusinessIdProvider);
  if (businessId == null) {
    throw Exception('No hay negocio seleccionado');
  }
  return SaleRepository(
    db: PowerSyncService.db,
    businessId: businessId,
  );
}

/// Stream de ventas del dia actual.
@riverpod
Stream<List<sale_models.Sale>> todaySales(TodaySalesRef ref) {
  final repository = ref.watch(saleRepositoryProvider);
  return repository.watchTodaySales();
}

/// Stream de ventas por rango de fechas.
@riverpod
Stream<List<sale_models.Sale>> salesByDateRange(
  SalesByDateRangeRef ref,
  DateTime from,
  DateTime to,
) {
  final repository = ref.watch(saleRepositoryProvider);
  return repository.watchSalesByDateRange(from, to);
}

/// Metodo de pago seleccionado.
@riverpod
class PaymentMethod extends _$PaymentMethod {
  @override
  sale_models.PaymentMethod build() => sale_models.PaymentMethod.cash;

  void set(sale_models.PaymentMethod method) => state = method;
}

/// Descuento aplicado a la venta.
@riverpod
class SaleDiscount extends _$SaleDiscount {
  @override
  double build() => 0;

  void set(double amount) => state = amount;
}

/// Procesamiento de venta (async).
/// Devuelve [SaleResult] con el id de la venta y alertas de stock bajo.
///
/// FIX BUG-1: el Worker se resuelve internamente si se provee [workerId],
/// eliminando la necesidad de pasar `worker: null` desde la UI.
@riverpod
class SaleProcessor extends _$SaleProcessor {
  @override
  FutureOr<SaleResult?> build() => null;

  Future<void> process({
    required String? workerId,
    required String? cashSessionId,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository   = ref.read(saleRepositoryProvider);
      final cart         = ref.read(cartProvider);
      final paymentMethod = ref.read(paymentMethodProvider);
      final discount     = ref.read(saleDiscountProvider);

      if (cart.isEmpty) {
        throw Exception('El carrito esta vacio');
      }

      // Resuelve el Worker completo (con commissionType/Value) si hay un trabajador activo.
      // Esto garantiza que la comisión se calcule correctamente en processSale().
      final worker = workerId != null
          ? await WorkerRepository(PowerSyncService.db).getWorkerById(workerId)
          : null;

      final result = await repository.processSale(
        workerId: workerId,
        cashSessionId: cashSessionId,
        items: cart,
        paymentMethod: paymentMethod,
        discountAmount: discount,
        worker: worker,
        notes: notes,
      );

      // Limpiar carrito y descuento después de venta exitosa
      ref.read(cartProvider.notifier).clear();
      ref.read(saleDiscountProvider.notifier).set(0);

      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
