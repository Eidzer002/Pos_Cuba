// lib/core/constants/app_routes.dart
// Rutas de la aplicacion usando go_router.
// NUNCA hardcodear rutas como strings en los widgets.

class AppRoutes {
  // Rutas publicas
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';

  // Rutas de licencia
  static const String workerPin = '/worker-pin';
  static const String licenseBlocked = '/license-blocked';
  static const String licenseWarning = '/license-warning';
  static const String trial = '/trial';

  // Rutas principales (con BottomNavigationBar)
  static const String dashboard = '/dashboard';
  static const String sales = '/sales';
  static const String inventory = '/inventory';
  static const String cashbox = '/cashbox';
  static const String reports = '/reports';
  static const String settings = '/settings';

  // Sub-rutas de ventas
  static const String saleReceipt = 'receipt/:saleId';
  static String saleReceiptPath(String saleId) => '/sales/receipt/$saleId';

  // Sub-rutas de inventario
  static const String productNew = 'new';
  static const String productEdit = ':productId';
  static const String productHistory = ':productId/history';
  static String productEditPath(String productId) => '/inventory/$productId';
  static String productHistoryPath(String productId) => '/inventory/$productId/history';
  static const String inventoryNew = '/inventory/new';

  // Sub-rutas de configuracion
  static const String categories = 'categories';
  static const String workers = 'workers';
  static const String backup = 'backup';
  static const String workersNew = 'new';
  static const String workerEdit = ':workerId';
  static String workerEditPath(String workerId) => '/settings/workers/$workerId';
  static const String settingsWorkersNew = '/settings/workers/new';

  // Rutas solo para owner
  static const List<String> ownerOnlyRoutes = [
    inventory,
    reports,
    settings,
  ];

  // Rutas publicas (sin autenticacion)
  static const List<String> publicRoutes = [
    splash,
    login,
    register,
    licenseBlocked,
  ];
}
