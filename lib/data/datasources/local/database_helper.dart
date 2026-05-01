import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../../core/constants/app_constants.dart';

/// SQLite database helper for local storage
class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._();

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create trips table
    await db.execute('''
      CREATE TABLE trips (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        description TEXT,
        imageUrl TEXT,
        userId TEXT NOT NULL,
        participantIds TEXT,
        isShared INTEGER DEFAULT 0,
        shareCode TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Create stops table
    await db.execute('''
      CREATE TABLE stops (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        note TEXT,
        durationMinutes INTEGER DEFAULT 60,
        orderIndex INTEGER NOT NULL,
        dayNumber INTEGER DEFAULT 1,
        arrivalTime TEXT,
        departureTime TEXT,
        transportType TEXT DEFAULT 'car',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (tripId) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    // Create tags table
    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        stopId TEXT NOT NULL,
        name TEXT NOT NULL,
        color TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (stopId) REFERENCES stops (id) ON DELETE CASCADE
      )
    ''');

    // Create expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        currency TEXT DEFAULT 'USD',
        date TEXT NOT NULL,
        userId TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (tripId) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    // Create sync metadata table
    await db.execute('''
      CREATE TABLE sync_metadata (
        id TEXT PRIMARY KEY,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        lastSyncedAt TEXT NOT NULL,
        syncStatus TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE stops ADD COLUMN dayNumber INTEGER DEFAULT 1;',
      );
    }
    if (oldVersion < 3) {
      // Check if column already exists (in case user had a partial update)
      var tableInfo = await db.rawQuery('PRAGMA table_info(trips)');
      bool columnExists = tableInfo.any((column) => column['name'] == 'participantIds');
      
      if (!columnExists) {
        await db.execute(
          'ALTER TABLE trips ADD COLUMN participantIds TEXT;',
        );
      }
    }
  }

  // Trip CRUD operations
  Future<int> insertTrip(Map<String, dynamic> trip) async {
    final db = await database;
    final Map<String, dynamic> mutableTrip = Map.from(trip);
    if (mutableTrip['participantIds'] is List) {
      mutableTrip['participantIds'] = (mutableTrip['participantIds'] as List).join(',');
    }
    return await db.insert(
      'trips',
      mutableTrip,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTrips(String userId) async {
    final db = await database;
    return await db.query(
      'trips',
      where: 'userId = ? OR participantIds LIKE ?',
      whereArgs: [userId, '%$userId%'],
      orderBy: 'startDate DESC',
    );
  }

  Future<Map<String, dynamic>?> getTripById(String id) async {
    final db = await database;
    final results = await db.query(
      'trips',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateTrip(Map<String, dynamic> trip) async {
    final db = await database;
    final Map<String, dynamic> mutableTrip = Map.from(trip);
    if (mutableTrip['participantIds'] is List) {
      mutableTrip['participantIds'] = (mutableTrip['participantIds'] as List).join(',');
    }
    return await db.update(
      'trips',
      mutableTrip,
      where: 'id = ?',
      whereArgs: [trip['id']],
    );
  }

  Future<int> deleteTrip(String id) async {
    final db = await database;
    return await db.delete(
      'trips',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Stop CRUD operations
  Future<int> insertStop(Map<String, dynamic> stop) async {
    final db = await database;
    return await db.insert('stops', stop);
  }

  Future<List<Map<String, dynamic>>> getStops(String tripId) async {
    final db = await database;
    return await db.query(
      'stops',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'orderIndex ASC',
    );
  }

  Future<int> updateStop(Map<String, dynamic> stop) async {
    final db = await database;
    return await db.update(
      'stops',
      stop,
      where: 'id = ?',
      whereArgs: [stop['id']],
    );
  }

  Future<int> deleteStop(String id) async {
    final db = await database;
    return await db.delete(
      'stops',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Tag CRUD operations
  Future<int> insertTag(Map<String, dynamic> tag) async {
    final db = await database;
    return await db.insert('tags', tag);
  }

  Future<List<Map<String, dynamic>>> getTags(String stopId) async {
    final db = await database;
    return await db.query(
      'tags',
      where: 'stopId = ?',
      whereArgs: [stopId],
    );
  }

  Future<int> deleteTag(String id) async {
    final db = await database;
    return await db.delete(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Expense CRUD operations
  Future<int> insertExpense(Map<String, dynamic> expense) async {
    final db = await database;
    return await db.insert('expenses', expense);
  }

  Future<List<Map<String, dynamic>>> getExpenses(String tripId) async {
    final db = await database;
    return await db.query(
      'expenses',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'date DESC',
    );
  }

  Future<int> updateExpense(Map<String, dynamic> expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      expense,
      where: 'id = ?',
      whereArgs: [expense['id']],
    );
  }

  Future<int> deleteExpense(String id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getStopById(String id) async {
    final db = await database;
    final results = await db.query(
      'stops',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getExpenseById(String id) async {
    final db = await database;
    final results = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Sync metadata operations
  Future<void> updateSyncMetadata(
    String entityType,
    String entityId,
    DateTime lastSyncedAt,
  ) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {
        'id': '${entityType}_$entityId',
        'entityType': entityType,
        'entityId': entityId,
        'lastSyncedAt': lastSyncedAt.toIso8601String(),
        'syncStatus': 'synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedEntities(
      String entityType) async {
    final db = await database;
    final metadata = await db.query('sync_metadata');
    final unsyncedIds = metadata
        .where(
            (m) => m['entityType'] == entityType && m['syncStatus'] != 'synced')
        .map((m) => m['entityId'] as String)
        .toList();

    if (unsyncedIds.isEmpty) return [];

    final placeholders = List.filled(unsyncedIds.length, '?').join(',');
    return await db.query(
      entityType,
      where: 'id IN ($placeholders)',
      whereArgs: unsyncedIds,
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
