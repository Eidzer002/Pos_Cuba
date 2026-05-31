import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../models/business.dart';

class BusinessRepository {
  final PowerSyncDatabase db;

  BusinessRepository(this.db);

  Stream<Business?> watchBusiness(String ownerId) {
    try {
      return db.watch(
        'SELECT * FROM businesses WHERE owner_id = ? LIMIT 1',
        parameters: [ownerId],
      ).map((results) => results.isEmpty ? null : Business.fromRow(results.first));
    } catch (e, stack) {
      debugPrint('BusinessRepository.watchBusiness: $e\n$stack');
      rethrow;
    }
  }

  Future<Business?> getByOwnerId(String ownerId) async {
    try {
      final row = await db.getOptional(
        'SELECT * FROM businesses WHERE owner_id = ? LIMIT 1',
        parameters: [ownerId],
      );
      return row != null ? Business.fromRow(row) : null;
    } catch (e, stack) {
      debugPrint('BusinessRepository.getByOwnerId: $e\n$stack');
      rethrow;
    }
  }

  Future<Business> createBusiness(String ownerId, String name) async {
    try {
      final now = DateTime.now().toIso8601String();
      final id = const Uuid().v4();
      
      // Moneda por defecto para evitar hardcoding de acuerdo a la documentación (BUG-04)
      const defaultCurrency = 'CUP';

      await db.execute('''
        INSERT INTO businesses (
          id, owner_id, name, currency_symbol, address, phone, logo_path, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        id,
        ownerId,
        name,
        defaultCurrency,
        null, // address
        null, // phone
        null, // logo_path
        now,
        now,
      ]);

      // Recuperamos el negocio creado para devolverlo como objeto Business completo
      final row = await db.get('SELECT * FROM businesses WHERE id = ?', [id]);
      return Business.fromRow(row);
    } catch (e, stack) {
      debugPrint('BusinessRepository.createBusiness: $e\n$stack');
      rethrow;
    }
  }

  Future<void> updateBusiness(Business business) async {
    try {
      final now = DateTime.now().toIso8601String();
      
      await db.execute('''
        UPDATE businesses SET
          name = ?, currency_symbol = ?, address = ?, phone = ?, 
          logo_path = ?, updated_at = ?
        WHERE id = ? AND owner_id = ?
      ''', [
        business.name,
        business.currencySymbol,
        business.address,
        business.phone,
        business.logoPath,
        now,
        business.id,
        business.ownerId,
      ]);
    } catch (e, stack) {
      debugPrint('BusinessRepository.updateBusiness: $e\n$stack');
      rethrow;
    }
  }
}
