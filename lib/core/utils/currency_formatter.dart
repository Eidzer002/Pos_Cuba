// lib/core/utils/currency_formatter.dart
// Formateo de moneda usando el simbolo configurable del negocio.
// NUNCA hardcodear el simbolo de moneda.

import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._(); // No instanciar

  /// Formatea un monto con el simbolo de moneda del negocio
  /// 
  /// Ejemplo: format(1234.56, '\$') -> '\$ 1,234.56'
  static String format(double amount, String currencySymbol) {
    final formatter = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 2,
      locale: 'es_MX',
    );
    return formatter.format(amount);
  }

  /// Formatea sin simbolo de moneda (solo numeros)
  /// 
  /// Ejemplo: formatPlain(1234.56) -> '1,234.56'
  static String formatPlain(double amount) {
    final formatter = NumberFormat.decimalPattern('es_MX');
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;
    return formatter.format(amount);
  }

  /// Formatea con simbolo compacto para espacios reducidos
  /// 
  /// Ejemplo: formatCompact(1234567, '\$') -> '\$ 1.2M'
  static String formatCompact(double amount, String currencySymbol) {
    final formatter = NumberFormat.compactCurrency(
      symbol: currencySymbol,
      decimalDigits: 1,
      locale: 'es_MX',
    );
    return formatter.format(amount);
  }

  /// Parsea un string formateado a double
  /// 
  /// Ejemplo: parse('1,234.56') -> 1234.56
  static double? parse(String formatted) {
    try {
      final formatter = NumberFormat.decimalPattern('es_MX');
      return formatter.parse(formatted).toDouble();
    } catch (e) {
      return null;
    }
  }
}
