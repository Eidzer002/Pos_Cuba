// lib/presentation/screens/settings/settings_screen.dart
// Pantalla de configuración general.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as pathlib;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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
          Consumer(
            builder: (context, ref, _) {
              final business = ref.watch(currentBusinessProvider).valueOrNull;
              return ListTile(
                leading: const Icon(Icons.business_outlined),
                title: const Text('Información del negocio'),
                subtitle: business != null ? Text(business.name) : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: business == null
                    ? null
                    : () => _showBusinessInfoSheet(context, ref, business),
              );
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

          Consumer(
            builder: (context, ref, _) {
              final symbol = ref.watch(currencySymbolProvider);
              return ListTile(
                leading: const Icon(Icons.attach_money_outlined),
                title: const Text(AppStrings.currencySettings),
                subtitle: Text('Símbolo actual: $symbol'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCurrencyDialog(context, ref),
              );
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
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          if (value == 'pin') _showChangePinDialog(context, ref);
          if (value == 'commission') _showCommissionDialog(context, ref);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'pin',
              child: ListTile(dense: true, leading: Icon(Icons.pin_outlined),
                  title: Text('Cambiar PIN'), contentPadding: EdgeInsets.zero)),
          PopupMenuItem(value: 'commission',
              child: ListTile(dense: true, leading: Icon(Icons.percent),
                  title: Text('Editar comisión'), contentPadding: EdgeInsets.zero)),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _ChangePinDialog(worker: worker),
    );
  }

  void _showCommissionDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _CommissionDialog(worker: worker),
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
// _showCurrencyDialog — #18
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showCurrencyDialog(BuildContext context, WidgetRef ref) async {
  final business = ref.read(currentBusinessProvider).valueOrNull;
  if (business == null) return;

  const presets = ['CUP', 'USD', 'EUR', 'MLC'];
  String selected = business.currencySymbol;
  final customCtrl = TextEditingController(
      text: presets.contains(selected) ? '' : selected);

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Símbolo de moneda'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: presets.map((p) => ChoiceChip(
                label: Text(p),
                selected: selected == p,
                onSelected: (_) => setState(() {
                  selected = p;
                  customCtrl.clear();
                }),
              )).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: customCtrl,
              decoration: const InputDecoration(
                labelText: 'Personalizado (ej. \$ , €, Bs)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              maxLength: 5,
              onChanged: (v) => setState(() => selected = v.trim().isEmpty ? presets[0] : v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final symbol = customCtrl.text.trim().isNotEmpty
                  ? customCtrl.text.trim()
                  : selected;
              final repo = ref.read(businessRepositoryProvider);
              await repo.updateBusiness(business.copyWith(currencySymbol: symbol));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Moneda actualizada a: $symbol'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

// _showBusinessInfoSheet — #17
// ─────────────────────────────────────────────────────────────────────────────

void _showBusinessInfoSheet(BuildContext context, WidgetRef ref, business) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _BusinessInfoSheet(business: business),
  );
}

class _BusinessInfoSheet extends ConsumerStatefulWidget {
  final dynamic business;
  const _BusinessInfoSheet({required this.business});

  @override
  ConsumerState<_BusinessInfoSheet> createState() => _BusinessInfoSheetState();
}

class _BusinessInfoSheetState extends ConsumerState<_BusinessInfoSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  String? _logoPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController(text: widget.business.name as String);
    _addressCtrl = TextEditingController(text: widget.business.address as String? ?? '');
    _phoneCtrl   = TextEditingController(text: widget.business.phone as String? ?? '');
    _logoPath    = widget.business.logoPath as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _addressCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 90);
    if (picked == null) return;
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/business');
    if (!await dir.exists()) await dir.create(recursive: true);
    final dest = '${dir.path}/${const Uuid().v4()}${pathlib.extension(picked.path)}';
    await File(picked.path).copy(dest);
    if (mounted) setState(() => _logoPath = dest);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(businessRepositoryProvider);
      await repo.updateBusiness(widget.business.copyWith(
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        logoPath: _logoPath,
      ));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20,
          MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Información del negocio',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Logo
          GestureDetector(
            onTap: _pickLogo,
            child: Stack(alignment: Alignment.bottomRight, children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: cs.primaryContainer,
                backgroundImage: _logoPath != null && File(_logoPath!).existsSync()
                    ? FileImage(File(_logoPath!)) : null,
                child: _logoPath == null
                    ? Icon(Icons.storefront_outlined, size: 40, color: cs.onPrimaryContainer)
                    : null,
              ),
              CircleAvatar(radius: 14, backgroundColor: cs.primary,
                  child: Icon(Icons.camera_alt, size: 14, color: cs.onPrimary)),
            ]),
          ),
          const SizedBox(height: 20),

          TextFormField(controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre del negocio *',
                  prefixIcon: Icon(Icons.store_outlined), border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Dirección (opcional)',
                  prefixIcon: Icon(Icons.location_on_outlined), border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono (opcional)',
                  prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder())),
          const SizedBox(height: 20),

          SizedBox(width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),
        ],
      ),
    );
  }
}

// _CommissionDialog — #16
// ─────────────────────────────────────────────────────────────────────────────

class _CommissionDialog extends ConsumerStatefulWidget {
  final dynamic worker;
  const _CommissionDialog({required this.worker});

  @override
  ConsumerState<_CommissionDialog> createState() => _CommissionDialogState();
}

class _CommissionDialogState extends ConsumerState<_CommissionDialog> {
  late CommissionType _type;
  late final TextEditingController _valueCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.worker.commissionType as CommissionType;
    _valueCtrl = TextEditingController(
        text: (widget.worker.commissionValue as double).toStringAsFixed(2));
  }

  @override
  void dispose() { _valueCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final value = double.tryParse(_valueCtrl.text.replaceAll(',', '.')) ?? 0;
    if (value < 0) return;
    final business = ref.read(currentBusinessProvider).valueOrNull;
    if (business == null) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(workerOperationsProvider.notifier).updateCommission(
        workerId: widget.worker.id as String,
        businessId: business.id,
        commissionType: _type,
        commissionValue: value,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Comisión de ${widget.worker.name} actualizada.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Comisión — ${widget.worker.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<CommissionType>(
            segments: const [
              ButtonSegment(value: CommissionType.percentage,
                  icon: Icon(Icons.percent), label: Text('Porcentaje')),
              ButtonSegment(value: CommissionType.fixed,
                  icon: Icon(Icons.attach_money), label: Text('Fijo')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _valueCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _type == CommissionType.percentage
                  ? 'Porcentaje (ej. 5.0 = 5%)' : 'Monto fijo por venta',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(_type == CommissionType.percentage
                  ? Icons.percent : Icons.attach_money),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

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
