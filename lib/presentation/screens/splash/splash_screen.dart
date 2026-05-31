// lib/presentation/screens/splash/splash_screen.dart
// Pantalla de splash con verificacion de licencia y autenticacion.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../services/license_service.dart';
import '../../../providers/auth_provider.dart';

/// Pantalla de splash con inicializacion.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Verificar licencia
    final licenseStatus = await LicenseService.checkStatus();

    switch (licenseStatus) {
      case LicenseStatus.hardBlocked:
        if (mounted) context.go(AppRoutes.licenseBlocked);
        return;
      case LicenseStatus.softBlocked:
      case LicenseStatus.gracePeriod:
        // Mostrar warning pero continuar
        break;
      case LicenseStatus.valid:
      case LicenseStatus.trial:
        // Continuar normalmente
        break;
    }

    if (!mounted) return;

    // Verificar autenticacion
    final authState = ref.read(authStateProvider).value;
    if (authState?.isAuthenticated == true) {
      context.go(AppRoutes.dashboard);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Icon(
              Icons.point_of_sale,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.appName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.appVersion,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
