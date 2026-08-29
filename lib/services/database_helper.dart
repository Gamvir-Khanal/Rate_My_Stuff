import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/rating_history_item.dart';

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ratings.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ratings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        rating REAL NOT NULL,
        remark TEXT NOT NULL,
        category_id TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  // Insert rating record and save photo persistently to application documents directory
  Future<RatingHistoryItem> insertRating({
    required File imageFile,
    required double rating,
    required String remark,
    required String categoryId,
  }) async {
    try {
      final db = await database;

      String finalImagePath = imageFile.path;
      if (await imageFile.exists()) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = 'rating_${DateTime.now().microsecondsSinceEpoch}.png';
          final persistentPath = p.join(appDir.path, fileName);
          final savedFile = await imageFile.copy(persistentPath);
          finalImagePath = savedFile.path;
        } catch (e) {
          debugPrint('⚠️ Could not copy image to app docs dir, using original path: $e');
        }
      }

      final item = RatingHistoryItem(
        imagePath: finalImagePath,
        rating: rating,
        remark: remark,
        categoryId: categoryId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final id = await db.insert('ratings', item.toMap());
      debugPrint('✅ Saved rating card to SQLite database with ID: $id');
      
      return RatingHistoryItem(
        id: id,
        imagePath: item.imagePath,
        rating: item.rating,
        remark: item.remark,
        categoryId: item.categoryId,
        createdAt: item.createdAt,
      );
    } catch (e) {
      debugPrint('❌ SQLite Insert failed: $e');
      rethrow;
    }
  }

  // Retrieve all ratings from SQLite sorted by creation date descending
  Future<List<RatingHistoryItem>> getRatings() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'ratings',
        orderBy: 'created_at DESC',
      );
      
      return List.generate(maps.length, (i) {
        return RatingHistoryItem.fromMap(maps[i]);
      });
    } catch (e) {
      debugPrint('❌ SQLite Fetch failed: $e');
      rethrow;
    }
  }

  // Delete rating record from database
  Future<int> deleteRating(int id) async {
    try {
      final db = await database;
      // We could also delete the associated image file here to save space
      final maps = await db.query('ratings', where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) {
        final imagePath = maps.first['image_path'] as String?;
        if (imagePath != null) {
          final file = File(imagePath);
          if (await file.exists()) {
            await file.delete();
            debugPrint('🗑️ Deleted persistent image file: $imagePath');
          }
        }
      }
      final rowsDeleted = await db.delete(
        'ratings',
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('🗑️ Deleted SQLite record ID: $id');
      return rowsDeleted;
    } catch (e) {
      debugPrint('❌ SQLite Delete failed: $e');
      return 0;
    }
  }
}
