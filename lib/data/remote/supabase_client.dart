// lib/data/remote/supabase_client.dart
// Cliente de Supabase con inicializacion y utilidades.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_config.dart';

/// Inicializa Supabase con las credenciales de entorno.
/// 
/// Llamar en main() antes de runApp():
/// ```dart
/// await initSupabase();
/// ```
Future<void> initSupabase() async {
  if (!AppConfig.isConfigured) {
    throw Exception(
      'Variables de entorno no configuradas. '
      'Asegurate de pasar --dart-define=SUPABASE_URL=... '
      '--dart-define=SUPABASE_ANON_KEY=... al compilar.',
    );
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
}

/// Acceso rapido al cliente de Supabase.
/// 
/// Ejemplo: SupabaseClient.instance.auth.currentUser
class SupabaseClient {
  SupabaseClient._(); // No instanciar

  static SupabaseClient get instance => Supabase.instance.client;

  /// Verifica si hay una sesion activa.
  static bool get isAuthenticated =>
      Supabase.instance.client.auth.currentSession != null;

  /// Obtiene el usuario actual.
  static User? get currentUser =>
      Supabase.instance.client.auth.currentUser;

  /// Obtiene el ID del usuario actual.
  static String? get currentUserId => currentUser?.id;

  /// Cierra la sesion actual.
  static Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
}

/// Extensiones utiles para Supabase User
extension UserExtensions on User? {
  /// Verifica si el usuario tiene email confirmado.
  bool get isEmailConfirmed => this?.emailConfirmedAt != null;

  /// Obtiene el nombre del usuario o el email como fallback.
  String get displayName => this?.userMetadata?['name'] as String? ??
      this?.email ??
      'Usuario';
}
