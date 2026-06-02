// lib/presentation/screens/reports/reports_screen.dart
// Pantalla de reportes con 3 tabs:
// 1. Resumen financiero + top productos
// 2. Gráfica de dona por categoría
// 3. Tabla de ventas con botón anular (solo owner)

import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/sale.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/report_provider.dart';
import '../../../providers/worker_session_provider.dart';
import '../../../services/powersync_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReportsScreen
// ─────────────────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();
  bool _hasGenerated = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
    final session = ref.watch(workerSessionProvider);

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
        bottom: _hasGenerated
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Resumen'),
                  Tab(text: 'Categorías'),
                  Tab(text: 'Ventas'),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          // ── Filtros de fecha ─────────────────────────────────────────────
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

          // ── Tabs ─────────────────────────────────────────────────────────
          Expanded(
            child: !_hasGenerated
                ? _EmptyState()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Resumen + top productos
                      reportAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (data) => data == null
                            ? _EmptyState()
                            : _SummaryTab(
                                data: data,
                                currency: currency,
                                topAsync: topAsync,
                                fromDate: _fromDate,
                                toDate: _toDate,
                              ),
                      ),

                      // Tab 2: Dona por categoría
                      categoryAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (cats) =>
                            _CategoryTab(data: cats, currency: currency),
                      ),

                      // Tab 3: Tabla de ventas con botón anular
                      _SalesTab(
                        fromDate: _fromDate,
                        toDate: _toDate,
                        currency: currency,
                        isOwner: session?.isOwner ?? false,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Resumen financiero
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  final DashboardData data;
  final String currency;
  final AsyncValue<List<TopProductData>> topAsync;
  final DateTime fromDate;
  final DateTime toDate;

  const _SummaryTab({
    required this.data,
    required this.currency,
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
          Text(
            '${DateFormatter.formatDate(fromDate)} — ${DateFormatter.formatDate(toDate)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          _ReportCard(title: 'Total ventas',
              value: CurrencyFormatter.format(data.totalSales, currency),
              icon: Icons.attach_money, color: Colors.green),
          _ReportCard(title: 'Ganancia total',
              value: CurrencyFormatter.format(data.totalProfit, currency),
              icon: Icons.trending_up, color: Colors.blue),
          _ReportCard(title: 'Efectivo',
              value: CurrencyFormatter.format(data.totalCash, currency),
              icon: Icons.payments_outlined, color: Colors.teal),
          _ReportCard(title: 'Transferencias',
              value: CurrencyFormatter.format(data.totalTransfers, currency),
              icon: Icons.swap_horiz, color: Colors.purple),
          _ReportCard(title: 'Comisiones',
              value: CurrencyFormatter.format(data.totalCommission, currency),
              icon: Icons.people_outline, color: Colors.orange),
          _ReportCard(title: 'Transacciones',
              value: data.transactionCount.toString(),
              icon: Icons.receipt_long_outlined, color: Colors.indigo),
          const SizedBox(height: 20),
          Text('Top productos',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          topAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (products) => products.isEmpty
                ? const _EmptyChartState(
                    message: 'Sin productos vendidos en este período')
                : _TopProductsList(products: products, currency: currency),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Dona por categoría
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryTab extends StatelessWidget {
  final Map<String, double> data;
  final String currency;
  const _CategoryTab({required this.data, required this.currency});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: data.isEmpty
          ? const _EmptyChartState(
              message: 'Sin datos de categorías en este período')
          : _DonutChart(data: data, currency: currency),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Tabla de ventas con botón anular
// ─────────────────────────────────────────────────────────────────────────────

class _SalesTab extends ConsumerStatefulWidget {
  final DateTime fromDate;
  final DateTime toDate;
  final String currency;
  final bool isOwner;

  const _SalesTab({
    required this.fromDate,
    required this.toDate,
    required this.currency,
    required this.isOwner,
  });

  @override
  ConsumerState<_SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends ConsumerState<_SalesTab> {
  Future<List<Sale>>? _salesFuture;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  void _loadSales() {
    final businessId = ref.read(selectedBusinessIdProvider) ?? '';
    final fromStr = DateTime(widget.fromDate.year, widget.fromDate.month,
            widget.fromDate.day, 0, 0, 0)
        .toIso8601String();
    final toStr = DateTime(widget.toDate.year, widget.toDate.month,
            widget.toDate.day, 23, 59, 59, 999)
        .toIso8601String();

    _salesFuture = PowerSyncService.db.execute(
      'SELECT * FROM sales WHERE business_id = ? AND created_at BETWEEN ? AND ? ORDER BY created_at DESC LIMIT 200',
      [businessId, fromStr, toStr],
    ).then((rows) => rows.map(Sale.fromRow).toList());
  }

  Future<void> _cancelSale(Sale sale) async {
    final reasonCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Anular venta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Venta #${sale.id.substring(0, 8).toUpperCase()}\n'
              'Total: ${CurrencyFormatter.format(sale.total, widget.currency)}\n'
              '${DateFormatter.formatDateTime(sale.createdAt)}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text('Esta acción restaurará el stock. ¿Motivo?'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                hintText: 'Ej: Error en la venta',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Anular venta'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final businessId = ref.read(selectedBusinessIdProvider) ?? '';
      final repo = SaleRepository(
          db: PowerSyncService.db, businessId: businessId);
      await repo.cancelSale(
        sale.id,
        reasonCtrl.text.trim().isEmpty
            ? 'Sin motivo especificado'
            : reasonCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Venta anulada y stock restaurado.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
        setState(() => _loadSales());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al anular: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FutureBuilder<List<Sale>>(
      future: _salesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final sales = snapshot.data ?? [];

        if (sales.isEmpty) {
          return const _EmptyChartState(message: 'Sin ventas en este período');
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: sales.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (_, i) {
            final sale = sales[i];
            final isCancelled = sale.status == 'cancelled';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isCancelled
                    ? Colors.red.withOpacity(0.1)
                    : cs.primaryContainer,
                child: Icon(
                  isCancelled
                      ? Icons.cancel_outlined
                      : sale.paymentMethod == PaymentMethod.cash
                          ? Icons.payments_outlined
                          : Icons.credit_card,
                  size: 18,
                  color: isCancelled ? Colors.red : cs.primary,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    '#${sale.id.substring(0, 8).toUpperCase()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                      color: isCancelled ? cs.outline : null,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    CurrencyFormatter.format(sale.total, widget.currency),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isCancelled ? cs.outline : cs.primary,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormatter.formatDateTime(sale.createdAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.outline),
                  ),
                  if (isCancelled && sale.cancelledReason != null)
                    Text(
                      'Anulada: ${sale.cancelledReason}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.red),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              isThreeLine: isCancelled && sale.cancelledReason != null,
              // Botón anular — solo owner, solo ventas completadas
              trailing: (!isCancelled && widget.isOwner)
                  ? IconButton(
                      icon: const Icon(Icons.cancel_outlined,
                          color: Colors.red, size: 20),
                      tooltip: 'Anular venta',
                      onPressed: () => _cancelSale(sale),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DonutChart
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

  static const _colors = [
    Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFFF9800),
    Color(0xFF9C27B0), Color(0xFFF44336), Color(0xFF00BCD4),
    Color(0xFFFFEB3B), Color(0xFF795548), Color(0xFF607D8B),
    Color(0xFFE91E63),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              _touchedIndex = response
                                      ?.touchedSection
                                      ?.touchedSectionIndex ??
                                  -1;
                            });
                          },
                        ),
                        centerSpaceRadius: 52,
                        sectionsSpace: 2,
                        sections: List.generate(entries.length, (i) {
                          final isTouched = i == _touchedIndex;
                          final pct = total > 0
                              ? entries[i].value / total * 100
                              : 0.0;
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
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
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
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(
                                            fontWeight: isTouched
                                                ? FontWeight.bold
                                                : null),
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
            if (_touchedIndex >= 0 && _touchedIndex < entries.length) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      width: 12,
                      height: 12,
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
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _TopProductsList extends StatelessWidget {
  final List<TopProductData> products;
  final String currency;
  const _TopProductsList({required this.products, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxQty = products
        .map((p) => p.totalQuantity)
        .reduce((a, b) => a > b ? a : b);
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
                Row(children: [
                  SizedBox(
                    width: 24,
                    child: Text('#${i + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(p.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600))),
                  Text('${p.totalQuantity} uds',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(width: 12),
                  Text(CurrencyFormatter.format(p.totalRevenue, currency),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: barWidth.toDouble(),
                    backgroundColor: theme.colorScheme.surfaceVariant,
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
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant)),
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
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline)),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _ReportCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 18)),
        title: Text(title),
        trailing: Text(value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime?> onChanged;
  const _DatePickerField(
      {required this.label,
      required this.date,
      required this.onChanged});

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
          suffixIcon:
              const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(DateFormatter.formatDate(date),
            style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
