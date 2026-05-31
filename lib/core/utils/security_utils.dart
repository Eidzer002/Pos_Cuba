// lib/core/utils/security_utils.dart
// Utilidades de seguridad: hash de PIN, validación de formato, tokens.
// FIX BUG-01/SEC-01: el PIN NUNCA se guarda ni compara en texto plano.
//
// Uso:
//   final hash = SecurityUtils.hashPin(rawPin);   // antes de INSERT
//   final ok   = SecurityUtils.verifyPin(input, storedHash); // para auth
//   final fmt  = SecurityUtils.isValidPinFormat(pin); // antes de aceptar pin

import 'dart:convert';

import 'package:crypto/crypto.dart';

class SecurityUtils {
  // Clase de utilidades puras — no instanciar.
  SecurityUtils._();

  // ── PIN ──────────────────────────────────────────────────────────────────

  /// Hashea un PIN usando SHA-256.
  ///
  /// - Hace trim() para eliminar espacios accidentales.
  /// - SIEMPRE usar antes de guardar o comparar un PIN.
  /// - NUNCA loggear el resultado — es un hash pero puede ser reversible
  ///   con rainbow tables si el PIN es corto.
  ///
  /// Ejemplo:
  ///   SecurityUtils.hashPin('1234')
  ///   → '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4'
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  /// Verifica [inputPin] (texto plano) contra [storedHash] (SHA-256).
  ///
  /// Retorna `true` si coinciden, `false` en caso contrario.
  /// NUNCA comparar texto plano directamente — usar siempre este método.
  static bool verifyPin(String inputPin, String storedHash) {
    return hashPin(inputPin) == storedHash;
  }

  /// Valida que [pin] tenga entre 4 y 6 dígitos numéricos.
  ///
  /// Retorna `true` si el formato es válido.
  /// Llamar antes de aceptar un PIN en cualquier formulario.
  ///
  /// Ejemplos:
  ///   isValidPinFormat('1234')   → true
  ///   isValidPinFormat('123')    → false  (muy corto)
  ///   isValidPinFormat('1234567') → false (muy largo)
  ///   isValidPinFormat('12ab')   → false  (no numérico)
  static bool isValidPinFormat(String pin) {
    return RegExp(r'^\d{4,6}$').hasMatch(pin);
  }

  // ── Tokens ────────────────────────────────────────────────────────────────

  /// Hashea un token de licencia u otro valor sensible con SHA-256.
  ///
  /// Nota: los tokens se almacenan en flutter_secure_storage (SEC-02),
  /// no en SharedPreferences ni en la BD local.
  static String hashToken(String token) {
    final bytes = utf8.encode(token);
    return sha256.convert(bytes).toString();
  }
}
