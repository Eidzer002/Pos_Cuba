// lib/data/repositories/backup_repository.dart
// Genera un backup completo del negocio en JSON y lo restaura.
// El JSON incluye: business, categories, products, workers,
// cash_sessions, cash_movements, sales, sale_items, stock_movements.
// licenses se excluye intencionalmente — es solo del servidor.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';

class BackupRepository {
  final PowerSyncDatabase db;

  BackupRepository(this.db);

  // ── Exportar ─────────────────────────────────────────────────────────────

  /// Genera un Map con todos los datos del negocio listos para convertir a JSON.
  Future<Map<String, dynamic>> generateBackup(String businessId) async {
    try {
      final tables = [
        'businesses',
        'categories',
        'products',
        'workers',
        'cash_sessions',
        'cash_movements',
        'sales',
        'sale_items',
        'stock_movements',
      ];

      final backup = <String, dynamic>{
        'version': 1,
        'business_id': businessId,
        'exported_at': DateTime.now().toIso8601String(),
        'app': 'POS Cuba',
      };

      for (final table in tables) {
        final rows = await db.execute(
          'SELECT * FROM $table WHERE '
          '${table == "businesses" ? "id" : "business_id"} = ?',
          [businessId],
        );
        backup[table] = rows
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }

      return backup;
    } catch (e, stack) {
      debugPrint('BackupRepository.generateBackup: $e\n$stack');
      rethrow;
    }
  }

  /// Estadísticas rápidas del backup para mostrar en el diálogo de confirmación.
  Future<Map<String, int>> getBackupStats(String businessId) async {
    try {
      final stats = <String, int>{};
      final tables = {
        'Productos': 'products',
        'Ventas': 'sales',
        'Trabajadores': 'workers',
        'Categorías': 'categories',
        'Movimientos de caja': 'cash_movements',
      };

      for (final entry in tables.entries) {
        final rows = await db.execute(
          'SELECT COUNT(*) as count FROM ${entry.value} WHERE business_id = ?',
          [businessId],
        );
        stats[entry.key] = (rows.first['count'] as num?)?.toInt() ?? 0;
      }

      return stats;
    } catch (e, stack) {
      debugPrint('BackupRepository.getBackupStats: $e\n$stack');
      rethrow;
    }
  }
}
