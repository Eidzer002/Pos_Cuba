// lib/core/constants/app_config.dart
// Lee las variables de entorno pasadas con --dart-define al compilar.
// Ejemplo de compilacion: flutter run
// --dart-define=SUPABASE_URL=https://...
// --dart-define=SUPABASE_ANON_KEY=eyJ...
// --dart-define=POWERSYNC_URL=https://...

class AppConfig {
  // Variables de entorno obligatorias
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String powerSyncUrl = String.fromEnvironment('POWERSYNC_URL');

  // Configuracion de licencias
  static const int trialDays = 7;
  static const int gracePeriodDays = 7;
  static const int softBlockSalesLimit = 5;

  // Configuracion de PIN
  static const int pinMinLength = 4;
  static const int pinMaxLength = 6;

  // Configuracion de moneda por defecto
  static const String defaultCurrencySymbol = '\$';

  // Configuracion de stock
  static const int defaultMinStock = 5;

  // Verificar que las variables de entorno esten configuradas
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        powerSyncUrl.isNotEmpty;
  }
}
