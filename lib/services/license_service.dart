// lib/services/license_service.dart
// Servicio para verificacion de licencias (5 capas offline-first).

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_config.dart';

/// Estados posibles de la licencia.
enum LicenseStatus {
  valid, // Activa y verificada
  trial, // En periodo de prueba
  gracePeriod, // Vencida pero dentro del grace period
  softBlocked, // Vencida, grace period pasado, aun puede vender
  hardBlocked, // Bloqueada totalmente
}

/// Servicio para gestionar licencias.
/// 
/// Arquitectura de 5 capas:
/// 1. JWT local cifrado en flutter_secure_storage
/// 2. Verificacion en background con Edge Function
/// 3. Grace period 7 dias
/// 4. Soft block (aviso + 5 ventas mas)
/// 5. Hard block (bloqueo total)
class LicenseService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'pos_cuba_license_token';
  static const _graceStartKey = 'pos_cuba_grace_start';

  LicenseService._(); // No instanciar

  /// Verifica el estado de la licencia.
  /// 
  /// Funciona 100% offline con el JWT local.
  static Future<LicenseStatus> checkStatus() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return LicenseStatus.hardBlocked;

    final payload = _decodeJwt(token);
    if (payload == null) return LicenseStatus.hardBlocked;

    final status = payload['status'] as String? ?? 'expired';
    final now = DateTime.now();

    // Licencia activa
    if (status == 'active') {
      final paidUntil = DateTime.tryParse(payload['paid_until'] as String? ?? '');
      if (paidUntil != null && paidUntil.isAfter(now)) {
        _verifyInBackground(); // Fire and forget
        return LicenseStatus.valid;
      }
    }

    // Trial
    if (status == 'trial') {
      final trialEnds = DateTime.tryParse(payload['trial_ends_at'] as String? ?? '');
      if (trialEnds != null && trialEnds.isAfter(now)) {
        _verifyInBackground();
        return LicenseStatus.trial;
      }
    }

    // Suspendida explicitamente
    if (status == 'suspended') return LicenseStatus.hardBlocked;

    // Vencida - evaluar grace period
    return _evalGracePeriod();
  }

  /// Evalua el periodo de gracia.
  static Future<LicenseStatus> _evalGracePeriod() async {
    final graceStartStr = await _storage.read(key: _graceStartKey);
    if (graceStartStr == null) {
      // Primer dia sin licencia - iniciar grace period
      await _storage.write(
        key: _graceStartKey,
        value: DateTime.now().toIso8601String(),
      );
      return LicenseStatus.gracePeriod;
    }

    final graceStart = DateTime.parse(graceStartStr);
    final days = DateTime.now().difference(graceStart).inDays;

    if (days <= AppConfig.gracePeriodDays) return LicenseStatus.gracePeriod;
    if (days <= AppConfig.gracePeriodDays * 2) return LicenseStatus.softBlocked;
    return LicenseStatus.hardBlocked;
  }

  /// Verifica en background con la Edge Function.
  /// 
  /// Fire and forget - nunca bloquea la UI.
  static Future<void> _verifyInBackground() async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('verify-license', body: {'action': 'refresh'})
          .timeout(const Duration(seconds: 10));

      final newToken = response.data?['token'] as String?;
      if (newToken != null) {
        await _storage.write(key: _tokenKey, value: newToken);
        await _storage.delete(key: _graceStartKey); // Reiniciar grace period
      }
    } catch (_) {
      // Sin internet o Edge Function caida - continuar con token local
    }
  }

  /// Guarda un nuevo token de licencia.
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.delete(key: _graceStartKey);
  }

  /// Decodifica el payload de un JWT.
  static Map<String, dynamic>? _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final padded = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(padded));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Obtiene el token almacenado (para debugging).
  static Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  /// Limpia el token (para logout).
  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _graceStartKey);
  }
}
