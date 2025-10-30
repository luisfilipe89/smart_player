import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized cache configuration with TTL values
///
/// This configuration is used by CacheServiceInstance to determine
/// how long different types of cached data should be kept.
/// Adjust these values based on your app's needs without modifying service code.
class CacheConfig {
  /// Time-to-live for user profile cache (default: 1 hour)
  final Duration userProfileTtl;

  /// Time-to-live for game details cache (default: 30 minutes)
  final Duration gameDetailsTtl;

  /// Time-to-live for public games list cache (default: 5 minutes)
  final Duration publicGamesTtl;

  /// Time-to-live for games list cache (legacy, used by CacheMixin)
  final Duration gamesTtl;

  /// Time-to-live for friends list cache (legacy, used by CacheMixin)
  final Duration friendsTtl;

  const CacheConfig({
    this.userProfileTtl = const Duration(hours: 1),
    this.gameDetailsTtl = const Duration(minutes: 30),
    this.publicGamesTtl = const Duration(minutes: 5),
    this.gamesTtl = const Duration(minutes: 5),
    this.friendsTtl = const Duration(minutes: 5),
  });
}

final cacheConfigProvider = Provider<CacheConfig>((_) => const CacheConfig());
