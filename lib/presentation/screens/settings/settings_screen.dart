// lib/presentation/screens/settings/settings_screen.dart
// Pantalla de configuracion general.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../providers/auth_provider.dart';

/// Pantalla de configuracion.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: ListView(
        children: [
          // Seccion de Negocio
          _SectionHeader(title: 'Negocio'),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Informacion del Negocio'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Editar informacion del negocio
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text(AppStrings.categories),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('${AppRoutes.settings}/${AppRoutes.categories}'),
          ),

          // Seccion de Trabajadores
          _SectionHeader(title: 'Trabajadores'),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text(AppStrings.workers),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('${AppRoutes.settings}/${AppRoutes.workers}'),
          ),

          // Seccion de Configuracion
          _SectionHeader(title: 'Configuracion'),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text(AppStrings.currencySettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Configurar moneda
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text(AppStrings.backupRestore),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('${AppRoutes.settings}/${AppRoutes.backup}'),
          ),

          // Seccion de Cuenta
          _SectionHeader(title: 'Cuenta'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text(AppStrings.logout),
            textColor: Colors.red,
            iconColor: Colors.red,
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.logout),
        content: const Text('Estas seguro de que quieres cerrar sesion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(authStateProvider.notifier).signOut();
              context.go(AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(AppStrings.logout),
          ),
        ],
      ),
    );
  }
}

/// Header de seccion.
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
