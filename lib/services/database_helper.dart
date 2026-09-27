import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/rating_history_item.dart';
import 'encryption_service.dart';

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ratings_v2_encrypted.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    final masterKey = await EncryptionService.instance.getMasterKeyHex();

    // Check for legacy unencrypted database migration
    final legacyDbPath = p.join(dbPath, 'ratings.db');
    final legacyDbFile = File(legacyDbPath);

    Database encryptedDb = await openDatabase(
      path,
      password: masterKey,
      version: 1,
      onCreate: _createDB,
    );

    if (await legacyDbFile.exists()) {
      await _migrateLegacyDatabase(legacyDbPath, encryptedDb);
    }

    return encryptedDb;
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

  /// Migrates items from legacy unencrypted database to encrypted database at rest
  Future<void> _migrateLegacyDatabase(String legacyPath, Database newDb) async {
    try {
      debugPrint('🔄 Starting legacy database migration to encrypted storage...');
      final legacyDb = await openDatabase(legacyPath);
      final List<Map<String, dynamic>> legacyRows = await legacyDb.query('ratings');

      for (final row in legacyRows) {
        String imagePath = row['image_path'] as String;
        final file = File(imagePath);

        // Encrypt legacy image if unencrypted
        if (await file.exists() && !imagePath.endsWith('.enc')) {
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final encFileName = 'rating_${DateTime.now().microsecondsSinceEpoch}.enc';
            final encPath = p.join(appDir.path, encFileName);
            
            await EncryptionService.instance.encryptAndSaveFile(file, encPath);
            await file.delete();
            imagePath = encPath;
            debugPrint('🔐 Encrypted legacy image to $encPath');
          } catch (e) {
            debugPrint('⚠️ Error encrypting legacy image $imagePath: $e');
          }
        }

        await newDb.insert('ratings', {
          'image_path': imagePath,
          'rating': row['rating'],
          'remark': row['remark'],
          'category_id': row['category_id'],
          'created_at': row['created_at'],
        });
      }

      await legacyDb.close();
      await File(legacyPath).delete();
      debugPrint('✅ Migration complete! Deleted legacy unencrypted database.');
    } catch (e) {
      debugPrint('❌ Legacy database migration failed: $e');
    }
  }

  // Insert rating record and save photo persistently & encrypted at rest
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
          final encFileName = 'rating_${DateTime.now().microsecondsSinceEpoch}.enc';
          final persistentEncPath = p.join(appDir.path, encFileName);

          final savedEncFile = await EncryptionService.instance.encryptAndSaveFile(
            imageFile,
            persistentEncPath,
          );
          finalImagePath = savedEncFile.path;
          debugPrint('🔐 Successfully encrypted image to disk: $finalImagePath');
        } catch (e) {
          debugPrint('⚠️ Encryption during image save failed: $e');
          rethrow;
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
      debugPrint('✅ Saved rating card to encrypted SQLite database with ID: $id');

      return RatingHistoryItem(
        id: id,
        imagePath: item.imagePath,
        rating: item.rating,
        remark: item.remark,
        categoryId: item.categoryId,
        createdAt: item.createdAt,
      );
    } catch (e) {
      debugPrint('❌ Encrypted SQLite Insert failed: $e');
      rethrow;
    }
  }

  // Retrieve all ratings from encrypted SQLite sorted by creation date descending
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
      debugPrint('❌ Encrypted SQLite Fetch failed: $e');
      rethrow;
    }
  }

  // Delete rating record from database and purge encrypted image file
  Future<int> deleteRating(int id) async {
    try {
      final db = await database;
      final maps = await db.query('ratings', where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) {
        final imagePath = maps.first['image_path'] as String?;
        if (imagePath != null) {
          final file = File(imagePath);
          if (await file.exists()) {
            await file.delete();
            debugPrint('🗑️ Deleted persistent encrypted image file: $imagePath');
          }
        }
      }
      final rowsDeleted = await db.delete(
        'ratings',
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('🗑️ Deleted encrypted SQLite record ID: $id');
      return rowsDeleted;
    } catch (e) {
      debugPrint('❌ Encrypted SQLite Delete failed: $e');
      return 0;
    }
  }
}
