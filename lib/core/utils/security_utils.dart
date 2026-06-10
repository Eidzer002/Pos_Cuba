// lib/core/utils/security_utils.dart
// Utilidades de seguridad: hash de PIN, validación de formato, tokens.
//
// FIX SEC-1: hashPin ahora requiere un [salt] (businessId) para prevenir
// ataques de rainbow table sobre PINs cortos (4-6 dígitos numéricos).
// El salt NO es secreto, pero hace inútiles las tablas precomputadas.
//
// ⚠️  BREAKING CHANGE: los hashes existentes sin salt son incompatibles.
//    Los trabajadores creados antes de este fix deberán restablecer su PIN.
//
// Uso:
//   final hash = SecurityUtils.hashPin(rawPin, salt: businessId);
//   final ok   = SecurityUtils.verifyPin(input, storedHash, salt: businessId);
//   final fmt  = SecurityUtils.isValidPinFormat(pin);

import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityUtils {
  SecurityUtils._();

  // ── PIN ──────────────────────────────────────────────────────────────────

  /// Hashea un PIN usando SHA-256 con [salt].
  ///
  /// El formato interno es SHA-256("salt:pin"), donde [salt] debe ser
  /// el businessId (único por negocio y disponible en autenticación).
  ///
  /// - Hace trim() al PIN para eliminar espacios accidentales.
  /// - NUNCA loggear [pin] ni el resultado.
  ///
  /// Ejemplo:
  ///   SecurityUtils.hashPin('1234', salt: 'biz-uuid')
  static String hashPin(String pin, {required String salt}) {
    final bytes = utf8.encode('$salt:${pin.trim()}');
    return sha256.convert(bytes).toString();
  }

  /// Verifica [inputPin] (texto plano) contra [storedHash] (SHA-256 con salt).
  ///
  /// Retorna true si coinciden, false en caso contrario.
  static bool verifyPin(String inputPin, String storedHash, {required String salt}) {
    return hashPin(inputPin, salt: salt) == storedHash;
  }

  /// Valida que [pin] tenga entre 4 y 6 dígitos numéricos.
  static bool isValidPinFormat(String pin) {
    return RegExp(r'^\d{4,6}$').hasMatch(pin);
  }

  // ── Tokens ────────────────────────────────────────────────────────────────

  /// Hashea un token de licencia u otro valor sensible con SHA-256.
  static String hashToken(String token) {
    final bytes = utf8.encode(token);
    return sha256.convert(bytes).toString();
  }
}
