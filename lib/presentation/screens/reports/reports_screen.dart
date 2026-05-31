// lib/presentation/screens/reports/reports_screen.dart
// Pantalla de reportes con filtros y exportacion.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/report_provider.dart';

/// Pantalla de reportes.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencySymbolProvider);
    final reportAsync = ref.watch(dateRangeReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.reports),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportCsv(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros de fecha
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _DatePickerField(
                    label: AppStrings.startDate,
                    date: _fromDate,
                    onChanged: (date) {
                      if (date != null) {
                        setState(() => _fromDate = date);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DatePickerField(
                    label: AppStrings.endDate,
                    date: _toDate,
                    onChanged: (date) {
                      if (date != null) {
                        setState(() => _toDate = date);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Boton generar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref
                      .read(dateRangeReportProvider.notifier)
                      .generate(_fromDate, _toDate);
                },
                child: const Text(AppStrings.generateReport),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Resultados
          Expanded(
            child: reportAsync.when(
              data: (data) => data == null
                  ? const Center(child: Text('Selecciona un rango de fechas'))
                  : _buildReportSummary(data, currency),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSummary(DashboardData data, String currency) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen del Periodo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Total de Ventas',
            value: CurrencyFormatter.format(data.totalSales, currency),
            icon: Icons.attach_money,
            color: Colors.green,
          ),
          _ReportCard(
            title: 'Ganancia Total',
            value: CurrencyFormatter.format(data.totalProfit, currency),
            icon: Icons.trending_up,
            color: Colors.blue,
          ),
          _ReportCard(
            title: 'Comisiones',
            value: CurrencyFormatter.format(data.totalCommission, currency),
            icon: Icons.people,
            color: Colors.purple,
          ),
          _ReportCard(
            title: 'Transacciones',
            value: data.transactionCount.toString(),
            icon: Icons.receipt,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  void _exportCsv() async {
    await ref.read(csvExportProvider.notifier).export(_fromDate, _toDate);
    final csv = ref.read(csvExportProvider).value;
    if (csv != null && mounted) {
      // TODO: Compartir o guardar el CSV
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte exportado')),
      );
    }
  }
}

/// Campo de seleccion de fecha.
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
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(DateFormatter.formatDate(date)),
      ),
    );
  }
}

/// Tarjeta de reporte.
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
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
