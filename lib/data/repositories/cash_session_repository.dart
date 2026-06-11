// lib/data/repositories/cash_session_repository.dart
// Repositorio para operaciones de sesiones de caja.

import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import '../models/cash_session.dart';
import '../models/cash_movement.dart';

class CashSessionRepository {
  final PowerSyncDatabase db;
  final String businessId;

  const CashSessionRepository({required this.db, required this.businessId});

  // ── Streams ──────────────────────────────────────────────────────────────

  Stream<CashSession?> watchOpenSession() {
    return db.watch('''
      SELECT * FROM cash_sessions 
      WHERE business_id = ? AND status = 'open'
      LIMIT 1
    ''', parameters: [businessId]).map(
      (rs) => rs.isEmpty ? null : CashSession.fromRow(rs.first),
    );
  }

  Stream<List<CashMovement>> watchSessionMovements(String sessionId) {
    return db.watch('''
      SELECT * FROM cash_movements 
      WHERE cash_session_id = ?
      ORDER BY created_at DESC
    ''', parameters: [sessionId]).map(
      (rs) => rs.map(CashMovement.fromRow).toList(),
    );
  }

  // ── Futures ──────────────────────────────────────────────────────────────

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
  /// Fórmula: apertura + ventas en efectivo + entradas − salidas
  ///
  /// FIX ARCH-5: eliminada la variable `session` que se creaba y descartaba
  /// inmediatamente sin usarse nunca.
  Future<double> calculateExpectedAmount(String sessionId) async {
    try {
      final sessionResult = await db.execute('''
        SELECT opening_amount FROM cash_sessions 
        WHERE id = ? AND business_id = ?
      ''', [sessionId, businessId]);

      if (sessionResult.isEmpty) return 0;
      final openingAmount = (sessionResult.first['opening_amount'] as num).toDouble();

      final salesResult = await db.execute('''
        SELECT COALESCE(SUM(total), 0.0) as total FROM sales 
        WHERE cash_session_id = ? AND payment_method = 'cash' AND status = 'completed'
      ''', [sessionId]);
      final cashSales = (salesResult.first['total'] as num).toDouble();

      final movementsResult = await db.execute('''
        SELECT 
          COALESCE(SUM(CASE WHEN movement_type = 'in'  THEN amount ELSE 0 END), 0.0) as total_in,
          COALESCE(SUM(CASE WHEN movement_type = 'out' THEN amount ELSE 0 END), 0.0) as total_out
        FROM cash_movements WHERE cash_session_id = ?
      ''', [sessionId]);

      final totalIn  = (movementsResult.first['total_in']  as num).toDouble();
      final totalOut = (movementsResult.first['total_out'] as num).toDouble();

      return openingAmount + cashSales + totalIn - totalOut;
    } catch (e, stack) {
      debugPrint('CashSessionRepository.calculateExpectedAmount: $e\n$stack');
      rethrow;
    }
  }

  // ── Escritura ─────────────────────────────────────────────────────────────

  Future<void> openSession(double openingAmount, {String? workerId}) async {
    try {
      final openSession = await getOpenSession();
      if (openSession != null) {
        throw Exception('Ya existe una sesion de caja abierta');
      }
      final now = DateTime.now().toIso8601String();
      await db.execute('''
        INSERT INTO cash_sessions (
          id, business_id, worker_id, opening_amount, status, opened_at, updated_at
        ) VALUES (?, ?, ?, ?, 'open', ?, ?)
      ''', [const Uuid().v4(), businessId, workerId, openingAmount, now, now]);
    } catch (e, stack) {
      debugPrint('CashSessionRepository.openSession: $e\n$stack');
      rethrow;
    }
  }

  Future<void> closeSession(String sessionId, double closingAmount) async {
    try {
      final expectedAmount = await calculateExpectedAmount(sessionId);
      final difference     = closingAmount - expectedAmount;
      final now            = DateTime.now().toIso8601String();
      await db.execute('''
        UPDATE cash_sessions SET
          closing_amount  = ?,
          expected_amount = ?,
          difference      = ?,
          status          = 'closed',
          closed_at       = ?,
          updated_at      = ?
        WHERE id = ? AND business_id = ?
      ''', [closingAmount, expectedAmount, difference, now, now, sessionId, businessId]);
    } catch (e, stack) {
      debugPrint('CashSessionRepository.closeSession: $e\n$stack');
      rethrow;
    }
  }

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
        const Uuid().v4(), businessId, sessionId,
        type == CashMovementType.in_ ? 'in' : 'out',
        amount, description, now,
      ]);
    } catch (e, stack) {
      debugPrint('CashSessionRepository.addMovement: $e\n$stack');
      rethrow;
    }
  }
}
