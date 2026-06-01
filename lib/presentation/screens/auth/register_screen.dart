// lib/presentation/screens/auth/register_screen.dart
// Pantalla de registro de nuevo negocio.
// Crea cuenta en Supabase Auth + registro en tabla businesses.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../data/models/business.dart';
import '../../../data/repositories/business_repository.dart';
import '../../../providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/powersync_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  int _currentStep = 0; // 0 = cuenta, 1 = negocio

  @override
  void dispose() {
    _nameCtrl.dispose();
    _businessNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Crear cuenta en Supabase Auth
      await ref.read(authStateProvider.notifier).signUp(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        name: _nameCtrl.text.trim(),
      );

      // 2. Esperar sesión activa
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Error al crear la cuenta');

      // 3. Crear el negocio en la BD
      final repo = BusinessRepository(PowerSyncService.db);
      await repo.createBusiness(user.id, _businessNameCtrl.text.trim());

      if (mounted) context.go(AppRoutes.workerPin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Stepper(
                  currentStep: _currentStep,
                  onStepContinue: () {
                    if (_currentStep == 0) {
                      // Validar solo los campos del paso 0
                      if (_emailCtrl.text.isEmpty ||
                          !_emailCtrl.text.contains('@') ||
                          _passwordCtrl.text.length < 6 ||
                          _passwordCtrl.text != _confirmPasswordCtrl.text ||
                          _nameCtrl.text.isEmpty) {
                        _formKey.currentState!.validate();
                        return;
                      }
                      setState(() => _currentStep = 1);
                    } else {
                      _register();
                    }
                  },
                  onStepCancel: () {
                    if (_currentStep > 0) setState(() => _currentStep--);
                  },
                  controlsBuilder: (context, details) => Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        FilledButton(
                          onPressed: details.onStepContinue,
                          child: Text(_currentStep == 0
                              ? 'Continuar'
                              : 'Crear cuenta'),
                        ),
                        if (_currentStep > 0) ...[
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: details.onStepCancel,
                            child: const Text('Atrás'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  steps: [
                    // ── Paso 1: Cuenta ─────────────────────────────
                    Step(
                      title: const Text('Tu cuenta'),
                      isActive: _currentStep >= 0,
                      state: _currentStep > 0
                          ? StepState.complete
                          : StepState.indexed,
                      content: Column(
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tu nombre *',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'El nombre es obligatorio'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico *',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Requerido';
                              if (!v.contains('@')) return 'Correo inválido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Contraseña *',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Requerido';
                              if (v.length < 6) return 'Mínimo 6 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordCtrl,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'Confirmar contraseña *',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Requerido';
                              if (v != _passwordCtrl.text)
                                return 'Las contraseñas no coinciden';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    // ── Paso 2: Negocio ────────────────────────────
                    Step(
                      title: const Text('Tu negocio'),
                      isActive: _currentStep >= 1,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Puedes cambiar estos datos después en Configuración.',
                            style: TextStyle(
                                color: theme.colorScheme.outline,
                                fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _businessNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del negocio *',
                              prefixIcon: Icon(Icons.storefront_outlined),
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => _currentStep < 1
                                ? null
                                : (v == null || v.trim().isEmpty)
                                    ? 'El nombre del negocio es obligatorio'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            const Icon(Icons.info_outline,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Empezarás con 7 días de prueba gratuita.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.outline),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
