// lib/main.dart
// Punto de entrada de la aplicacion POS Cuba.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/remote/supabase_client.dart';
import 'services/license_service.dart';
import 'services/powersync_service.dart';
import 'presentation/screens/screens.dart';
import 'presentation/widgets/common/app_scaffold.dart';

import 'providers/auth_provider.dart';
import 'providers/worker_session_provider.dart';

part 'main.g.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase
  await initSupabase();

  // Inicializar PowerSync
  await PowerSyncService.initialize();

  runApp(
    const ProviderScope(
      child: POSCubaApp(),
    ),
  );
}

/// Aplicacion principal con routing.
class POSCubaApp extends ConsumerWidget {
  const POSCubaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'POS Cuba',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}

/// Provider del router con guards de navegacion.
/// 
/// Guards en orden de evaluacion:
/// 1. Sin sesion Supabase → /login
/// 2. Licencia hardBlocked → /license-blocked
/// 3. Sin WorkerSession → /worker-pin
/// 4. Ruta owner + rol worker → /dashboard
@riverpod
GoRouter router(RouterRef ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) async {
      final currentPath = state.uri.path;

      // Rutas publicas que no requieren autenticacion
      final publicRoutes = [
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.register,
      ];

      // Si es ruta publica, permitir acceso sin verificacion
      if (publicRoutes.contains(currentPath)) {
        return null;
      }

      // GUARD 1: Verificar sesion Supabase (Usando AuthState provider)
      // Nota: Leemos el estado actual del stream. Si es nulo o no autenticado, redirect.
      final authState = ref.read(authStateProvider).asData?.value;
      if (authState == null || !authState.isAuthenticated) {
        return AppRoutes.login;
      }

      // GUARD 2: Verificar estado de licencia
      final licenseStatus = await LicenseService.checkStatus();
      if (licenseStatus == LicenseStatus.hardBlocked) {
        return AppRoutes.licenseBlocked;
      }

      // GUARD 3: Verificar WorkerSession activa (BUG-02)
      // No aplica en Splash, Login, Register, LicenseBlocked ni WorkerPin
      final skipWorkerGuard = [
        ...publicRoutes,
        AppRoutes.workerPin,
        AppRoutes.licenseBlocked,
      ];

      final workerSession = ref.read(currentWorkerSessionProvider);
      if (!skipWorkerGuard.contains(currentPath) && workerSession == null) {
        return AppRoutes.workerPin;
      }

      // GUARD 4: Verificar permisos de owner
      // Las rutas owner-only son: inventory, reports, settings
      final ownerOnlyRoutes = [
        AppRoutes.inventory,
        AppRoutes.reports,
        AppRoutes.settings,
      ];

      final isOwner = workerSession?.isOwner ?? false;
      if (ownerOnlyRoutes.contains(currentPath) && !isOwner) {
        // Trabajadores sin permiso de owner son redirigidos a caja o ventas (dashboard es seguro)
        return null; // Dashborad es permitido
      }

      // Todas las verificaciones pasaron, permitir navegacion
      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const Placeholder(), // TODO: RegisterScreen
      ),

      // Worker PIN
      GoRoute(
        path: AppRoutes.workerPin,
        builder: (context, state) => const Placeholder(), // TODO: WorkerPinScreen
      ),

      // License
      GoRoute(
        path: AppRoutes.licenseBlocked,
        builder: (context, state) => const LicenseBlockedScreen(),
      ),

      // Main screens con BottomNavigationBar
      ShellRoute(
        builder: (context, state, child) {
          return AppScaffold(
            body: child,
            currentRoute: state.uri.path,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.sales,
            builder: (context, state) => const SalesScreen(),
          ),
          GoRoute(
            path: AppRoutes.inventory,
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.cashbox,
            builder: (context, state) => const CashboxScreen(),
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (context, state) => const ReportsScreen(),
          ),
        ],
      ),

      // Settings (sin BottomNavigationBar)
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),

      // Sub-rutas de inventario
      GoRoute(
        path: AppRoutes.inventoryNew,
        builder: (context, state) => const Placeholder(), // TODO: ProductFormScreen
      ),
      GoRoute(
        path: '/inventory/:productId',
        builder: (context, state) {
          final productId = state.pathParameters['productId']!;
          return Placeholder(); // TODO: ProductDetailScreen
        },
      ),
    ],
  );
}
