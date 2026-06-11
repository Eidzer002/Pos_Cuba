// lib/core/constants/app_routes.dart
// Rutas de la aplicacion usando go_router.
// NUNCA hardcodear rutas como strings en los widgets.
//
// FIX ARCH-3: eliminadas rutas sin GoRoute registrado (dead code):
//   - licenseWarning, trial → pendientes de implementar
//   - saleReceipt / saleReceiptPath → el recibo se muestra via bottomsheet, no navegación
//   - productHistory → pendiente de implementar

class AppRoutes {
  // ── Rutas públicas ────────────────────────────────────────────────────────
  static const String splash   = '/splash';
  static const String login    = '/login';
  static const String register = '/register';

  // ── Rutas de licencia ─────────────────────────────────────────────────────
  static const String workerPin      = '/worker-pin';
  static const String licenseBlocked = '/license-blocked';
  // Pendiente de implementar (no hay GoRoute registrado aún):
  // static const String licenseWarning = '/license-warning';
  // static const String trial          = '/trial';

  // ── Rutas principales (con BottomNavigationBar) ───────────────────────────
  static const String dashboard = '/dashboard';
  static const String sales     = '/sales';
  static const String inventory = '/inventory';
  static const String cashbox   = '/cashbox';
  static const String reports   = '/reports';
  static const String settings  = '/settings';

  // ── Sub-rutas de inventario ───────────────────────────────────────────────
  static const String productNew  = 'new';
  static const String productEdit = ':productId';
  // Pendiente de implementar (no hay GoRoute registrado aún):
  // static const String productHistory = ':productId/history';

  static String productEditPath(String productId) => '/inventory/$productId';
  static const String inventoryNew = '/inventory/new';

  // ── Sub-rutas de configuración ────────────────────────────────────────────
  static const String categories        = 'categories';
  static const String workers           = 'workers';
  static const String backup            = 'backup';
  static const String workersNew        = 'new';
  static const String workerEdit        = ':workerId';
  static const String settingsWorkersNew = '/settings/workers/new';

  static String workerEditPath(String workerId) => '/settings/workers/$workerId';

  // ── Listas de control de acceso ───────────────────────────────────────────

  /// Rutas accesibles solo por el dueño (no por trabajadores con PIN).
  static const List<String> ownerOnlyRoutes = [
    inventory,
    reports,
    settings,
  ];

  /// Rutas públicas (sin autenticación requerida).
  static const List<String> publicRoutes = [
    splash,
    login,
    register,
    licenseBlocked,
  ];
}
