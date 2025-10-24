import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'image_cache_service_instance.dart';

// Image cache service provider
final imageCacheServiceProvider = Provider<ImageCacheServiceInstance>((ref) {
  return ImageCacheServiceInstance();
});

// Image cache actions provider
final imageCacheActionsProvider = Provider<ImageCacheActions>((ref) {
  final imageCacheService = ref.watch(imageCacheServiceProvider);
  return ImageCacheActions(imageCacheService);
});

class ImageCacheActions {
  final ImageCacheServiceInstance _imageCacheService;

  ImageCacheActions(this._imageCacheService);

  Future<void> initialize() async {
    await _imageCacheService.initialize();
  }

  Future<void> clearCache() async {
    await _imageCacheService.clearCache();
  }

  Map<String, dynamic> getCacheStats() {
    return _imageCacheService.getCacheStats();
  }

  Future<Uint8List> compressImage(Uint8List imageData) async {
    return await _imageCacheService.compressImage(imageData);
  }
}
