// lib/providers/auth_provider.dart
// Provider de autenticacion con Supabase Auth.

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/remote/supabase_client.dart';

part 'auth_provider.g.dart';

/// Estado de autenticacion.
@riverpod
class AuthState extends _$AuthState {
  @override
  Stream<AuthStateData> build() {
    return Supabase.instance.client.auth.onAuthStateChange.map((event) {
      return AuthStateData(
        user: event.session?.user,
        isAuthenticated: event.session != null,
      );
    });
  }

  /// Inicia sesion con email y password.
  Future<void> signIn(String email, String password) async {
    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Registra un nuevo usuario.
  Future<void> signUp(String email, String password, {String? name}) async {
    await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
  }

  /// Cierra sesion.
  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
}

/// Datos del estado de autenticacion.
class AuthStateData {
  final User? user;
  final bool isAuthenticated;

  const AuthStateData({
    this.user,
    this.isAuthenticated = false,
  });

  String get userId => user?.id ?? '';
  String get displayName => user?.userMetadata?['name'] as String? ??
      user?.email ??
      'Usuario';
}
