// lib/core/utils/date_formatter.dart
// Formateo de fechas localizado en espanol.

import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._(); // No instanciar

  /// Formato completo: 13/03/2026 14:30
  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm', 'es').format(date);
  }

  /// Formato solo fecha: 13/03/2026
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'es').format(date);
  }

  /// Formato solo hora: 14:30
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm', 'es').format(date);
  }

  /// Formato corto para graficas: Lun 13
  static String formatShortDay(DateTime date) {
    return DateFormat('EEE d', 'es').format(date);
  }

  /// Formato mes corto: Mar
  static String formatShortMonth(DateTime date) {
    return DateFormat('MMM', 'es').format(date);
  }

  /// Formato para nombres de archivos: 2026-03-13
  static String formatForFilename(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Formato ISO 8601 para la BD
  static String toIso8601(DateTime date) {
    return date.toIso8601String();
  }

  /// Parsea desde ISO 8601
  static DateTime? fromIso8601(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso);
    } catch (e) {
      return null;
    }
  }

  /// Formato relativo: Hoy, Ayer, o fecha
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return 'Hoy';
    } else if (dateDay == today.subtract(const Duration(days: 1))) {
      return 'Ayer';
    } else {
      return formatDate(date);
    }
  }
}
