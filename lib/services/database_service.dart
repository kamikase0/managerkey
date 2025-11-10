import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/registro_despliegue_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    _database ??= await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'app_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Crear tabla para registros de despliegue
    await db.execute('''
      CREATE TABLE registros_despliegue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        destino TEXT NOT NULL,
        latitud_despliegue TEXT,
        longitud_despliegue TEXT,
        latitud_llegada TEXT,
        longitud_llegada TEXT,
        estado TEXT NOT NULL DEFAULT 'TRANSMITIDO',
        fue_desplegado INTEGER NOT NULL DEFAULT 1,
        llego_destino INTEGER NOT NULL DEFAULT 0,
        fecha_hora_salida TEXT NOT NULL,
        fecha_hora_llegada TEXT,
        operador_id INTEGER NOT NULL,
        observaciones TEXT,
        sincronizar INTEGER NOT NULL DEFAULT 0,
        sincronizado INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // Insertar un nuevo registro de despliegue
  Future<int> insertRegistroDespliegue(RegistroDespliegue registro) async {
    try {
      final db = await database;
      final result = await db.insert(
        'registros_despliegue',
        registro.toMap(),
      );
      print('Registro insertado con ID: $result');
      return result;
    } catch (e) {
      print('Error al insertar registro: $e');
      rethrow;
    }
  }

  // Actualizar un registro de despliegue
  Future<int> actualizarRegistroDespliegue(RegistroDespliegue registro) async {
    try {
      final db = await database;
      if (registro.id == null) {
        throw Exception('El registro debe tener un ID para actualizarse');
      }
      final result = await db.update(
        'registros_despliegue',
        registro.toMap(),
        where: 'id = ?',
        whereArgs: [registro.id],
      );
      print('Registro actualizado: $result filas afectadas');
      return result;
    } catch (e) {
      print('Error al actualizar registro: $e');
      rethrow;
    }
  }

  // Obtener todos los registros
  Future<List<RegistroDespliegue>> obtenerTodosRegistros() async {
    try {
      final db = await database;
      final result = await db.query('registros_despliegue');
      return result.map((json) => RegistroDespliegue.fromMap(json)).toList();
    } catch (e) {
      print('Error al obtener registros: $e');
      return [];
    }
  }

  // Obtener registros no sincronizados
  Future<List<RegistroDespliegue>> obtenerNoSincronizados() async {
    try {
      final db = await database;
      final result = await db.query(
        'registros_despliegue',
        where: 'sincronizado = ?',
        whereArgs: [0],
      );
      return result.map((json) => RegistroDespliegue.fromMap(json)).toList();
    } catch (e) {
      print('Error al obtener no sincronizados: $e');
      return [];
    }
  }

  // Obtener registros activos (desplegados pero sin llegada)
  Future<List<RegistroDespliegue>> obtenerRegistrosActivos() async {
    try {
      final db = await database;
      final result = await db.query(
        'registros_despliegue',
        where: 'fue_desplegado = ? AND llego_destino = ?',
        whereArgs: [1, 0],
      );
      return result.map((json) => RegistroDespliegue.fromMap(json)).toList();
    } catch (e) {
      print('Error al obtener registros activos: $e');
      return [];
    }
  }

  // Marcar un registro como sincronizado
  Future<void> marcarComoSincronizado(int id) async {
    try {
      final db = await database;
      await db.update(
        'registros_despliegue',
        {'sincronizado': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      print('Registro $id marcado como sincronizado');
    } catch (e) {
      print('Error al marcar como sincronizado: $e');
    }
  }

  // Obtener un registro por ID
  Future<RegistroDespliegue?> obtenerRegistroPorId(int id) async {
    try {
      final db = await database;
      final result = await db.query(
        'registros_despliegue',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (result.isNotEmpty) {
        return RegistroDespliegue.fromMap(result.first);
      }
      return null;
    } catch (e) {
      print('Error al obtener registro por ID: $e');
      return null;
    }
  }

  // Eliminar un registro
  Future<void> eliminarRegistro(int id) async {
    try {
      final db = await database;
      await db.delete(
        'registros_despliegue',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('Registro $id eliminado');
    } catch (e) {
      print('Error al eliminar registro: $e');
    }
  }

  // Limpiar todos los datos (útil para testing)
  Future<void> limpiarBaseDatos() async {
    try {
      final db = await database;
      await db.delete('registros_despliegue');
      print('Base de datos limpiada');
    } catch (e) {
      print('Error al limpiar base de datos: $e');
    }
  }
}