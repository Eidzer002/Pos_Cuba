// lib/presentation/screens/auth/worker_pin_screen.dart
// Pantalla de selección de trabajador y autenticación por PIN.
// El dueño puede entrar sin PIN usando "Entrar como dueño".
// SEGURIDAD: PIN nunca se loggea ni persiste — solo se hashea en memoria.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../data/models/worker.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/worker_provider.dart';
import '../../../providers/worker_session_provider.dart';

class WorkerPinScreen extends ConsumerStatefulWidget {
  const WorkerPinScreen({super.key});

  @override
  ConsumerState<WorkerPinScreen> createState() => _WorkerPinScreenState();
}

class _WorkerPinScreenState extends ConsumerState<WorkerPinScreen> {
  Worker? _selectedWorker;
  String _pin = '';
  bool _isLoading = false;
  bool _hasError = false;
  int _attempts = 0;

  static const int _maxAttempts = 5;
  static const int _pinLength = 4;

  void _onDigit(String digit) {
    if (_pin.length >= _pinLength || _isLoading) return;
    setState(() {
      _pin += digit;
      _hasError = false;
    });
    if (_pin.length == _pinLength) _authenticate();
  }

  void _onDelete() {
    if (_pin.isEmpty || _isLoading) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _onClear() => setState(() => _pin = '');

  Future<void> _authenticate() async {
    if (_selectedWorker == null) return;

    final business = ref.read(currentBusinessProvider).valueOrNull;
    if (business == null) return;

    setState(() { _isLoading = true; _hasError = false; });

    final ok = await ref.read(workerSessionProvider.notifier).login(
      business.id,
      _pin,
    );

    if (!mounted) return;

    if (ok) {
      context.go(AppRoutes.dashboard);
    } else {
      _attempts++;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _pin = '';
      });

      if (_attempts >= _maxAttempts) {
        _showLockedDialog();
      }
    }
  }

  void _enterAsOwner() {
    final user = ref.read(authUserProvider);
    if (user == null) return;

    ref.read(workerSessionProvider.notifier).loginAsOwner(
      ownerId: user.id,
      ownerName: user.userMetadata?['name'] as String? ?? 'Dueño',
    );
    context.go(AppRoutes.dashboard);
  }

  void _showLockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Acceso bloqueado'),
        content: const Text(
          'Demasiados intentos fallidos. Contacta al dueño del negocio.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() { _attempts = 0; _pin = ''; _selectedWorker = null; });
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(activeWorkersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.point_of_sale,
                      size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text('¿Quién está trabajando?',
                      style: theme.textTheme.titleLarge),
                ],
              ),
            ),

            // ── Selección de trabajador ───────────────────────────
            workersAsync.when(
              data: (workers) => workers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No hay trabajadores activos. El dueño puede entrar directamente.',
                        style: TextStyle(color: theme.colorScheme.outline),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: workers.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final w = workers[i];
                          final selected = _selectedWorker?.id == w.id;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedWorker = w;
                              _pin = '';
                              _hasError = false;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: selected
                                    ? Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 2)
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person,
                                      color: selected
                                          ? theme.colorScheme.primary
                                          : null),
                                  const SizedBox(height: 4),
                                  Text(w.name,
                                      style: TextStyle(
                                          fontWeight: selected
                                              ? FontWeight.bold
                                              : FontWeight.normal)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error cargando trabajadores'),
            ),

            const Spacer(),

            // ── Indicador de PIN ──────────────────────────────────
            if (_selectedWorker != null) ...[
              Text(
                'Ingresa tu PIN',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasError
                          ? theme.colorScheme.error
                          : filled
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  );
                }),
              ),
              if (_hasError) ...[
                const SizedBox(height: 8),
                Text(
                  'PIN incorrecto. Intento $_attempts/$_maxAttempts',
                  style: TextStyle(color: theme.colorScheme.error,
                      fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
            ],

            // ── Teclado numérico ──────────────────────────────────
            if (_selectedWorker != null)
              _isLoading
                  ? const CircularProgressIndicator()
                  : _NumPad(
                      onDigit: _onDigit,
                      onDelete: _onDelete,
                    ),

            const SizedBox(height: 24),

            // ── Botón dueño ───────────────────────────────────────
            TextButton.icon(
              onPressed: _enterAsOwner,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Entrar como dueño'),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Teclado numérico ─────────────────────────────────────────────────────────

class _NumPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  const _NumPad({required this.onDigit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 1.8,
      padding: const EdgeInsets.symmetric(horizontal: 48),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      physics: const NeverScrollableScrollPhysics(),
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox.shrink();
        if (key == '⌫') {
          return _PadKey(
            label: key,
            onTap: onDelete,
            isAction: true,
          );
        }
        return _PadKey(label: key, onTap: () => onDigit(key));
      }).toList(),
    );
  }
}

class _PadKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAction;

  const _PadKey({
    required this.label,
    required this.onTap,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isAction
          ? theme.colorScheme.surfaceVariant
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
