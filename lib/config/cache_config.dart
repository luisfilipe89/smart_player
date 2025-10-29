import 'package:flutter_riverpod/flutter_riverpod.dart';

class CacheConfig {
  final Duration gamesTtl;
  final Duration friendsTtl;
  const CacheConfig({
    this.gamesTtl = const Duration(minutes: 5),
    this.friendsTtl = const Duration(minutes: 5),
  });
}

final cacheConfigProvider = Provider<CacheConfig>((_) => const CacheConfig());
