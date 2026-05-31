import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../models/worker.dart';
import '../../core/utils/security_utils.dart';

class WorkerRepository {
  final PowerSyncDatabase db;

  WorkerRepository(this.db);

  Stream<List<Worker>> watchActiveWorkers(String businessId) {
    try {
      return db.watch(
        'SELECT * FROM workers WHERE business_id = ? AND is_active = 1 ORDER BY name ASC',
        parameters: [businessId],
      ).map((results) => results.map((row) => Worker.fromRow(row)).toList());
    } catch (e, stack) {
      debugPrint('WorkerRepository.watchActiveWorkers: $e\n$stack');
      rethrow;
    }
  }

  Future<void> createWorker({
    required String businessId,
    required String name,
    required String rawPin,
    required String commissionType,
    required double commissionValue,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final pinHash = SecurityUtils.hashPin(rawPin); // Hashea PIN antes de guardar (BUG-01)
      final id = const Uuid().v4();

      await db.execute('''
        INSERT INTO workers (
          id, business_id, name, pin_hash, commission_type, 
          commission_value, is_active, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        id,
        businessId,
        name,
        pinHash,
        commissionType,
        commissionValue,
        1,
        now,
        now,
      ]);
    } catch (e, stack) {
      debugPrint('WorkerRepository.createWorker: $e\n$stack');
      rethrow;
    }
  }

  Future<Worker?> authenticateByPin(String businessId, String rawPin) async {
    try {
      final pinHash = SecurityUtils.hashPin(rawPin); // Busca por hash, nunca en plano (BUG-01)
      
      final row = await db.getOptional(
        'SELECT * FROM workers WHERE business_id = ? AND pin_hash = ? AND is_active = 1',
        parameters: [businessId, pinHash],
      );
      
      return row != null ? Worker.fromRow(row) : null;
    } catch (e, stack) {
      debugPrint('WorkerRepository.authenticateByPin: $e\n$stack');
      rethrow;
    }
  }

  Future<void> changePin({
    required String workerId,
    required String businessId,
    required String newRawPin,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final newPinHash = SecurityUtils.hashPin(newRawPin);

      await db.execute(
        'UPDATE workers SET pin_hash = ?, updated_at = ? WHERE id = ? AND business_id = ?',
        [newPinHash, now, workerId, businessId],
      );
    } catch (e, stack) {
      debugPrint('WorkerRepository.changePin: $e\n$stack');
      rethrow;
    }
  }
}
