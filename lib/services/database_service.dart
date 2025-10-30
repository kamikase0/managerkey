import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/salida_ruta_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'salidas_ruta.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE salidas_ruta(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_hora TEXT NOT NULL,
        latitud REAL NOT NULL,
        longitud REAL NOT NULL,
        descripcion TEXT NOT NULL,
        observaciones TEXT NOT NULL,
        enviado INTEGER NOT NULL DEFAULT 0,
        fecha_envio TEXT
      )
    ''');
  }

  Future<int> insertSalidaRuta(SalidaRuta salida) async {
    final db = await database;
    return await db.insert('salidas_ruta', salida.toMap());
  }

  Future<List<SalidaRuta>> getSalidasRuta() async {
    final db = await database;
    final maps = await db.query('salidas_ruta', orderBy: 'fecha_hora DESC');
    return maps.map((map) => SalidaRuta.fromMap(map)).toList();
  }

  Future<int> updateSalidaEnviada(int id) async {
    final db = await database;
    return await db.update(
      'salidas_ruta',
      {
        'enviado': 1,
        'fecha_envio': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<SalidaRuta>> getSalidasNoEnviadas() async {
    final db = await database;
    final maps = await db.query(
      'salidas_ruta',
      where: 'enviado = ?',
      whereArgs: [0],
    );
    return maps.map((map) => SalidaRuta.fromMap(map)).toList();
  }
}