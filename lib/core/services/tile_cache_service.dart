import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Cached tile info
class CachedTile {
  final String url;
  final int zoom;
  final int x;
  final int y;
  final DateTime cachedAt;
  final int size;

  const CachedTile({
    required this.url,
    required this.zoom,
    required this.x,
    required this.y,
    required this.cachedAt,
    required this.size,
  });
}

/// Service for caching map tiles for offline use
/// Uses SQLite to track cached tiles
class TileCacheService {
  static TileCacheService? _instance;
  static Database? _database;

  // Max cache size in bytes (100 MB default)
  static const int maxCacheSize = 100 * 1024 * 1024;

  TileCacheService._();

  static TileCacheService get instance {
    _instance ??= TileCacheService._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'tile_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tiles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT UNIQUE NOT NULL,
            zoom INTEGER NOT NULL,
            x INTEGER NOT NULL,
            y INTEGER NOT NULL,
            data BLOB NOT NULL,
            cached_at TEXT NOT NULL,
            size INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_tile_location ON tiles (zoom, x, y)
        ''');
      },
    );
  }

  /// Check if tile is cached
  Future<bool> isTileCached(String url, int zoom, int x, int y) async {
    final db = await database;
    final result = await db.query(
      'tiles',
      where: 'zoom = ? AND x = ? AND y = ?',
      whereArgs: [zoom, x, y],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get cached tile data
  Future<List<int>?> getTile(int zoom, int x, int y) async {
    final db = await database;
    final result = await db.query(
      'tiles',
      columns: ['data'],
      where: 'zoom = ? AND x = ? AND y = ?',
      whereArgs: [zoom, x, y],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first['data'] as List<int>;
  }

  /// Cache a tile
  Future<void> cacheTile({
    required String url,
    required int zoom,
    required int x,
    required int y,
    required List<int> data,
  }) async {
    final db = await database;

    // Check current cache size
    final currentSize = await getCacheSize();
    if (currentSize >= maxCacheSize) {
      // Clear oldest tiles
      await _clearOldestTiles(currentSize - maxCacheSize + (10 * 1024 * 1024));
    }

    await db.insert(
      'tiles',
      {
        'url': url,
        'zoom': zoom,
        'x': x,
        'y': y,
        'data': data,
        'cached_at': DateTime.now().toIso8601String(),
        'size': data.length,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get current cache size
  Future<int> getCacheSize() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(size) as total FROM tiles');
    return (result.first['total'] as int?) ?? 0;
  }

  /// Get number of cached tiles
  Future<int> getTileCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM tiles');
    return (result.first['count'] as int?) ?? 0;
  }

  /// Clear oldest tiles to free up space
  Future<void> _clearOldestTiles(int bytesToFree) async {
    final db = await database;
    var freed = 0;

    while (freed < bytesToFree) {
      final oldest = await db.query(
        'tiles',
        orderBy: 'cached_at ASC',
        limit: 10,
      );

      if (oldest.isEmpty) break;

      for (final tile in oldest) {
        await db.delete(
          'tiles',
          where: 'id = ?',
          whereArgs: [tile['id']],
        );
        freed += tile['size'] as int;
      }
    }
  }

  /// Clear all cached tiles
  Future<void> clearCache() async {
    final db = await database;
    await db.delete('tiles');
  }

  /// Delete tiles outside zoom range
  Future<void> clearZoomRange(int minZoom, int maxZoom) async {
    final db = await database;
    await db.delete(
      'tiles',
      where: 'zoom < ? OR zoom > ?',
      whereArgs: [minZoom, maxZoom],
    );
  }

  /// Get cache info
  Future<Map<String, dynamic>> getCacheInfo() async {
    final count = await getTileCount();
    final size = await getCacheSize();

    return {
      'tileCount': count,
      'cacheSize': size,
      'cacheSizeFormatted': _formatBytes(size),
      'maxSize': maxCacheSize,
      'maxSizeFormatted': _formatBytes(maxCacheSize),
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
