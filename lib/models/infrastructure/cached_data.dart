/// Represents cached data with timestamp for expiry checking
class CachedData<T> {
  final T data;
  final DateTime timestamp;
  final Duration? expiry;

  CachedData(this.data, this.timestamp, {this.expiry});

  /// Check if the cached data has expired
  bool get isExpired {
    if (expiry == null) return false;
    return DateTime.now().difference(timestamp) > expiry!;
  }
}
