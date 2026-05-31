// lib/services/powersync_service.dart
// Servicio para inicializar y configurar PowerSync.

import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_config.dart';
import '../data/local/powersync_schema.dart';

/// Conector de PowerSync a Supabase.
class SupabasePowerSyncConnector implements PowerSyncBackendConnector {
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return null;

    return PowerSyncCredentials(
      endpoint: AppConfig.powerSyncUrl,
      token: session.accessToken,
    );
  }
}

/// Servicio para gestionar PowerSync.
class PowerSyncService {
  static late PowerSyncDatabase db;

  PowerSyncService._(); // No instanciar

  /// Inicializa PowerSync con el schema de la app.
  /// 
  /// Llamar en main() antes de runApp():
  /// ```dart
  /// await PowerSyncService.initialize();
  /// ```
  static Future<void> initialize() async {
    db = PowerSyncDatabase(schema: appSchema);
    await db.open();

    // Conectar solo si hay sesion de Supabase
    if (Supabase.instance.client.auth.currentSession != null) {
      await db.connect(connector: SupabasePowerSyncConnector());
    }
  }

  /// Conecta a Supabase cuando el usuario inicia sesion.
  static Future<void> connect() async {
    if (Supabase.instance.client.auth.currentSession != null) {
      await db.connect(connector: SupabasePowerSyncConnector());
    }
  }

  /// Desconecta de Supabase cuando el usuario cierra sesion.
  static Future<void> disconnect() async {
    await db.disconnect();
  }

  /// Verifica si esta conectado a Supabase.
  static bool get isConnected => db.currentStatus.connected;

  /// Stream del estado de sincronizacion.
  static Stream<SyncStatus> get statusStream => db.statusStream;

  /// Estado actual de sincronizacion.
  static SyncStatus get currentStatus => db.currentStatus;
}
