import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static Database? _db;

  // ================= DATABASE =================
  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bms_inventory.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // ================= CREATE TABLES =================
  static Future<void> _onCreate(Database db, int version) async {
    // SPECIES OBSERVATION
    await db.execute('''
      CREATE TABLE records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_year TEXT,
        assessment_period TEXT,
        station TEXT,
        category TEXT,
        habitat TEXT,
        species TEXT,
        count INTEGER,
        remarks TEXT,
        latitude REAL,
        longitude REAL,
        photo_path TEXT,
        created_at TEXT
      )
    ''');

    // HABITAT ASSESSMENT
    await db.execute('''
      CREATE TABLE habitat (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_year TEXT,
        station TEXT,
        habitat_condition TEXT,
        forest_cover TEXT,
        invasive_present TEXT,
        invasive_details TEXT,
        water_condition TEXT,
        disturbance_notes TEXT,
        remarks TEXT,
        latitude REAL,
        longitude REAL,
        photo_path TEXT,
        created_at TEXT
      )
    ''');

    // THREAT MONITORING
    await db.execute('''
      CREATE TABLE threats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_year TEXT,
        station TEXT,
        threat_type TEXT,
        evidence TEXT,
        threat_age TEXT,
        action_taken TEXT,
        remarks TEXT,
        latitude REAL,
        longitude REAL,
        photo_path TEXT,
        created_at TEXT
      )
    ''');

    // HUMAN ACTIVITY
    await db.execute('''
      CREATE TABLE human_activity (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_year TEXT,
        station TEXT,
        activity_type TEXT,
        activity_description TEXT,
        intensity TEXT,
        frequency TEXT,
        remarks TEXT,
        latitude REAL,
        longitude REAL,
        photo_path TEXT,
        created_at TEXT
      )
    ''');
  }

  // ================= INSERT METHODS =================

  static Future<void> insertRecord(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('records', data);
  }

  static Future<void> insertHabitat(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('habitat', data);
  }

  static Future<void> insertThreat(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('threats', data);
  }

  static Future<void> insertHumanActivity(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('human_activity', data);
  }

  // ================= SUMMARY COUNTS =================

  static Future<int> getCountByCategory(String category) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) FROM records WHERE category = ?',
      [category],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  static Future<int> countTable(String table) async {
    const allowed = [
      'records',
      'habitat',
      'threats',
      'human_activity',
    ];

    if (!allowed.contains(table)) return 0;

    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  // ================= FETCH ALL FOR CSV =================

  static Future<List<Map<String, dynamic>>> getAllRecords() async {
    final db = await database;
    return await db.query('records');
  }

  static Future<List<Map<String, dynamic>>> getAllHabitat() async {
    final db = await database;
    return await db.query('habitat');
  }

  static Future<List<Map<String, dynamic>>> getAllThreats() async {
    final db = await database;
    return await db.query('threats');
  }

  static Future<List<Map<String, dynamic>>> getAllHumanActivity() async {
    final db = await database;
    return await db.query('human_activity');
  }
}
