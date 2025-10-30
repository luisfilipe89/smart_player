/// Provider for game repository
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'game_repository.dart';
import '../services/games/cloud_games_provider.dart';

/// Game repository provider
final gameRepositoryProvider = Provider<IGameRepository>((ref) {
  final cloudService = ref.watch(cloudGamesServiceProvider);
  return GameRepository(cloudService);
});

