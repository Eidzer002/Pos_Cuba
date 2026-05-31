// lib/providers/worker_session_provider.dart
// FIX BUG-02/SEC-06: Sesión del trabajador en memoria (Riverpod).
// NUNCA persistir este estado en disco, SharedPreferences ni sessionStorage.
// Al reiniciar la app el estado vuelve a null y se pide PIN nuevamente.

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repositories/worker_repository.dart';
import '../services/powersync_service.dart';

part 'worker_session_provider.g.dart';

// ---------------------------------------------------------------------------
// Enumeración de roles
// ---------------------------------------------------------------------------

/// Rol del usuario activo en la sesión de la app.
/// - [owner]  → dueño del negocio (autenticado vía Supabase Auth)
/// - [worker] → trabajador (autenticado vía PIN hasheado, BUG-01)
enum UserRole { owner, worker }

// ---------------------------------------------------------------------------
// WorkerSessionData — datos de la sesión activa (inmutable)
// ---------------------------------------------------------------------------

@immutable
class WorkerSessionData {
  final String workerId;
  final String workerName;
  final UserRole role;

  const WorkerSessionData({
    required this.workerId,
    required this.workerName,
    required this.role,
  });

  /// Verdadero cuando el usuario activo es el dueño del negocio.
  bool get isOwner => role == UserRole.owner;

  WorkerSessionData copyWith({
    String? workerId,
    String? workerName,
    UserRole? role,
  }) {
    return WorkerSessionData(
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      role: role ?? this.role,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkerSessionData &&
          runtimeType == other.runtimeType &&
          workerId == other.workerId &&
          workerName == other.workerName &&
          role == other.role;

  @override
  int get hashCode => Object.hash(workerId, workerName, role);

  @override
  String toString() =>
      'WorkerSessionData(workerId: $workerId, workerName: $workerName, role: $role)';
}

// ---------------------------------------------------------------------------
// WorkerSession — Notifier con estado IN-MEMORY (FIX BUG-02)
// ---------------------------------------------------------------------------

@riverpod
class WorkerSession extends _$WorkerSession {
  /// Estado inicial: sin sesión. Riverpod no persiste este valor.
  @override
  WorkerSessionData? build() => null;

  // ── Autenticación por PIN ─────────────────────────────────────────────────

  /// Intenta autenticar un trabajador por PIN.
  ///
  /// - Llama a [WorkerRepository.authenticateByPin] que busca por hash SHA-256
  ///   (nunca compara texto plano — FIX BUG-01).
  /// - Si encuentra el trabajador: actualiza el estado y retorna `true`.
  /// - Si no encuentra / PIN incorrecto: deja el estado en `null`, retorna `false`.
  ///
  /// NUNCA loggear [rawPin] — ni en debugPrint.
  Future<bool> login(String businessId, String rawPin) async {
    try {
      final repo = WorkerRepository(PowerSyncService.db);
      final worker = await repo.authenticateByPin(businessId, rawPin);

      if (worker == null) {
        state = null;
        return false;
      }

      state = WorkerSessionData(
        workerId: worker.id,
        workerName: worker.name,
        role: UserRole.worker, // Los trabajadores de BD son siempre role=worker
      );
      return true;
    } catch (e, stack) {
      // No incluir rawPin en el log — SEC-01
      debugPrint('WorkerSession.login: $e\n$stack');
      state = null;
      return false;
    }
  }

  /// Establece la sesión del dueño del negocio.
  ///
  /// El dueño se autentica vía Supabase Auth (no usa PIN local).
  /// Este método lo llama el guard de navegación una vez confirmada la auth.
  void loginAsOwner({required String ownerId, required String ownerName}) {
    state = WorkerSessionData(
      workerId: ownerId,
      workerName: ownerName,
      role: UserRole.owner,
    );
  }

  // ── Cierre de sesión ──────────────────────────────────────────────────────

  /// Cierra la sesión del trabajador/dueño activo.
  /// El estado vuelve a null — la app pedirá PIN nuevamente.
  void logout() => state = null;
}
