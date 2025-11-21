import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/punto_empadronamiento_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'empadronamiento.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE puntos_empadronamiento(
        id INTEGER PRIMARY KEY,
        provincia TEXT NOT NULL,
        punto_de_empadronamiento TEXT NOT NULL
      )
    ''');
  }

  // Insertar todos los puntos
  Future<void> insertarPuntos(List<PuntoEmpadronamiento> puntos) async {
    final db = await database;

    // Limpiar tabla antes de insertar
    await db.delete('puntos_empadronamiento');

    // Insertar en lote
    final batch = db.batch();
    for (var punto in puntos) {
      batch.insert('puntos_empadronamiento', punto.toJson());
    }
    await batch.commit();
  }

  // Obtener todas las provincias
  Future<List<String>> obtenerProvincias() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT provincia FROM puntos_empadronamiento ORDER BY provincia',
    );
    return maps.map((map) => map['provincia'] as String).toList();
  }

  // Obtener puntos por provincia
  Future<List<String>> obtenerPuntosPorProvincia(String provincia) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'puntos_empadronamiento',
      where: 'provincia = ?',
      whereArgs: [provincia],
      columns: ['punto_de_empadronamiento'],
    );
    return maps
        .map((map) => map['punto_de_empadronamiento'] as String)
        .toList();
  }

  // Verificar si hay datos
  Future<bool> tieneDatos() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM puntos_empadronamiento'),
    );
    return count != null && count > 0;
  }
}
