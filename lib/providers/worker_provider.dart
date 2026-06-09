// lib/providers/worker_provider.dart
// Providers para trabajadores y autenticacion por PIN.

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/worker.dart';
import '../data/repositories/worker_repository.dart';
import '../services/powersync_service.dart';
import 'business_provider.dart';

part 'worker_provider.g.dart';

/// Repositorio de trabajadores (singleton por db).
@riverpod
WorkerRepository workerRepository(WorkerRepositoryRef ref) {
  return WorkerRepository(PowerSyncService.db);
}

/// Stream de trabajadores activos del negocio actual.
@riverpod
Stream<List<Worker>> activeWorkers(ActiveWorkersRef ref) {
  final businessId = ref.watch(selectedBusinessIdProvider) ?? '';
  if (businessId.isEmpty) return Stream.value([]);
  return ref.watch(workerRepositoryProvider).watchActiveWorkers(businessId);
}

/// Trabajador autenticado actualmente.
@riverpod
class CurrentWorker extends _$CurrentWorker {
  @override
  Worker? build() => null;

  void set(Worker? worker) => state = worker;
}

/// Autenticacion por PIN.
@riverpod
class WorkerAuth extends _$WorkerAuth {
  @override
  FutureOr<Worker?> build() => null;

  /// Intenta autenticar con PIN (busca por hash SHA-256 — BUG-01).
  Future<bool> authenticate(String businessId, String rawPin) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(workerRepositoryProvider);
      final worker = await repository.authenticateByPin(businessId, rawPin);
      state = AsyncValue.data(worker);
      if (worker != null) {
        ref.read(currentWorkerProvider.notifier).set(worker);
        return true;
      }
      return false;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Cierra sesion del trabajador.
  void logout() {
    state = const AsyncValue.data(null);
    ref.read(currentWorkerProvider.notifier).set(null);
  }
}

/// Operaciones CRUD de trabajadores.
@riverpod
class WorkerOperations extends _$WorkerOperations {
  @override
  FutureOr<void> build() {}

  /// Crea un nuevo trabajador. Requiere businessId del negocio activo.
  Future<void> create({
    required String businessId,
    required String name,
    required String pin,
    CommissionType commissionType = CommissionType.percentage,
    double commissionValue = 0,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(workerRepositoryProvider);
      await repository.createWorker(
        businessId: businessId,
        name: name,
        rawPin: pin,
        commissionType: commissionType,
        commissionValue: commissionValue,
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Actualiza el tipo y valor de comisión de un trabajador.
  Future<void> updateCommission({
    required String workerId,
    required String businessId,
    required CommissionType commissionType,
    required double commissionValue,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(workerRepositoryProvider).updateCommission(
        workerId: workerId,
        businessId: businessId,
        commissionType: commissionType,
        commissionValue: commissionValue,
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Cambia el PIN de un trabajador.
  Future<void> changePin({
    required String workerId,
    required String businessId,
    required String newPin,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(workerRepositoryProvider);
      await repository.changePin(
        workerId: workerId,
        businessId: businessId,
        newRawPin: newPin,
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
