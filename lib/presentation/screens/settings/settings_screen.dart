// lib/presentation/screens/settings/settings_screen.dart
// Pantalla de configuración general.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/security_utils.dart';
import '../../../data/models/worker.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/worker_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SettingsScreen
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workersAsync = ref.watch(activeWorkersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: ListView(
        children: [
          // ── Negocio ──────────────────────────────────────────────────────
          const _SectionHeader(title: 'Negocio'),
          ListTile(
            leading: const Icon(Icons.business_outlined),
            title: const Text('Información del negocio'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Pantalla editar negocio
            },
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text(AppStrings.categories),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.push('${AppRoutes.settings}/${AppRoutes.categories}'),
          ),

          // ── Trabajadores ─────────────────────────────────────────────────
          const _SectionHeader(title: 'Trabajadores'),
          ListTile(
            leading: const Icon(Icons.person_add_outlined),
            title: const Text(AppStrings.workers),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.push('${AppRoutes.settings}/${AppRoutes.workers}'),
          ),

          // Lista de trabajadores activos con botón de cambiar PIN
          workersAsync.when(
            data: (workers) => workers.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Text(
                          'Cambiar PIN de trabajador',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                        ),
                      ),
                      ...workers.map((w) => _WorkerPinTile(worker: w)),
                    ],
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ── Configuración ────────────────────────────────────────────────
          const _SectionHeader(title: 'Configuración'),
          // Toggle de tema claro/oscuro/sistema
          Consumer(
            builder: (context, ref, _) {
              final themeAsync = ref.watch(appThemeModeProvider);
              final mode = themeAsync.valueOrNull ?? ThemeMode.system;
              return ListTile(
                leading: Icon(
                  mode == ThemeMode.dark
                      ? Icons.dark_mode_outlined
                      : mode == ThemeMode.light
                          ? Icons.light_mode_outlined
                          : Icons.brightness_auto_outlined,
                ),
                title: const Text('Apariencia'),
                subtitle: Text(
                  mode == ThemeMode.dark
                      ? 'Modo oscuro'
                      : mode == ThemeMode.light
                          ? 'Modo claro'
                          : 'Según el sistema',
                ),
                trailing: SegmentedButton<ThemeMode>(
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode, size: 18),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selection) {
                    ref.read(appThemeModeProvider.notifier)
                        .setTheme(selection.first);
                  },
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.attach_money_outlined),
            title: const Text(AppStrings.currencySettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Configurar moneda
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text(AppStrings.backupRestore),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.push('${AppRoutes.settings}/${AppRoutes.backup}'),
          ),

          // ── Cuenta ───────────────────────────────────────────────────────
          const _SectionHeader(title: 'Cuenta'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(AppStrings.logout),
            textColor: Colors.red,
            onTap: () => _confirmLogout(context, ref),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.logout),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.cancel)),
          FilledButton(
            onPressed: () {
              ref.read(authStateProvider.notifier).signOut();
              context.go(AppRoutes.login);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(AppStrings.logout),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WorkerPinTile — fila de trabajador con botón de cambiar PIN
// ─────────────────────────────────────────────────────────────────────────────

class _WorkerPinTile extends ConsumerWidget {
  final Worker worker;
  const _WorkerPinTile({required this.worker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          worker.name.substring(0, 1).toUpperCase(),
          style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(worker.name),
      subtitle: Text(
        worker.commissionType == CommissionType.percentage
            ? 'Comisión: ${worker.commissionValue.toStringAsFixed(1)}%'
            : 'Salario fijo: ${worker.commissionValue.toStringAsFixed(2)}',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      ),
      trailing: TextButton.icon(
        icon: const Icon(Icons.pin_outlined, size: 16),
        label: const Text('Cambiar PIN'),
        onPressed: () => _showChangePinDialog(context, ref),
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _ChangePinDialog(worker: worker),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChangePinDialog — diálogo completo para cambiar PIN
// ─────────────────────────────────────────────────────────────────────────────

class _ChangePinDialog extends ConsumerStatefulWidget {
  final Worker worker;
  const _ChangePinDialog({required this.worker});

  @override
  ConsumerState<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends ConsumerState<_ChangePinDialog> {
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final business = ref.read(currentBusinessProvider).valueOrNull;
    if (business == null) return;

    // Validar que el nuevo PIN sea diferente al actual
    final newHash = SecurityUtils.hashPin(_newPinCtrl.text);
    if (newHash == widget.worker.pinHash) {
      setState(() => _errorMessage = 'El nuevo PIN debe ser diferente al actual.');
      return;
    }

    setState(() { _isSaving = true; _errorMessage = null; });

    try {
      await ref.read(workerOperationsProvider.notifier).changePin(
            workerId: widget.worker.id,
            businessId: business.id,
            newPin: _newPinCtrl.text,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PIN de ${widget.worker.name} actualizado.'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Error al cambiar PIN: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cambiar PIN — ${widget.worker.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nuevo PIN
            TextFormField(
              controller: _newPinCtrl,
              obscureText: _obscureNew,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: 'Nuevo PIN (4–6 dígitos)',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureNew ? Icons.visibility : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requerido';
                if (!SecurityUtils.isValidPinFormat(v)) {
                  return 'El PIN debe tener entre 4 y 6 dígitos';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirmar PIN
            TextFormField(
              controller: _confirmPinCtrl,
              obscureText: _obscureConfirm,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: 'Confirmar nuevo PIN',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requerido';
                if (v != _newPinCtrl.text) return 'Los PINs no coinciden';
                return null;
              },
            ),

            // Mensaje de error
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Guardar PIN'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionHeader
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
