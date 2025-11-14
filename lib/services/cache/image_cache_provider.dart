import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'image_cache_service_instance.dart';

// Image cache service provider
final imageCacheServiceProvider = Provider<ImageCacheServiceInstance>((ref) {
  return ImageCacheServiceInstance();
});
