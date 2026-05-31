// lib/providers/business_provider.dart
// Provider del negocio actual del usuario autenticado.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/business.dart';
import '../data/repositories/business_repository.dart';
import '../services/powersync_service.dart';
import 'auth_provider.dart';

part 'business_provider.g.dart';

// ---------------------------------------------------------------------------
// Repositorio singleton para BusinessRepository.
// ---------------------------------------------------------------------------

@riverpod
BusinessRepository businessRepository(BusinessRepositoryRef ref) {
  return BusinessRepository(PowerSyncService.db);
}

// ---------------------------------------------------------------------------
// selectedBusinessIdProvider
// ID del negocio activo — derivado del negocio del usuario autenticado.
// Usado por los repositorios de cashbox, workers, sales y reports.
// ---------------------------------------------------------------------------

@riverpod
String? selectedBusinessId(SelectedBusinessIdRef ref) {
  final businessAsync = ref.watch(currentBusinessProvider);
  return businessAsync.valueOrNull?.id;
}


// ---------------------------------------------------------------------------
// currentBusinessProvider
// Retorna AsyncValue<Business?> — stream reactivo sobre el negocio del
// usuario autenticado. Si no hay sesión, emite null inmediatamente.
// ---------------------------------------------------------------------------

@riverpod
Stream<Business?> currentBusiness(CurrentBusinessRef ref) {
  final authAsync = ref.watch(authStateProvider);

  // Mientras no haya sesión autenticada, emitir null sin query.
  final userId = authAsync.valueOrNull?.userId ?? '';
  if (userId.isEmpty) return Stream.value(null);

  return ref
      .watch(businessRepositoryProvider)
      .watchBusiness(userId);
}

// ---------------------------------------------------------------------------
// currencySymbolProvider
// Derivado de currentBusiness — nunca hardcodea el símbolo (BUG-04).
// ---------------------------------------------------------------------------

@riverpod
String currencySymbol(CurrencySymbolRef ref) {
  final businessAsync = ref.watch(currentBusinessProvider);
  return businessAsync.when(
    data: (business) => business?.currencySymbol ?? 'CUP',
    loading: () => 'CUP',
    error: (_, __) => 'CUP',
  );
}

// ---------------------------------------------------------------------------
// userBusinessesProvider
// Stream de todos los negocios del usuario (para el selector inicial).
// ---------------------------------------------------------------------------

@riverpod
Stream<List<Business>> userBusinesses(UserBusinessesRef ref) {
  final userId = ref.watch(authStateProvider).valueOrNull?.userId ?? '';
  if (userId.isEmpty) return Stream.value([]);

  return PowerSyncService.db
      .watch(
        'SELECT * FROM businesses WHERE owner_id = ? ORDER BY name ASC',
        parameters: [userId],
      )
      .map((rs) => rs.map(Business.fromRow).toList());
}
