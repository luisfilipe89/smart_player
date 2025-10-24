import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart';
import 'favorites_service_instance.dart';

/// FavoritesService provider with dependency injection
final favoritesServiceProvider = Provider<FavoritesServiceInstance>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FavoritesServiceInstance(prefs);
});

/// Favorites list provider (reactive)
final favoritesListProvider = FutureProvider<Set<String>>((ref) {
  final favoritesService = ref.watch(favoritesServiceProvider);
  return favoritesService.getFavorites();
});

/// Favorites actions provider
final favoritesActionsProvider = Provider<FavoritesActions>((ref) {
  final favoritesService = ref.watch(favoritesServiceProvider);
  return FavoritesActions(favoritesService);
});

/// Helper class for favorites actions
class FavoritesActions {
  final FavoritesServiceInstance _favoritesService;

  FavoritesActions(this._favoritesService);

  Future<Set<String>> getFavorites() => _favoritesService.getFavorites();
  Future<void> toggleFavorite(String id) =>
      _favoritesService.toggleFavorite(id);
  Future<bool> isFavorite(String id) => _favoritesService.isFavorite(id);
}
