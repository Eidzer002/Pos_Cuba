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
import 'presentation/screens/auth/worker_pin_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/inventory/product_form_screen.dart';

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
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
    // Escuchar el tema guardado — ThemeMode.system mientras carga
    final themeMode = ref.watch(appThemeModeProvider).valueOrNull ?? ThemeMode.system;

    return MaterialApp.router(
      title: 'POS Cuba',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

// ---------------------------------------------------------------------------
// FIX BUG-A: RouterListenable — notifica al router cuando cambia auth o
// workerSession para que re-evalúe los redirects automáticamente.
// Sin esto, cerrar sesión no redirige al login.
// ---------------------------------------------------------------------------

class _RouterListenable extends ChangeNotifier {
  _RouterListenable(Ref ref) {
    // Escuchar cambios de auth de Supabase
    ref.listen<AsyncValue<AuthStateData>>(authStateProvider, (_, __) {
      notifyListeners();
    });
    // Escuchar cambios de sesión de trabajador
    ref.listen<WorkerSessionData?>(workerSessionProvider, (_, __) {
      notifyListeners();
    });
  }
}

@Riverpod(keepAlive: true)
Raw<_RouterListenable> routerListenable(RouterListenableRef ref) {
  final listenable = _RouterListenable(ref);
  ref.onDispose(listenable.dispose);
  return listenable;
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
  // FIX BUG-A: refreshListenable re-ejecuta redirect cuando auth o workerSession cambian
  final listenable = ref.watch(routerListenableProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: listenable,
    redirect: (context, state) async {
      final currentPath = state.uri.path;

      // Rutas publicas que no requieren autenticacion
      final publicRoutes = [
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.register,
      ];

      // Si es ruta publica, permitir acceso sin verificacion
      if (publicRoutes.contains(currentPath)) return null;

      // GUARD 1: Verificar sesion Supabase
      final authState = ref.read(authStateProvider).asData?.value;
      if (authState == null || !authState.isAuthenticated) {
        return AppRoutes.login;
      }

      // GUARD 2: Verificar estado de licencia
      final licenseStatus = await LicenseService.checkStatus();
      if (licenseStatus == LicenseStatus.hardBlocked) {
        return AppRoutes.licenseBlocked;
      }

      // GUARD 3: Verificar WorkerSession activa (FIX BUG-02)
      final skipWorkerGuard = [
        ...publicRoutes,
        AppRoutes.workerPin,
        AppRoutes.licenseBlocked,
      ];

      final workerSession = ref.read(workerSessionProvider);
      if (!skipWorkerGuard.contains(currentPath) && workerSession == null) {
        return AppRoutes.workerPin;
      }

      // GUARD 4: Verificar permisos de owner
      // FIX BUG-B: Redirigir a dashboard cuando worker intenta acceder a ruta owner
      final ownerOnlyRoutes = AppRoutes.ownerOnlyRoutes;
      final isOwner = workerSession?.isOwner ?? false;
      if (ownerOnlyRoutes.contains(currentPath) && !isOwner) {
        return AppRoutes.dashboard;
      }

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
        builder: (context, state) => const RegisterScreen(),
      ),

      // Worker PIN
      GoRoute(
        path: AppRoutes.workerPin,
        builder: (context, state) => const WorkerPinScreen(),
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
        routes: [
          GoRoute(
            path: AppRoutes.backup,
            builder: (context, state) => const BackupScreen(),
          ),
        ],
      ),

      // Sub-rutas de inventario
      GoRoute(
        path: AppRoutes.inventoryNew,
        builder: (context, state) => const ProductFormScreen(),
      ),
      GoRoute(
        path: '/inventory/:productId',
        builder: (context, state) {
          final productId = state.pathParameters['productId']!;
          return ProductFormScreen(productId: productId);
        },
      ),
    ],
  );
}
