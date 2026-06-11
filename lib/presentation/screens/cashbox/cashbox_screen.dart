// lib/presentation/screens/cashbox/cashbox_screen.dart
// Pantalla de caja con apertura/cierre y movimientos.
//
// FIXES aplicados:
//   BUG-2:  _OpenCashboxView → ConsumerStatefulWidget con dispose() del controller
//   ARCH-6: ref.listen en CashboxScreen para mostrar errores de operaciones

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/cash_movement.dart';
import '../../../data/models/cash_session.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/cashbox_provider.dart';
import '../../../providers/worker_session_provider.dart';

class CashboxScreen extends ConsumerWidget {
  const CashboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency     = ref.watch(currencySymbolProvider);
    final sessionAsync = ref.watch(openSessionProvider);

    // FIX ARCH-6: mostrar SnackBar cuando una operación de caja falla.
    // Antes: open/addIncome/addExpense fallaban silenciosamente sin feedback al usuario.
    ref.listen<AsyncValue<void>>(cashboxOperationsProvider, (_, next) {
      if (next.hasError) {
        final msg = next.error.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error en caja: $msg'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.cashbox)),
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

// ─────────────────────────────────────────────────────────────────────────────
// _OpenCashboxView
// FIX BUG-2: convertido a ConsumerStatefulWidget para poder llamar dispose()
// sobre el TextEditingController. Antes era ConsumerWidget y el controller se
// creaba en build() sin nunca ser dispuesto → memory leak garantizado.
// ─────────────────────────────────────────────────────────────────────────────

class _OpenCashboxView extends ConsumerStatefulWidget {
  final String currency;
  const _OpenCashboxView({required this.currency});

  @override
  ConsumerState<_OpenCashboxView> createState() => _OpenCashboxViewState();
}

class _OpenCashboxViewState extends ConsumerState<_OpenCashboxView> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.storefront, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            AppStrings.cashboxClosed,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Debes abrir la caja para procesar ventas en efectivo',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppStrings.openingAmount,
              prefixText: widget.currency,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              final amount = double.tryParse(_controller.text) ?? 0;
              if (amount < 0) return;
              // Pasar workerId del trabajador/dueño activo a la sesión de caja
              final workerSession = ref.read(workerSessionProvider);
              ref.read(cashboxOperationsProvider.notifier).open(
                amount,
                workerId: workerSession?.workerId,
              );
            },
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text(AppStrings.openCashbox),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CashboxOpenView
// ─────────────────────────────────────────────────────────────────────────────

class _CashboxOpenView extends ConsumerWidget {
  final CashSession session;
  final String currency;

  const _CashboxOpenView({required this.session, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(sessionMovementsProvider(session.id));

    return Column(
      children: [
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
                            color: Colors.green.shade700, fontWeight: FontWeight.bold),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: movementsAsync.when(
            data: (movements) => _buildMovementsList(context, movements),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildMovementsList(BuildContext context, List<CashMovement> movements) {
    if (movements.isEmpty) {
      return const Center(child: Text('No hay movimientos registrados'));
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
    final amountCtrl = TextEditingController();
    final descCtrl   = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIncome ? 'Nueva Entrada' : 'Nueva Salida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monto', prefixText: currency, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.cancel)),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              final desc   = descCtrl.text.trim();
              if (amount <= 0 || desc.isEmpty) return;
              if (isIncome) {
                ref.read(cashboxOperationsProvider.notifier).addIncome(session.id, amount, desc);
              } else {
                ref.read(cashboxOperationsProvider.notifier).addExpense(session.id, amount, desc);
              }
              Navigator.pop(ctx);
            },
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
  }

  void _showCloseDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.closeCashbox),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: AppStrings.closingAmount,
            prefixText: currency,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.cancel)),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0;
              ref.read(cashboxOperationsProvider.notifier).close(amount);
              Navigator.pop(ctx);
            },
            child: const Text(AppStrings.closeCashbox),
          ),
        ],
      ),
    );
  }
}
