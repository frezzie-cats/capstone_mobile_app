
import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  // Database getter
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB('first_aid_guidelines.db');

    return _database!;
  }

  // Initialize database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // Create database table
  Future<void> _createDB(Database db, int version) async {
    await db.execute(
      '''
      CREATE TABLE guidelines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        species_key TEXT UNIQUE NOT NULL,
        common_name TEXT NOT NULL,
        first_aid_steps TEXT NOT NULL,
        warning_signs TEXT NOT NULL
      )
      ''',
    );

    await _seedInitialData(db);
  }

  // Insert initial guideline records
  Future<void> _seedInitialData(Database db) async {
    final List<Map<String, Object?>> initialRecords = [
      {
        'species_key': 'bee_wasp',
        'common_name': 'Honey Bee / Wasp Sting',
        'first_aid_steps':
            '1. Immediately remove the stinger by scraping horizontally with a flat card. Do not squeeze the sting site.\n'
            '2. Wash the affected skin thoroughly with soap and clean water.\n'
            '3. Apply a cold pack or ice wrapped in a cloth for 10-15 minutes to reduce localized swelling and redness.\n'
            '4. Keep the affected limb elevated if possible.',
        'warning_signs':
            'Monitor closely for systemic reactions: difficulty breathing, facial or throat swelling, dizziness, hives, or rapid pulse.',
      },
      {
        'species_key': 'brown_recluse_necrotic',
        'common_name': 'Necrotic Arachnid Lesion',
        'first_aid_steps':
            '1. Wash the affected area gently with mild soap and clean water.\n'
            '2. Apply a cold compress wrapped in a cloth to relieve pain.\n'
            '3. Elevate the affected area to help control swelling.\n'
            '4. Keep the affected area clean and avoid applying pressure.',
        'warning_signs':
            'Watch for expanding discoloration, pale areas around the wound, severe localized pain, fever, or chills.',
      },
      {
        'species_key': 'fire_ant',
        'common_name': 'Fire Ant Pustular Sting',
        'first_aid_steps':
            '1. Gently wash the sting site with mild soap and water.\n'
            '2. Apply a cold compress for 10 minutes to soothe burning and reduce inflammation.\n'
            '3. Do not scratch, squeeze, or pop the pustules.\n'
            '4. Keep the affected area clean.',
        'warning_signs':
            'Watch for spreading redness, pus leakage, widespread hives, or swelling of the lips or tongue.',
      },
      {
        'species_key': 'tick_erythema_migrans',
        'common_name': 'Tick Vector Rash (Erythema Migrans)',
        'first_aid_steps':
            '1. If a tick is present, grasp it firmly near the skin with fine-tipped tweezers and pull straight upward without twisting.\n'
            '2. Clean the bite area thoroughly with soap and water.\n'
            '3. Monitor and photograph any expanding rash.\n'
            '4. Keep the bite location clean.',
        'warning_signs':
            'Monitor for an expanding rash, persistent joint pain, fatigue, neck stiffness, fever, or headache.',
      },
    ];

    for (final record in initialRecords) {
      await db.insert(
        'guidelines',
        record,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // Retrieve a guideline using its species key
  Future<Map<String, Object?>?> getGuideline(
    String speciesKey,
  ) async {
    final db = await database;

    final results = await db.query(
      'guidelines',
      where: 'species_key = ?',
      whereArgs: [speciesKey],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return results.first;
    }

    return null;
  }

  // Retrieve all guidelines
  Future<List<Map<String, Object?>>> getAllGuidelines() async {
    final db = await database;

    return await db.query(
      'guidelines',
      orderBy: 'common_name ASC',
    );
  }

  // Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();

    _database = null;
  }
}
