import 'package:flutter/material.dart';
import 'dart:convert';

/// Memoized widget that caches widget instances based on data hash
class MemoizedWidget extends StatefulWidget {
  final Widget Function() builder;
  final String cacheKey;
  final Duration? ttl;
  final bool enabled;

  const MemoizedWidget({
    super.key,
    required this.builder,
    required this.cacheKey,
    this.ttl,
    this.enabled = true,
  });

  @override
  State<MemoizedWidget> createState() => _MemoizedWidgetState();
}

class _MemoizedWidgetState extends State<MemoizedWidget> {
  static final Map<String, _CachedWidget> _cache = {};
  Widget? _cachedWidget;

  @override
  void initState() {
    super.initState();
    _updateCachedWidget();
  }

  @override
  void didUpdateWidget(MemoizedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.enabled != widget.enabled) {
      _updateCachedWidget();
    }
  }

  void _updateCachedWidget() {
    if (!widget.enabled) {
      _cachedWidget = null;
      return;
    }

    final now = DateTime.now();
    final cached = _cache[widget.cacheKey];

    if (cached != null &&
        (widget.ttl == null ||
            now.difference(cached.timestamp) < widget.ttl!)) {
      _cachedWidget = cached.widget;
    } else {
      _cachedWidget = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _cachedWidget == null) {
      final widget = this.widget.builder();
      if (this.widget.enabled) {
        _cache[this.widget.cacheKey] = _CachedWidget(
          widget: widget,
          timestamp: DateTime.now(),
        );
        _cachedWidget = widget;
      }
      return widget;
    }

    return _cachedWidget!;
  }

  @override
  void dispose() {
    // Clean up expired cache entries
    final now = DateTime.now();
    _cache.removeWhere((key, cached) {
      return widget.ttl != null &&
          now.difference(cached.timestamp) > widget.ttl!;
    });
    super.dispose();
  }
}

class _CachedWidget {
  final Widget widget;
  final DateTime timestamp;

  _CachedWidget({required this.widget, required this.timestamp});
}

/// Hook-like pattern for memoized values
class MemoizedValue<T> {
  final T Function() computation;
  final String key;
  final Duration? ttl;

  T? _cachedValue;
  DateTime? _lastComputed;
  String? _lastKey;

  MemoizedValue({
    required this.computation,
    required this.key,
    this.ttl,
  });

  T get value {
    final now = DateTime.now();

    if (_cachedValue != null &&
        _lastKey == key &&
        (ttl == null ||
            _lastComputed != null && now.difference(_lastComputed!) < ttl!)) {
      return _cachedValue!;
    }

    _cachedValue = computation();
    _lastComputed = now;
    _lastKey = key;
    return _cachedValue!;
  }

  void invalidate() {
    _cachedValue = null;
    _lastComputed = null;
    _lastKey = null;
  }
}

/// Memoized builder widget
class MemoizedBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) builder;
  final String cacheKey;
  final Duration? ttl;
  final bool enabled;

  const MemoizedBuilder({
    super.key,
    required this.builder,
    required this.cacheKey,
    this.ttl,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return MemoizedWidget(
      cacheKey: cacheKey,
      ttl: ttl,
      enabled: enabled,
      builder: () => builder(context),
    );
  }
}

/// Utility for creating cache keys from objects
class CacheKeyBuilder {
  static String fromObject(Object? object) {
    if (object == null) return 'null';
    if (object is String) return 'str_$object';
    if (object is int) return 'int_$object';
    if (object is double) return 'dbl_${object.toStringAsFixed(2)}';
    if (object is bool) return 'bool_$object';
    if (object is List) return 'list_${object.length}_${object.hashCode}';
    if (object is Map) return 'map_${object.length}_${object.hashCode}';

    // For complex objects, use JSON encoding
    try {
      final json = jsonEncode(object);
      return 'json_${json.hashCode}';
    } catch (e) {
      return 'obj_${object.hashCode}';
    }
  }

  static String fromObjects(List<Object?> objects) {
    return objects.map((obj) => fromObject(obj)).join('_');
  }
}

/// Mixin for widgets that need to keep their state alive
/// Note: This is just a marker mixin. Use AutomaticKeepAliveClientMixin directly for actual keep-alive functionality.
mixin KeepAliveMixin<T extends StatefulWidget> on State<T> {
  // This mixin is intentionally empty and serves as a marker
  // For actual keep-alive functionality, use AutomaticKeepAliveClientMixin
}

/// Optimized list item widget
class OptimizedListItem extends StatefulWidget {
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int itemCount;
  final String? itemKey;
  final Duration? ttl;
  final bool keepAlive;

  const OptimizedListItem({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    this.itemKey,
    this.ttl,
    this.keepAlive = true,
  });

  @override
  State<OptimizedListItem> createState() => _OptimizedListItemState();
}

class _OptimizedListItemState extends State<OptimizedListItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return MemoizedBuilder(
      cacheKey: widget.itemKey ?? 'item_${widget.hashCode}',
      ttl: widget.ttl,
      builder: (context) => widget.itemBuilder(context, 0),
    );
  }
}
