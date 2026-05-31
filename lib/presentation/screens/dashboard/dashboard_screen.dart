// lib/presentation/screens/dashboard/dashboard_screen.dart
// Pantalla principal con resumen de ventas y KPIs.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/report_provider.dart';

/// Pantalla del dashboard con resumen de ventas.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencySymbolProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dashboard),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPIs del dia
              statsAsync.when(
                data: (stats) => _buildKpiGrid(context, stats, currency),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
              const SizedBox(height: 24),
              // Grafica de ultimos 7 dias
              Text(
                AppStrings.salesLast7Days,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildChartPlaceholder(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context, DashboardData stats, String currency) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _KpiCard(
          title: AppStrings.totalSalesToday,
          value: CurrencyFormatter.format(stats.totalSales, currency),
          icon: Icons.attach_money,
          color: Colors.green,
        ),
        _KpiCard(
          title: AppStrings.totalProfitToday,
          value: CurrencyFormatter.format(stats.totalProfit, currency),
          icon: Icons.trending_up,
          color: Colors.blue,
        ),
        _KpiCard(
          title: AppStrings.totalTransfersToday,
          value: CurrencyFormatter.format(stats.totalTransfers, currency),
          icon: Icons.swap_horiz,
          color: Colors.purple,
        ),
        _KpiCard(
          title: AppStrings.transactionsToday,
          value: stats.transactionCount.toString(),
          icon: Icons.receipt,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildChartPlaceholder(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text('Grafica de ventas (implementar con fl_chart)'),
      ),
    );
  }
}

/// Tarjeta de KPI.
class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
