// lib/presentation/screens/license/license_blocked_screen.dart
// Pantalla de licencia bloqueada.

import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';

/// Pantalla mostrada cuando la licencia esta bloqueada.
class LicenseBlockedScreen extends StatelessWidget {
  const LicenseBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.block,
                size: 80,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 32),
              Text(
                AppStrings.licenseExpired,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.licenseBlockedMessage,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Abrir contacto con desarrollador
                },
                icon: const Icon(Icons.contact_support),
                label: const Text(AppStrings.contactDeveloper),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
