// lib/presentation/screens/dashboard/dashboard_screen.dart
// Pantalla principal con KPIs del día y gráfica de ventas últimos 7 días.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/report_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencySymbolProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final chartAsync = ref.watch(last7DaysDataProvider);
    final businessAsync = ref.watch(currentBusinessProvider);

    final businessName = businessAsync.valueOrNull?.name ?? 'POS Cuba';

    return Scaffold(
      appBar: AppBar(
        title: Text(businessName),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () {
              ref.invalidate(dashboardStatsProvider);
              ref.invalidate(last7DaysDataProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(last7DaysDataProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fecha de hoy
              Text(
                'Hoy — ${DateFormatter.formatDate(DateTime.now())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 12),

              // KPIs del día
              statsAsync.when(
                data: (stats) => _KpiGrid(stats: stats, currency: currency),
                loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    )),
                error: (e, _) =>
                    Center(child: Text('Error cargando KPIs: $e')),
              ),

              const SizedBox(height: 28),

              // Título gráfica
              Text(
                AppStrings.salesLast7Days,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Gráfica de barras
              chartAsync.when(
                data: (data) => _BarChart(data: data, currency: currency),
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SizedBox(
                  height: 200,
                  child: Center(child: Text('Error: $e')),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── KPI Grid ──────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final DashboardData stats;
  final String currency;

  const _KpiGrid({required this.stats, required this.currency});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
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
          icon: Icons.receipt_long_outlined,
          color: Colors.orange,
        ),
      ],
    );
  }
}

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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ── Gráfica de barras — últimos 7 días ────────────────────────────────────────

class _BarChart extends StatefulWidget {
  final List<DailySalesData> data;
  final String currency;

  const _BarChart({required this.data, required this.currency});

  @override
  State<_BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<_BarChart> {
  int _touchedIndex = -1;

  // Rellena los 7 días aunque no haya ventas
  List<DailySalesData> _fillMissingDays() {
    final today = DateTime.now();
    final result = <DailySalesData>[];

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final found = widget.data.where((d) => d.saleDate == key).firstOrNull;
      result.add(found ??
          DailySalesData(
              saleDate: key,
              dailyTotal: 0,
              dailyProfit: 0,
              transactionCount: 0));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final days = _fillMissingDays();

    if (days.every((d) => d.dailyTotal == 0)) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 48, color: cs.outlineVariant),
              const SizedBox(height: 8),
              Text('Sin ventas en los últimos 7 días',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    final maxY = days.map((d) => d.dailyTotal).reduce((a, b) => a > b ? a : b);
    final topY = maxY == 0 ? 10.0 : (maxY * 1.25);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: topY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final day = days[group.x];
                        final date = DateTime.parse(day.saleDate);
                        return BarTooltipItem(
                          '${DateFormatter.formatShortDay(date)}\n',
                          const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white),
                          children: [
                            TextSpan(
                              text: CurrencyFormatter.format(
                                  day.dailyTotal, widget.currency),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                            TextSpan(
                              text: '\n${day.transactionCount} ventas',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 11),
                            ),
                          ],
                        );
                      },
                    ),
                    touchCallback: (event, response) {
                      setState(() {
                        _touchedIndex =
                            response?.spot?.touchedBarGroupIndex ?? -1;
                      });
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            CurrencyFormatter.formatCompact(value, widget.currency),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: cs.outline),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= days.length) {
                            return const SizedBox.shrink();
                          }
                          final date = DateTime.parse(days[index].saleDate);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormatter.formatShortDay(date),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: index == _touchedIndex
                                    ? cs.primary
                                    : cs.outline,
                                fontWeight: index == _touchedIndex
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: cs.outlineVariant.withOpacity(0.4),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(days.length, (i) {
                    final isTouched = i == _touchedIndex;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: days[i].dailyTotal,
                          color: isTouched ? cs.primary : cs.primary.withOpacity(0.6),
                          width: isTouched ? 20 : 16,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            // Leyenda
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 12, height: 12,
                    decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Text('Ventas diarias',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.outline)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
