// lib/presentation/screens/cashbox/cashbox_screen.dart
// Pantalla de caja con apertura/cierre y movimientos.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/cash_movement.dart';
import '../../../data/models/cash_session.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/cashbox_provider.dart';

/// Pantalla de caja.
class CashboxScreen extends ConsumerWidget {
  const CashboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencySymbolProvider);
    final sessionAsync = ref.watch(openSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.cashbox),
      ),
      body: sessionAsync.when(
        data: (session) => session == null
            ? _OpenCashboxView(currency: currency)
            : _CashboxOpenView(session: session, currency: currency),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

/// Vista para abrir caja.
class _OpenCashboxView extends ConsumerWidget {
  final String currency;

  const _OpenCashboxView({required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.storefront,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.cashboxClosed,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Debes abrir la caja para procesar ventas en efectivo',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppStrings.openingAmount,
              prefixText: currency,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount >= 0) {
                ref.read(cashboxOperationsProvider.notifier).open(amount);
              }
            },
            child: const Text(AppStrings.openCashbox),
          ),
        ],
      ),
    );
  }
}

/// Vista de caja abierta.
class _CashboxOpenView extends ConsumerWidget {
  final CashSession session;
  final String currency;

  const _CashboxOpenView({required this.session, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(sessionMovementsProvider(session.id));

    return Column(
      children: [
        // Header de caja abierta
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green.shade50,
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.cashboxOpen,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Apertura: ${CurrencyFormatter.format(session.openingAmount, currency)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showCloseDialog(context, ref),
                child: const Text(AppStrings.closeCashbox),
              ),
            ],
          ),
        ),
        // Botones de movimiento
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showMovementDialog(context, ref, true),
                  icon: const Icon(Icons.add),
                  label: const Text('Entrada'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showMovementDialog(context, ref, false),
                  icon: const Icon(Icons.remove),
                  label: const Text('Salida'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Lista de movimientos
        Expanded(
          child: movementsAsync.when(
            data: (movements) => _buildMovementsList(movements, currency),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildMovementsList(List<CashMovement> movements, String currency) {
    if (movements.isEmpty) {
      return const Center(
        child: Text('No hay movimientos registrados'),
      );
    }

    return ListView.builder(
      itemCount: movements.length,
      itemBuilder: (context, index) {
        final movement = movements[index];
        return ListTile(
          leading: Icon(
            movement.isIncoming ? Icons.add_circle : Icons.remove_circle,
            color: movement.isIncoming ? Colors.green : Colors.red,
          ),
          title: Text(movement.description),
          trailing: Text(
            CurrencyFormatter.format(movement.amount, currency),
            style: TextStyle(
              color: movement.isIncoming ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  void _showMovementDialog(BuildContext context, WidgetRef ref, bool isIncome) {
    final amountController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isIncome ? 'Nueva Entrada' : 'Nueva Salida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monto',
                prefixText: currency,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Descripcion',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0;
              final desc = descController.text;
              if (amount > 0 && desc.isNotEmpty) {
                if (isIncome) {
                  ref.read(cashboxOperationsProvider.notifier).addIncome(
                        session.id,
                        amount,
                        desc,
                      );
                } else {
                  ref.read(cashboxOperationsProvider.notifier).addExpense(
                        session.id,
                        amount,
                        desc,
                      );
                }
                Navigator.pop(context);
              }
            },
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
  }

  void _showCloseDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.closeCashbox),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: AppStrings.closingAmount,
            prefixText: currency,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0;
              ref.read(cashboxOperationsProvider.notifier).close(amount);
              Navigator.pop(context);
            },
            child: const Text(AppStrings.closeCashbox),
          ),
        ],
      ),
    );
  }
}
