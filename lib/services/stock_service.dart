import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class MedicineStock {
  const MedicineStock({
    required this.id,
    required this.medicineName,
    required this.purchaseDate,
    required this.totalCount,
    required this.remainingCount,
    required this.lowStockThreshold,
  });

  final int id;
  final String medicineName;
  final String purchaseDate;
  final int totalCount;
  final int remainingCount;
  final int lowStockThreshold;

  factory MedicineStock.fromMap(Map<String, dynamic> map) {
    return MedicineStock(
      id: (map['id'] as num).toInt(),
      medicineName: (map['medicine_name'] ?? '').toString(),
      purchaseDate: ((map['purchase_date'] ?? map['expiry_date']) ?? '')
          .toString(),
      totalCount: (map['total_count'] as num?)?.toInt() ?? 0,
      remainingCount: (map['remaining_count'] as num?)?.toInt() ?? 0,
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toInt() ?? 0,
    );
  }
}

class StockConsumeResult {
  const StockConsumeResult({
    required this.consumed,
    required this.lowStockAlert,
    this.message = '',
    this.updatedStock,
  });

  final bool consumed;
  final bool lowStockAlert;
  final String message;
  final MedicineStock? updatedStock;
}

class StockService {
  StockService._();
  static final StockService instance = StockService._();

  Database? _db;

  Future<Database> _database() async {
    if (_db != null) {
      return _db!;
    }
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'medicare_stock.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE medicine_stocks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            medicine_name TEXT NOT NULL,
            purchase_date TEXT NOT NULL,
            total_count INTEGER NOT NULL,
            remaining_count INTEGER NOT NULL,
            low_stock_threshold INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            UNIQUE(medicine_name, purchase_date)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE medicine_stocks ADD COLUMN purchase_date TEXT',
          );
          await db.execute(
            "UPDATE medicine_stocks SET purchase_date = expiry_date WHERE purchase_date IS NULL OR purchase_date = ''",
          );
        }
      },
    );
    return _db!;
  }

  Future<void> upsertStock({
    required String medicineName,
    required String purchaseDate,
    required int totalCount,
    required int remainingCount,
    required int lowStockThreshold,
  }) async {
    final db = await _database();
    final normalizedName = medicineName.trim();
    final normalizedDate = purchaseDate.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (normalizedName.isEmpty || normalizedDate.isEmpty) {
      return;
    }

    final existing = await db.query(
      'medicine_stocks',
      where: 'LOWER(medicine_name) = LOWER(?) AND purchase_date = ?',
      whereArgs: [normalizedName, normalizedDate],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert(
        'medicine_stocks',
        {
          'medicine_name': normalizedName,
          'purchase_date': normalizedDate,
          'total_count': totalCount,
          'remaining_count': remainingCount,
          'low_stock_threshold': lowStockThreshold,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    final id = (existing.first['id'] as num).toInt();
    await db.update(
      'medicine_stocks',
      {
        'medicine_name': normalizedName,
        'purchase_date': normalizedDate,
        'total_count': totalCount,
        'remaining_count': remainingCount,
        'low_stock_threshold': lowStockThreshold,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<MedicineStock>> listStocks() async {
    final db = await _database();
    final rows = await db.query(
      'medicine_stocks',
      orderBy: 'purchase_date ASC, medicine_name COLLATE NOCASE ASC',
    );
    return rows.map(MedicineStock.fromMap).toList();
  }

  Future<void> deleteStock(int id) async {
    final db = await _database();
    await db.delete(
      'medicine_stocks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<StockConsumeResult> consumeOneByMedicine(String medicineName) async {
    final normalized = medicineName.trim();
    if (normalized.isEmpty) {
      return const StockConsumeResult(consumed: false, lowStockAlert: false);
    }

    final db = await _database();
    final rows = await db.query(
      'medicine_stocks',
      where:
          'LOWER(medicine_name) = LOWER(?) AND remaining_count > 0',
      whereArgs: [normalized],
      orderBy: 'purchase_date ASC, id ASC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return const StockConsumeResult(
        consumed: false,
        lowStockAlert: false,
      );
    }

    final current = MedicineStock.fromMap(rows.first);
    final nextRemaining = (current.remainingCount - 1).clamp(0, 1000000000);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'medicine_stocks',
      {
        'remaining_count': nextRemaining,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [current.id],
    );

    final updated = MedicineStock(
      id: current.id,
      medicineName: current.medicineName,
      purchaseDate: current.purchaseDate,
      totalCount: current.totalCount,
      remainingCount: nextRemaining,
      lowStockThreshold: current.lowStockThreshold,
    );
    final low = nextRemaining <= current.lowStockThreshold;
    final message = low
        ? 'Low stock alert: ${updated.medicineName} remaining ${updated.remainingCount}'
        : '';

    return StockConsumeResult(
      consumed: true,
      lowStockAlert: low,
      message: message,
      updatedStock: updated,
    );
  }
}
