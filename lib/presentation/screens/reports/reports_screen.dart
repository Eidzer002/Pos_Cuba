// lib/presentation/screens/reports/reports_screen.dart
// Pantalla de reportes con filtros de fecha, resumen financiero,
// gráfica de dona por categoría, top productos y exportación CSV.

import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/report_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReportsScreen
// ─────────────────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();
  bool _hasGenerated = false;

  void _generate() {
    ref.read(dateRangeReportProvider.notifier).generate(_fromDate, _toDate);
    ref.read(salesByCategoryProvider.notifier).load(_fromDate, _toDate);
    ref.read(topProductsProvider.notifier).load(_fromDate, _toDate);
    setState(() => _hasGenerated = true);
  }

  Future<void> _exportCsv() async {
    try {
      final repo = ref.read(reportRepositoryProvider);
      final csv = await repo.exportSalesToCsv(_fromDate, _toDate);

      final dir = await getTemporaryDirectory();
      final filename =
          'ventas_${DateFormatter.formatForFilename(_fromDate)}_${DateFormatter.formatForFilename(_toDate)}.csv';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Reporte de ventas POS Cuba',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencySymbolProvider);
    final reportAsync = ref.watch(dateRangeReportProvider);
    final categoryAsync = ref.watch(salesByCategoryProvider);
    final topAsync = ref.watch(topProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.reports),
        actions: [
          if (_hasGenerated)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Exportar CSV',
              onPressed: _exportCsv,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Filtros de fecha ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _DatePickerField(
                    label: AppStrings.startDate,
                    date: _fromDate,
                    onChanged: (d) {
                      if (d != null) setState(() => _fromDate = d);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerField(
                    label: AppStrings.endDate,
                    date: _toDate,
                    onChanged: (d) {
                      if (d != null) setState(() => _toDate = d);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.bar_chart_outlined),
                label: const Text(AppStrings.generateReport),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Resultados ──────────────────────────────────────────────────
          Expanded(
            child: !_hasGenerated
                ? _EmptyState()
                : reportAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        Center(child: Text('Error: $e')),
                    data: (data) => data == null
                        ? _EmptyState()
                        : _ReportBody(
                            data: data,
                            currency: currency,
                            categoryAsync: categoryAsync,
                            topAsync: topAsync,
                            fromDate: _fromDate,
                            toDate: _toDate,
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReportBody — contenido principal cuando hay datos
// ─────────────────────────────────────────────────────────────────────────────

class _ReportBody extends StatelessWidget {
  final DashboardData data;
  final String currency;
  final AsyncValue<Map<String, double>> categoryAsync;
  final AsyncValue<List<TopProductData>> topAsync;
  final DateTime fromDate;
  final DateTime toDate;

  const _ReportBody({
    required this.data,
    required this.currency,
    required this.categoryAsync,
    required this.topAsync,
    required this.fromDate,
    required this.toDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Período
          Text(
            '${DateFormatter.formatDate(fromDate)} — ${DateFormatter.formatDate(toDate)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),

          // ── KPIs del período ────────────────────────────────────────────
          Text('Resumen financiero',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _ReportCard(
              title: 'Total ventas',
              value: CurrencyFormatter.format(data.totalSales, currency),
              icon: Icons.attach_money,
              color: Colors.green),
          _ReportCard(
              title: 'Ganancia total',
              value: CurrencyFormatter.format(data.totalProfit, currency),
              icon: Icons.trending_up,
              color: Colors.blue),
          _ReportCard(
              title: 'Efectivo',
              value: CurrencyFormatter.format(data.totalCash, currency),
              icon: Icons.payments_outlined,
              color: Colors.teal),
          _ReportCard(
              title: 'Transferencias',
              value: CurrencyFormatter.format(data.totalTransfers, currency),
              icon: Icons.swap_horiz,
              color: Colors.purple),
          _ReportCard(
              title: 'Comisiones pagadas',
              value: CurrencyFormatter.format(data.totalCommission, currency),
              icon: Icons.people_outline,
              color: Colors.orange),
          _ReportCard(
              title: 'Transacciones',
              value: data.transactionCount.toString(),
              icon: Icons.receipt_long_outlined,
              color: Colors.indigo),

          const SizedBox(height: 24),

          // ── Gráfica de dona por categoría ───────────────────────────────
          Text('Ventas por categoría',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          categoryAsync.when(
            loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) =>
                Center(child: Text('Error: $e')),
            data: (categories) =>
                _DonutChart(data: categories, currency: currency),
          ),

          const SizedBox(height: 24),

          // ── Top 10 productos ────────────────────────────────────────────
          Text('Top productos',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          topAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (products) => products.isEmpty
                ? _EmptyChartState(message: 'Sin productos vendidos en este período')
                : _TopProductsList(products: products, currency: currency),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DonutChart — gráfica de dona por categoría con fl_chart
// ─────────────────────────────────────────────────────────────────────────────

class _DonutChart extends StatefulWidget {
  final Map<String, double> data;
  final String currency;

  const _DonutChart({required this.data, required this.currency});

  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart> {
  int _touchedIndex = -1;

  // Paleta de colores para las secciones
  static const _colors = [
    Color(0xFF2196F3), // Azul
    Color(0xFF4CAF50), // Verde
    Color(0xFFFF9800), // Naranja
    Color(0xFF9C27B0), // Morado
    Color(0xFFF44336), // Rojo
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFFEB3B), // Amarillo
    Color(0xFF795548), // Marrón
    Color(0xFF607D8B), // Gris azul
    Color(0xFFE91E63), // Rosa
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.data.isEmpty) {
      return _EmptyChartState(message: 'Sin datos de categorías en este período');
    }

    final total = widget.data.values.fold(0.0, (a, b) => a + b);
    final entries = widget.data.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  // Dona
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              _touchedIndex =
                                  response?.touchedSection?.touchedSectionIndex ?? -1;
                            });
                          },
                        ),
                        centerSpaceRadius: 52,
                        sectionsSpace: 2,
                        sections: List.generate(entries.length, (i) {
                          final isTouched = i == _touchedIndex;
                          final pct = total > 0 ? entries[i].value / total * 100 : 0;
                          return PieChartSectionData(
                            color: _colors[i % _colors.length],
                            value: entries[i].value,
                            title: isTouched
                                ? '${pct.toStringAsFixed(1)}%'
                                : '',
                            radius: isTouched ? 72 : 60,
                            titleStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Leyenda
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(entries.length, (i) {
                          final isTouched = i == _touchedIndex;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _colors[i % _colors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    entries[i].key,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: isTouched
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Detalle de la sección tocada
            if (_touchedIndex >= 0 && _touchedIndex < entries.length) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: _colors[_touchedIndex % _colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(entries[_touchedIndex].key,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ]),
                  Text(
                    CurrencyFormatter.format(
                        entries[_touchedIndex].value, widget.currency),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TopProductsList
// ─────────────────────────────────────────────────────────────────────────────

class _TopProductsList extends StatelessWidget {
  final List<TopProductData> products;
  final String currency;

  const _TopProductsList(
      {required this.products, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxQty = products.isEmpty
        ? 1
        : products.map((p) => p.totalQuantity).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Column(
        children: List.generate(products.length, (i) {
          final p = products[i];
          final barWidth = maxQty > 0 ? p.totalQuantity / maxQty : 0.0;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Posición
                    SizedBox(
                      width: 24,
                      child: Text(
                        '#${i + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Nombre
                    Expanded(
                      child: Text(p.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    // Cantidad
                    Text('${p.totalQuantity} uds',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(width: 12),
                    // Total
                    Text(
                      CurrencyFormatter.format(p.totalRevenue, currency),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Barra de progreso relativa
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: barWidth.toDouble(),
                    backgroundColor:
                        theme.colorScheme.surfaceVariant,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('Selecciona un rango y genera el reporte',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _EmptyChartState extends StatelessWidget {
  final String message;
  const _EmptyChartState({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Center(
        child: Text(message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline)),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(title),
        trailing: Text(value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          locale: const Locale('es'),
        );
        onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(DateFormatter.formatDate(date),
            style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
