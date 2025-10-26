import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Helper to create in-memory SQLite databases for testing
class TestDbHelper {
  static Future<Database> createInMemoryDb({
    int version = 1,
    String? onCreate,
  }) async {
    sqfliteFfiInit();

    return await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: onCreate != null
            ? (database, version) async {
                await database.execute(onCreate);
              }
            : null,
      ),
    );
  }

  /// Create a database with a specific schema
  static Future<Database> createDbWithSchema({
    required String schema,
    int version = 1,
  }) async {
    return await createInMemoryDb(
      version: version,
      onCreate: schema,
    );
  }

  /// Initialize FFI if needed
  static void initializeFfi() {
    try {
      sqfliteFfiInit();
    } catch (e) {
      // Already initialized
    }
  }
}
