// lib/providers/category_provider.dart
// Providers para categorías de productos.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/category.dart';
import '../data/repositories/category_repository.dart';
import '../services/powersync_service.dart';
import 'business_provider.dart';

part 'category_provider.g.dart';

// ---------------------------------------------------------------------------
// Repositorio singleton para CategoryRepository.
// ---------------------------------------------------------------------------

@riverpod
CategoryRepository categoryRepository(CategoryRepositoryRef ref) {
  return CategoryRepository(PowerSyncService.db);
}

// ---------------------------------------------------------------------------
// categoriesProvider(businessId)
// Stream reactivo de categorías activas del negocio (deleted_at IS NULL),
// ordenadas por sort_order ASC.
// ---------------------------------------------------------------------------

@riverpod
Stream<List<Category>> categories(
  CategoriesRef ref,
  String businessId,
) {
  return ref
      .watch(categoryRepositoryProvider)
      .watchCategories(businessId);
}

// ---------------------------------------------------------------------------
// Acceso conveniente derivado del negocio actual (sin pasar businessId).
// ---------------------------------------------------------------------------

/// Categorías del negocio autenticado actualmente.
@riverpod
Stream<List<Category>> currentBusinessCategories(
  CurrentBusinessCategoriesRef ref,
) {
  final businessAsync = ref.watch(currentBusinessProvider);
  final businessId = businessAsync.valueOrNull?.id ?? '';
  if (businessId.isEmpty) return Stream.value([]);

  return ref
      .watch(categoryRepositoryProvider)
      .watchCategories(businessId);
}

// ---------------------------------------------------------------------------
// CategoryOperations — mutaciones (crear, actualizar, eliminar).
// ---------------------------------------------------------------------------

@riverpod
class CategoryOperations extends _$CategoryOperations {
  @override
  FutureOr<void> build() {}

  Future<void> create(Category category) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(categoryRepositoryProvider).createCategory(category);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> update(Category category) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(categoryRepositoryProvider).updateCategory(category);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> delete(String id, String businessId) async {
    state = const AsyncValue.loading();
    try {
      await ref
          .read(categoryRepositoryProvider)
          .deleteCategory(id, businessId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
