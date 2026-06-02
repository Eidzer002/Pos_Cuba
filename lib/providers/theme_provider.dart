// lib/providers/theme_provider.dart
// Provider de tema con persistencia en SharedPreferences.
// El usuario puede elegir: claro, oscuro o sistema.
// La preferencia se guarda localmente y persiste entre reinicios.

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_provider.g.dart';

const _kThemeKey = 'app_theme_mode';

/// Lee el ThemeMode guardado en SharedPreferences.
/// Retorna ThemeMode.system si no hay nada guardado.
Future<ThemeMode> _loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kThemeKey);
  switch (saved) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

/// Guarda el ThemeMode en SharedPreferences.
Future<void> _saveThemeMode(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  switch (mode) {
    case ThemeMode.light:
      await prefs.setString(_kThemeKey, 'light');
    case ThemeMode.dark:
      await prefs.setString(_kThemeKey, 'dark');
    case ThemeMode.system:
      await prefs.remove(_kThemeKey);
  }
}

/// Provider de ThemeMode con persistencia.
/// Se inicializa leyendo SharedPreferences (async).
@riverpod
class AppThemeMode extends _$AppThemeMode {
  @override
  Future<ThemeMode> build() async {
    return _loadThemeMode();
  }

  /// Cambia el tema y lo persiste inmediatamente.
  Future<void> setTheme(ThemeMode mode) async {
    state = AsyncValue.data(mode);
    await _saveThemeMode(mode);
  }

  /// Alterna entre claro y oscuro (omite sistema).
  Future<void> toggle() async {
    final current = state.valueOrNull ?? ThemeMode.system;
    final next = current == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setTheme(next);
  }
}
