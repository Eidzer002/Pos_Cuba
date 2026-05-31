// lib/data/repositories/cash_session_repository.dart
// Repositorio para operaciones de sesiones de caja.

import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import '../models/cash_session.dart';
import '../models/cash_movement.dart';

/// Repositorio para gestionar sesiones de caja y movimientos.
class CashSessionRepository {
  final PowerSyncDatabase db;
  final String businessId;

  const CashSessionRepository({
    required this.db,
    required this.businessId,
  });

  // ============================================
  // Consultas reactivas (Streams)
  // ============================================

  /// Stream de la sesion de caja abierta actual.
  Stream<CashSession?> watchOpenSession() {
    return db.watch('''
      SELECT * FROM cash_sessions 
      WHERE business_id = ? AND status = 'open'
      LIMIT 1
    ''', parameters: [businessId]).map(
      (resultSet) => resultSet.isEmpty ? null : CashSession.fromRow(resultSet.first),
    );
  }

  /// Stream de movimientos de una sesion.
  Stream<List<CashMovement>> watchSessionMovements(String sessionId) {
    return db.watch('''
      SELECT * FROM cash_movements 
      WHERE cash_session_id = ?
      ORDER BY created_at DESC
    ''', parameters: [sessionId]).map(
      (resultSet) => resultSet.map(CashMovement.fromRow).toList(),
    );
  }

  // ============================================
  // Consultas puntuales (Future)
  // ============================================

  /// Obtiene la sesion abierta actual.
  Future<CashSession?> getOpenSession() async {
    try {
      final results = await db.execute('''
        SELECT * FROM cash_sessions 
        WHERE business_id = ? AND status = 'open'
        LIMIT 1
      ''', [businessId]);
      return results.isEmpty ? null : CashSession.fromRow(results.first);
    } catch (e, stack) {
      debugPrint('CashSessionRepository.getOpenSession: $e\n$stack');
      rethrow;
    }
  }

  /// Calcula el monto esperado en caja.
  /// 
  /// Formula: apertura + ventas en efectivo + entradas - salidas
  Future<double> calculateExpectedAmount(String sessionId) async {
    try {
      // Obtener monto de apertura
      final sessionResult = await db.execute('''
        SELECT opening_amount FROM cash_sessions 
        WHERE id = ? AND business_id = ?
      ''', [sessionId, businessId]);

      if (sessionResult.isEmpty) return 0;
      final openingAmount = (sessionResult.first['opening_amount'] as num).toDouble();

      // Ventas en efectivo desde la apertura
      final session = CashSession.fromRow(sessionResult.first);
      final salesResult = await db.execute('''
        SELECT COALESCE(SUM(total), 0.0) as total FROM sales 
        WHERE cash_session_id = ? AND payment_method = 'cash' AND status = 'completed'
      ''', [sessionId]);
      final cashSales = (salesResult.first['total'] as num).toDouble();

      // Movimientos de caja
      final movementsResult = await db.execute('''
        SELECT 
          COALESCE(SUM(CASE WHEN movement_type = 'in' THEN amount ELSE 0 END), 0.0) as total_in,
          COALESCE(SUM(CASE WHEN movement_type = 'out' THEN amount ELSE 0 END), 0.0) as total_out
        FROM cash_movements 
        WHERE cash_session_id = ?
      ''', [sessionId]);

      final totalIn = (movementsResult.first['total_in'] as num).toDouble();
      final totalOut = (movementsResult.first['total_out'] as num).toDouble();

      return openingAmount + cashSales + totalIn - totalOut;
    } catch (e, stack) {
      debugPrint('CashSessionRepository.calculateExpectedAmount: $e\n$stack');
      rethrow;
    }
  }

  // ============================================
  // Operaciones de escritura
  // ============================================

  /// Abre una nueva sesion de caja.
  /// 
  /// FIX para BUG-03: Verifica que no haya otra sesion abierta.
  Future<void> openSession(double openingAmount, {String? workerId}) async {
    try {
      // Verificar que no haya sesion abierta
      final openSession = await getOpenSession();
      if (openSession != null) {
        throw Exception('Ya existe una sesion de caja abierta');
      }

      final now = DateTime.now().toIso8601String();
      await db.execute('''
        INSERT INTO cash_sessions (
          id, business_id, worker_id, opening_amount, status, opened_at, updated_at
        ) VALUES (?, ?, ?, ?, 'open', ?, ?)
      ''', [
        const Uuid().v4(),
        businessId,
        workerId,
        openingAmount,
        now,
        now,
      ]);
    } catch (e, stack) {
      debugPrint('CashSessionRepository.openSession: $e\n$stack');
      rethrow;
    }
  }

  /// Cierra la sesion de caja actual.
  Future<void> closeSession(String sessionId, double closingAmount) async {
    try {
      final expectedAmount = await calculateExpectedAmount(sessionId);
      final difference = closingAmount - expectedAmount;
      final now = DateTime.now().toIso8601String();

      await db.execute('''
        UPDATE cash_sessions SET
          closing_amount = ?,
          expected_amount = ?,
          difference = ?,
          status = 'closed',
          closed_at = ?,
          updated_at = ?
        WHERE id = ? AND business_id = ?
      ''', [
        closingAmount,
        expectedAmount,
        difference,
        now,
        now,
        sessionId,
        businessId,
      ]);
    } catch (e, stack) {
      debugPrint('CashSessionRepository.closeSession: $e\n$stack');
      rethrow;
    }
  }

  /// Agrega un movimiento de caja.
  Future<void> addMovement({
    required String sessionId,
    required CashMovementType type,
    required double amount,
    required String description,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      await db.execute('''
        INSERT INTO cash_movements (
          id, business_id, cash_session_id, movement_type, amount, description, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [
        const Uuid().v4(),
        businessId,
        sessionId,
        type == CashMovementType.in_ ? 'in' : 'out',
        amount,
        description,
        now,
      ]);
    } catch (e, stack) {
      debugPrint('CashSessionRepository.addMovement: $e\n$stack');
      rethrow;
    }
  }
}
