// lib/providers/cashbox_provider.dart
// Providers para caja y movimientos.

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/cash_session.dart';
import '../data/models/cash_movement.dart';
import '../data/repositories/cash_session_repository.dart';
import '../services/powersync_service.dart';
import 'business_provider.dart';

part 'cashbox_provider.g.dart';

/// Repositorio de caja para el negocio actual.
@riverpod
CashSessionRepository cashSessionRepository(CashSessionRepositoryRef ref) {
  final businessId = ref.watch(selectedBusinessIdProvider);
  if (businessId == null) {
    throw Exception('No hay negocio seleccionado');
  }
  return CashSessionRepository(
    db: PowerSyncService.db,
    businessId: businessId,
  );
}

/// Stream de la sesion de caja abierta.
@riverpod
Stream<CashSession?> openSession(OpenSessionRef ref) {
  final repository = ref.watch(cashSessionRepositoryProvider);
  return repository.watchOpenSession();
}

/// Verifica si hay una sesion de caja abierta.
@riverpod
bool isCashboxOpen(IsCashboxOpenRef ref) {
  final sessionAsync = ref.watch(openSessionProvider);
  return sessionAsync.when(
    data: (session) => session != null,
    loading: () => false,
    error: (_, __) => false,
  );
}

/// Stream de movimientos de la sesion actual.
@riverpod
Stream<List<CashMovement>> sessionMovements(
  SessionMovementsRef ref,
  String sessionId,
) {
  final repository = ref.watch(cashSessionRepositoryProvider);
  return repository.watchSessionMovements(sessionId);
}

/// Operaciones de caja (async).
@riverpod
class CashboxOperations extends _$CashboxOperations {
  @override
  FutureOr<void> build() {}

  /// Abre una nueva sesion de caja.
  Future<void> open(double openingAmount, {String? workerId}) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(cashSessionRepositoryProvider);
      await repository.openSession(openingAmount, workerId: workerId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Cierra la sesion actual.
  Future<void> close(double closingAmount) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(cashSessionRepositoryProvider);
      final session = await repository.getOpenSession();
      if (session == null) {
        throw Exception('No hay sesion de caja abierta');
      }
      await repository.closeSession(session.id, closingAmount);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Agrega un movimiento de entrada.
  Future<void> addIncome(String sessionId, double amount, String description) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(cashSessionRepositoryProvider);
      await repository.addMovement(
        sessionId: sessionId,
        type: CashMovementType.in_,
        amount: amount,
        description: description,
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Agrega un movimiento de salida.
  Future<void> addExpense(String sessionId, double amount, String description) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(cashSessionRepositoryProvider);
      await repository.addMovement(
        sessionId: sessionId,
        type: CashMovementType.out,
        amount: amount,
        description: description,
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
