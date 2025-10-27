/// Helper for testing - SQLite has been removed
/// This file is kept for compatibility but does nothing
class TestDbHelper {
  /// Initialize FFI (no-op, SQLite removed)
  static void initializeFfi() {
    // SQLite has been removed from the app
    // This method does nothing but keeps tests from breaking
  }

  /// Create in-memory DB (no-op, SQLite removed)
  static Future<void> createInMemoryDb({
    int version = 1,
    String? onCreate,
  }) async {
    // SQLite has been removed from the app
    // This method does nothing but keeps tests from breaking
  }

  /// Create DB with schema (no-op, SQLite removed)
  static Future<void> createDbWithSchema({
    required String schema,
    int version = 1,
  }) async {
    // SQLite has been removed from the app
    // This method does nothing but keeps tests from breaking
  }
}
