// lib/providers/report_provider.dart
// Providers para reportes y dashboard.

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/repositories/report_repository.dart';
import '../services/powersync_service.dart';
import 'business_provider.dart';

part 'report_provider.g.dart';

/// Repositorio de reportes para el negocio actual.
@riverpod
ReportRepository reportRepository(ReportRepositoryRef ref) {
  final businessId = ref.watch(selectedBusinessIdProvider);
  if (businessId == null) {
    throw Exception('No hay negocio seleccionado');
  }
  return ReportRepository(
    db: PowerSyncService.db,
    businessId: businessId,
  );
}

/// Stream de KPIs del dashboard (hoy).
@riverpod
Stream<DashboardData> dashboardStats(DashboardStatsRef ref) {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.watchTodayStats();
}

/// Datos de ventas de los ultimos 7 dias.
@riverpod
Future<List<DailySalesData>> last7DaysData(Last7DaysDataRef ref) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getLast7DaysData();
}

/// Estado del reporte por rango.
@riverpod
class DateRangeReport extends _$DateRangeReport {
  @override
  Future<DashboardData?> build() async => null;

  Future<void> generate(DateTime from, DateTime to) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(reportRepositoryProvider);
      final data = await repository.getReportByDateRange(from, to);
      state = AsyncValue.data(data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Top productos vendidos.
@riverpod
class TopProducts extends _$TopProducts {
  @override
  Future<List<TopProductData>> build() async => [];

  Future<void> load(DateTime from, DateTime to) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(reportRepositoryProvider);
      final data = await repository.getTopProducts(from, to);
      state = AsyncValue.data(data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Ventas por categoria.
@riverpod
class SalesByCategory extends _$SalesByCategory {
  @override
  Future<Map<String, double>> build() async => {};

  Future<void> load(DateTime from, DateTime to) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(reportRepositoryProvider);
      final data = await repository.getSalesByCategory(from, to);
      state = AsyncValue.data(data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Exportacion CSV.
@riverpod
class CsvExport extends _$CsvExport {
  @override
  Future<String?> build() async => null;

  Future<void> export(DateTime from, DateTime to) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(reportRepositoryProvider);
      final csv = await repository.exportSalesToCsv(from, to);
      state = AsyncValue.data(csv);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
