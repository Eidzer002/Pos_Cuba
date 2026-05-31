// lib/core/utils/pos_date_utils.dart
// Utilidades de fecha especificas para el POS.
// PORT exacto de getDayRange() de la PWA original.

class POSDateUtils {
  POSDateUtils._(); // No instanciar

  /// Retorna el inicio y fin del dia en formato ISO 8601.
  /// USAR ESTO en dashboard y reportes para garantizar coherencia.
  /// 
  /// PORT exacto de getDayRange() de index.js linea 50
  /// 
  /// Ejemplo: getDayRange(DateTime(2026, 3, 13)) ->
  ///   start: '2026-03-13T00:00:00.000Z'
  ///   end: '2026-03-13T23:59:59.999Z'
  static ({String start, String end}) getDayRange(DateTime date) {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    return (
      start: start.toIso8601String(),
      end: end.toIso8601String(),
    );
  }

  /// Retorna el rango de "hoy".
  /// 
  /// USAR ESTO para calcular los KPIs del dashboard.
  static ({String start, String end}) getToday() => getDayRange(DateTime.now());

  /// Retorna el rango entre dos fechas (inclusive).
  /// 
  /// Ejemplo: getDateRange(2026-03-01, 2026-03-13) ->
  ///   start: '2026-03-01T00:00:00.000Z'
  ///   end: '2026-03-13T23:59:59.999Z'
  static ({String start, String end}) getDateRange(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day, 0, 0, 0);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return (start: start.toIso8601String(), end: end.toIso8601String());
  }

  /// Retorna el inicio de los ultimos N dias.
  /// 
  /// Ejemplo: getLastNDaysStart(7) -> hace 7 dias a las 00:00:00
  static DateTime getLastNDaysStart(int days) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - days, 0, 0, 0);
  }

  /// Calcula el cobro del trabajador: el MAYOR entre comision acumulada y salario fijo.
  /// 
  /// PORT exacto de la logica de loadDashboardData() de index.js lineas 453-465
  /// 
  /// Ejemplo: calculateWorkerPay(accumulated: 150, fixed: 200) -> 200
  /// Ejemplo: calculateWorkerPay(accumulated: 250, fixed: 200) -> 250
  static double calculateWorkerPay({
    required double accumulatedCommission,
    required double fixedDailySalary,
  }) {
    return accumulatedCommission > fixedDailySalary
        ? accumulatedCommission
        : fixedDailySalary;
  }

  /// Verifica si una fecha esta dentro del periodo de gracia.
  static bool isWithinGracePeriod(DateTime graceStart, int graceDays) {
    final now = DateTime.now();
    final daysElapsed = now.difference(graceStart).inDays;
    return daysElapsed <= graceDays;
  }
}
