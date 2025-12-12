import 'package:district_dev/Services/Data%20Model/date_utilities.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:developer' as developer;

// Enhanced debug logging
void debugLog(String message, {String category = 'FoodDataModel'}) {
  if (kDebugMode) {
    developer.log(message, name: category);
    print('🍔 [$category]: $message');
  }
}

const bool kDebugMode = true;

// 1. Food Item Data Model
class FoodItem {
  final String name;
  final String servingSize;
  final int minCalories;
  final int maxCalories;
  final double minProtein;
  final double? minVitaminA;
  final String dietaryFocus;
  final String targetStatus;
  final String foodType;

  const FoodItem({
    required this.name,
    required this.servingSize,
    required this.minCalories,
    required this.maxCalories,
    required this.minProtein,
    this.minVitaminA,
    required this.dietaryFocus,
    required this.targetStatus,
    required this.foodType,
  });

  int get averageCalories => ((minCalories + maxCalories) / 2).round();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'serving_size': servingSize,
      'min_calories': minCalories,
      'max_calories': maxCalories,
      'min_protein': minProtein,
      'min_vitamin_a': minVitaminA,
      'dietary_focus': dietaryFocus,
      'target_status': targetStatus,
      'food_type': foodType,
      'created_at': DateUtilities.formatDateForDB(DateTime.now()),
      'updated_at': DateUtilities.formatDateForDB(DateTime.now()),
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      name: map['name'] ?? '',
      servingSize: map['serving_size'] ?? '',
      minCalories: map['min_calories'] ?? 0,
      maxCalories: map['max_calories'] ?? 0,
      minProtein: (map['min_protein'] ?? 0.0).toDouble(),
      minVitaminA: map['min_vitamin_a']?.toDouble(),
      dietaryFocus: map['dietary_focus'] ?? '',
      targetStatus: map['target_status'] ?? '',
      foodType: map['food_type'] ?? '',
    );
  }

  FoodItem copyWith({
    String? name,
    String? servingSize,
    int? minCalories,
    int? maxCalories,
    double? minProtein,
    double? minVitaminA,
    String? dietaryFocus,
    String? targetStatus,
    String? foodType,
  }) {
    return FoodItem(
      name: name ?? this.name,
      servingSize: servingSize ?? this.servingSize,
      minCalories: minCalories ?? this.minCalories,
      maxCalories: maxCalories ?? this.maxCalories,
      minProtein: minProtein ?? this.minProtein,
      minVitaminA: minVitaminA ?? this.minVitaminA,
      dietaryFocus: dietaryFocus ?? this.dietaryFocus,
      targetStatus: targetStatus ?? this.targetStatus,
      foodType: foodType ?? this.foodType,
    );
  }
}

// 2. Food Data Repository - CLEAN VERSION (NO DEFAULT DATA)
class FoodDataRepository {
  static final FoodDataRepository _instance = FoodDataRepository._internal();
  factory FoodDataRepository() => _instance;
  FoodDataRepository._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await _getDatabasePath();
      final path = join(databasesPath, 'food_database.db');

      if (kDebugMode) {
        debugLog('📁 Database path: $path');
      }

      final directory = Directory(databasesPath);
      if (!directory.existsSync()) {
        if (kDebugMode) {
          debugLog('📁 Creating directory: $databasesPath');
        }
        directory.createSync(recursive: true);
      }

      final database = await openDatabase(
        path,
        version: 1,
        onCreate: _createTables,
        onOpen: (db) {
          if (kDebugMode) {
            debugLog('✅ Database opened successfully');
          }
        },
      );

      if (kDebugMode) {
        debugLog('✅ Database initialized successfully');
      }

      return database;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugLog('❌ Database initialization failed: $e');
        debugLog('📋 Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  Future<String> _getDatabasePath() async {
    try {
      if (Platform.isWindows) {
        final documents = Platform.environment['USERPROFILE'];
        if (documents != null) {
          return join(documents, 'Documents', 'SchoolFeedingApp', 'FoodData');
        }
      }
      final directory = await getApplicationDocumentsDirectory();
      return join(directory.path, 'FoodData');
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      return tempDir.path;
    }
  }

  Future<void> _createTables(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS food_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL,
          serving_size TEXT NOT NULL,
          min_calories INTEGER NOT NULL,
          max_calories INTEGER NOT NULL,
          min_protein REAL NOT NULL,
          min_vitamin_a REAL,
          dietary_focus TEXT NOT NULL,
          target_status TEXT NOT NULL,
          food_type TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      if (kDebugMode) {
        debugLog('✅ Database tables created successfully');
        debugLog('🔄 Database ready - no default data inserted');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugLog('❌ Table creation failed: $e');
        debugLog('📋 Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  // ========== CRUD OPERATIONS ==========

  Future<void> addFoodItem(FoodItem foodItem) async {
    final db = await database;
    try {
      await db.insert(
        'food_items',
        foodItem.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      if (kDebugMode) {
        debugLog('✅ Food item added: ${foodItem.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugLog('❌ Failed to add food item: ${foodItem.name} - $e');
      }
      throw Exception('Food item "${foodItem.name}" already exists');
    }
  }

  Future<void> updateFoodItem(String originalName, FoodItem updatedItem) async {
    final db = await database;
    final result = await db.update(
      'food_items',
      updatedItem.toMap(),
      where: 'name = ?',
      whereArgs: [originalName],
    );
    if (result == 0) throw Exception('Food item "$originalName" not found');
  }

  Future<void> removeFoodItem(String foodName) async {
    final db = await database;
    final result = await db.delete(
      'food_items',
      where: 'name = ?',
      whereArgs: [foodName],
    );
    if (result == 0) throw Exception('Food item "$foodName" not found');
  }

  Future<FoodItem?> getFoodItemByName(String foodName) async {
    final db = await database;
    final results = await db.query(
      'food_items',
      where: 'name = ?',
      whereArgs: [foodName],
    );
    if (results.isEmpty) return null;
    return FoodItem.fromMap(results.first);
  }

  Future<bool> foodItemExists(String foodName) async {
    final db = await database;
    final results = await db.query(
      'food_items',
      where: 'name = ?',
      whereArgs: [foodName],
    );
    return results.isNotEmpty;
  }

  // ========== QUERY METHODS ==========

  Future<List<FoodItem>> getAllFoodItems() async {
    final db = await database;
    debugLog('🔍 Querying all food items from database...');

    try {
      final results =
          await db.query('food_items', orderBy: 'food_type, name').timeout(
        Duration(seconds: 10),
        onTimeout: () {
          debugLog('⏰ Database query timeout');
          return [];
        },
      );

      debugLog('✅ Database query completed, found ${results.length} items');
      return results.map((map) => FoodItem.fromMap(map)).toList();
    } catch (e, stackTrace) {
      debugLog('❌ Database query failed: $e');
      debugLog('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<FoodItem>> getFoodItemsByType(String foodType) async {
    final db = await database;
    final results = await db.query(
      'food_items',
      where: 'food_type = ?',
      whereArgs: [foodType],
      orderBy: 'name',
    );
    return results.map((map) => FoodItem.fromMap(map)).toList();
  }

  Future<List<FoodItem>> getFoodItemsByStatus(String targetStatus) async {
    final db = await database;
    final results = await db.query(
      'food_items',
      where: 'target_status = ?',
      whereArgs: [targetStatus],
      orderBy: 'name',
    );
    return results.map((map) => FoodItem.fromMap(map)).toList();
  }

  Future<List<FoodItem>> getFoodItemsByDietaryFocus(String dietaryFocus) async {
    final db = await database;
    final results = await db.query(
      'food_items',
      where: 'dietary_focus LIKE ?',
      whereArgs: ['%$dietaryFocus%'],
      orderBy: 'name',
    );
    return results.map((map) => FoodItem.fromMap(map)).toList();
  }

  Future<List<String>> getAvailableFoodTypes() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT DISTINCT food_type FROM food_items ORDER BY food_type',
    );
    return results.map((row) => row['food_type'] as String).toList();
  }

  Future<List<String>> getAvailableTargetStatuses() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT DISTINCT target_status FROM food_items ORDER BY target_status',
    );
    return results.map((row) => row['target_status'] as String).toList();
  }

  Future<List<String>> getAvailableDietaryFocuses() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT DISTINCT dietary_focus FROM food_items ORDER BY dietary_focus',
    );
    return results.map((row) => row['dietary_focus'] as String).toList();
  }

  // ========== SEARCH AND FILTER METHODS ==========

  Future<List<FoodItem>> searchFoodItems(String query) async {
    if (query.isEmpty) return getAllFoodItems();
    final db = await database;
    final results = await db.query(
      'food_items',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name',
    );
    return results.map((map) => FoodItem.fromMap(map)).toList();
  }

  Future<List<FoodItem>> filterFoodItems({
    String? foodType,
    String? targetStatus,
    String? dietaryFocus,
    double? minCalories,
    double? maxCalories,
    double? minProtein,
  }) async {
    final db = await database;
    var whereClauses = <String>[];
    var whereArgs = <dynamic>[];

    if (foodType != null) {
      whereClauses.add('food_type = ?');
      whereArgs.add(foodType);
    }
    if (targetStatus != null) {
      whereClauses.add('target_status = ?');
      whereArgs.add(targetStatus);
    }
    if (dietaryFocus != null) {
      whereClauses.add('dietary_focus LIKE ?');
      whereArgs.add('%$dietaryFocus%');
    }
    if (minCalories != null) {
      whereClauses.add('(min_calories + max_calories) / 2 >= ?');
      whereArgs.add(minCalories);
    }
    if (maxCalories != null) {
      whereClauses.add('(min_calories + max_calories) / 2 <= ?');
      whereArgs.add(maxCalories);
    }
    if (minProtein != null) {
      whereClauses.add('min_protein >= ?');
      whereArgs.add(minProtein);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final results = await db.query(
      'food_items',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name',
    );
    return results.map((map) => FoodItem.fromMap(map)).toList();
  }

  // ========== STATISTICS METHODS ==========

  Future<int> getFoodItemCount() async {
    try {
      final db = await database;
      final results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM food_items',
      );
      return results.first['count'] as int;
    } catch (e) {
      if (kDebugMode) {
        debugLog('⚠️ getFoodItemCount failed: $e - returning 0');
      }
      return 0;
    }
  }

  Future<Map<String, dynamic>> getNutritionalStatistics() async {
    try {
      final db = await database;
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM food_items',
      );
      final totalItems = countResult.first['count'] as int;

      if (totalItems == 0) {
        return {
          'totalItems': 0,
          'averageCalories': 0,
          'averageProtein': 0,
          'totalFoodTypes': 0,
        };
      }

      final calorieResult = await db.rawQuery('''
        SELECT AVG((min_calories + max_calories) / 2) as avg_calories FROM food_items
      ''');
      final proteinResult = await db.rawQuery(
        'SELECT AVG(min_protein) as avg_protein FROM food_items',
      );
      final typeResult = await db.rawQuery(
        'SELECT COUNT(DISTINCT food_type) as type_count FROM food_items',
      );

      return {
        'totalItems': totalItems,
        'averageCalories':
            (calorieResult.first['avg_calories'] as double?)?.round() ?? 0,
        'averageProtein':
            (proteinResult.first['avg_protein'] as double?)?.toStringAsFixed(
                  2,
                ) ??
                '0.00',
        'totalFoodTypes': typeResult.first['type_count'] as int? ?? 0,
      };
    } catch (e) {
      if (kDebugMode) {
        debugLog('⚠️ getNutritionalStatistics failed: $e');
      }
      return {
        'totalItems': 0,
        'averageCalories': 0,
        'averageProtein': 0,
        'totalFoodTypes': 0,
      };
    }
  }

  Future<Map<String, int>> getFoodTypeDistribution() async {
    try {
      final db = await database;
      final results = await db.rawQuery('''
        SELECT food_type, COUNT(*) as count 
        FROM food_items 
        GROUP BY food_type 
        ORDER BY count DESC
      ''');

      final distribution = <String, int>{};
      for (final row in results) {
        distribution[row['food_type'] as String] = row['count'] as int;
      }
      return distribution;
    } catch (e) {
      if (kDebugMode) {
        debugLog('⚠️ getFoodTypeDistribution failed: $e');
      }
      return {};
    }
  }

  Future<Map<String, int>> getTargetStatusDistribution() async {
    try {
      final db = await database;
      final results = await db.rawQuery('''
        SELECT target_status, COUNT(*) as count 
        FROM food_items 
        GROUP BY target_status 
        ORDER BY count DESC
      ''');

      final distribution = <String, int>{};
      for (final row in results) {
        distribution[row['target_status'] as String] = row['count'] as int;
      }
      return distribution;
    } catch (e) {
      if (kDebugMode) {
        debugLog('⚠️ getTargetStatusDistribution failed: $e');
      }
      return {};
    }
  }

  // ========== DATABASE MAINTENANCE ==========

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> deleteDatabase(String path) async {
    final dbPath = await _getDatabasePath();
    final path = join(dbPath, 'food_database.db');
    await deleteDatabase(path);
  }

  Future<void> resetDatabase() async {
    final db = await database;
    await db.delete('food_items');
    if (kDebugMode) {
      debugLog('✅ Database reset - all food items cleared');
    }
  }

  Future<void> importFoodItems(List<FoodItem> foodItems) async {
    final db = await database;
    final batch = db.batch();
    for (final item in foodItems) {
      if (!await foodItemExists(item.name)) {
        batch.insert('food_items', item.toMap());
      }
    }
    await batch.commit();
  }

  Future<void> clearAllFoodItems() async {
    final db = await database;
    await db.delete('food_items');
  }
}
