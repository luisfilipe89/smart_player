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

  /// Get the age of the cached data
  Duration get age => DateTime.now().difference(timestamp);

  /// Check if the data is still fresh (not expired)
  bool get isFresh => !isExpired;
}
