import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:move_young/utils/background_processor.dart';
import 'dart:typed_data';

// Top-level function for background image compression
Uint8List _compressImageIsolate(Uint8List data) {
  // Simple compression by reducing quality (in a real app, you'd use image processing libraries)
  // For now, just return the original data
  return data;
}

class ImageCacheService {
  static const int _memoryCacheSize = 100 * 1024 * 1024; // 100MB

  static bool _initialized = false;

  /// Initialize the image cache service with custom settings
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Configure Flutter's image cache
      PaintingBinding.instance.imageCache.maximumSize = 1000; // Max 1000 images
      PaintingBinding.instance.imageCache.maximumSizeBytes = _memoryCacheSize;

      // Initialize CachedNetworkImage configuration
      await _configureCachedNetworkImage();

      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize ImageCacheService: $e');
    }
  }

  /// Configure CachedNetworkImage with custom settings
  static Future<void> _configureCachedNetworkImage() async {
    // This is handled by the CachedNetworkImage widget configuration
    // The actual configuration happens when we create the widgets
  }

  /// Get optimized CachedNetworkImage widget with size constraints
  static Widget getOptimizedImage({
    required String imageUrl,
    required double? width,
    required double? height,
    BoxFit fit = BoxFit.cover,
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
    Duration fadeInDuration = const Duration(milliseconds: 300),
    Curve fadeInCurve = Curves.easeInOut,
  }) {
    // Handle infinity values for width/height
    int? memCacheWidth;
    int? memCacheHeight;

    if (width != null && width.isFinite) {
      memCacheWidth = width.toInt();
    }
    if (height != null && height.isFinite) {
      memCacheHeight = height.toInt();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width?.isFinite == true ? width : null,
      height: height?.isFinite == true ? height : null,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: fadeInDuration,
      fadeInCurve: fadeInCurve,
      placeholder: placeholder ??
          (BuildContext context, String url) =>
              _buildShimmerPlaceholder(width, height),
      errorWidget: errorWidget ??
          (BuildContext context, String url, dynamic error) =>
              _buildErrorWidget(width, height),
      // Cache configuration
      cacheManager: DefaultCacheManager(),
    );
  }

  /// Get optimized avatar image with circular clipping
  static Widget getOptimizedAvatar({
    required String? imageUrl,
    required double radius,
    String? fallbackText,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey[300],
        foregroundColor: foregroundColor ?? Colors.grey[600],
        child: fallbackText != null
            ? Text(fallbackText, style: TextStyle(fontSize: radius * 0.6))
            : Icon(Icons.person, size: radius * 0.8),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      backgroundImage: CachedNetworkImageProvider(
        imageUrl,
        cacheManager: DefaultCacheManager(),
      ),
      child: fallbackText != null
          ? Text(fallbackText, style: TextStyle(fontSize: radius * 0.6))
          : null,
    );
  }

  /// Preload images for better performance
  static Future<void> preloadImages(
      BuildContext context, List<String> imageUrls) async {
    for (final url in imageUrls) {
      if (url.isNotEmpty) {
        try {
          await precacheImage(
            CachedNetworkImageProvider(url,
                cacheManager: DefaultCacheManager()),
            context,
          );
        } catch (e) {
          debugPrint('Failed to preload image $url: $e');
        }
      }
    }
  }

  /// Clear image cache
  static Future<void> clearCache() async {
    try {
      PaintingBinding.instance.imageCache.clear();
      await DefaultCacheManager().emptyCache();
    } catch (e) {
      debugPrint('Failed to clear image cache: $e');
    }
  }

  /// Build shimmer placeholder
  static Widget _buildShimmerPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  /// Build error widget
  static Widget _buildErrorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    final imageCache = PaintingBinding.instance.imageCache;
    return {
      'currentSize': imageCache.currentSize,
      'currentSizeBytes': imageCache.currentSizeBytes,
      'maximumSize': imageCache.maximumSize,
      'maximumSizeBytes': imageCache.maximumSizeBytes,
    };
  }

  /// Compress image in background for large images
  static Future<Uint8List> compressImage(Uint8List imageData) async {
    if (imageData.length > 1024 * 1024) { // > 1MB
      return await BackgroundProcessor.processInBackground(
        computation: _compressImageIsolate,
        data: imageData,
        debugLabel: 'Compress Image',
      );
    }
    return imageData;
  }
}
