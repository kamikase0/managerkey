// lib/services/database_service.dart (ACTUALIZADO)
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
    if(_database != null) return _database!;
    _database = await _initializeDatabase();
    return _database!;
  }

  Future<List<RegistroDespliegue>> obtenerRegistrosDespliegueNoSincronizados() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'registros_despliegue',
      where: 'sincronizado = ?',
      whereArgs: [0], // Asumiendo que 0 significa no sincronizado
    );
    return List.generate(maps.length, (i) {
      return RegistroDespliegue.fromMap(maps[i]);
    });
  }

  // AGREGA ESTE MÉTODO
  Future<void> eliminarRegistroDespliegue(int id) async {
    final db = await database;
    await db.delete(
      'registros_despliegue',
      where: 'id = ?',
      whereArgs: [id],
    );
    print('✅ Registro de despliegue local $id eliminado.');
  }

  Future<Database> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'app_database.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Tabla registros de despliegue (EXISTENTE)
    await db.execute('''
      CREATE TABLE registros_despliegue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        destino TEXT NOT NULL,
        latitud TEXT,
        longitud TEXT,
        descripcion_reporte TEXT,
        estado TEXT NOT NULL DEFAULT 'DESPLIEGUE',
        sincronizar INTEGER NOT NULL DEFAULT 0,
        observaciones TEXT,
        incidencias TEXT,
        fecha_hora TEXT NOT NULL,
        operador_id INTEGER NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        fecha_sincronizacion TEXT
      )
    ''');

    // Tabla reportes diarios (NUEVA)
    await db.execute('''
      CREATE TABLE reportes_diarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_reporte TEXT NOT NULL,
        contador_inicial_c TEXT NOT NULL,
        contador_final_c TEXT NOT NULL,
        contador_c TEXT NOT NULL,
        contador_inicial_r TEXT NOT NULL,
        contador_final_r TEXT NOT NULL,
        contador_r TEXT NOT NULL,
        incidencias TEXT,
        observaciones TEXT,
        operador INTEGER NOT NULL,
        estacion INTEGER NOT NULL,
        estado TEXT DEFAULT 'TRANSMITIDO',
        sincronizar INTEGER DEFAULT 1,
        synced INTEGER DEFAULT 0,
        updated_at TEXT
      )
    ''');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Crear tabla de reportes si no existe
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reportes_diarios (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fecha_reporte TEXT NOT NULL,
          contador_inicial_c TEXT NOT NULL,
          contador_final_c TEXT NOT NULL,
          contador_c TEXT NOT NULL,
          contador_inicial_r TEXT NOT NULL,
          contador_final_r TEXT NOT NULL,
          contador_r TEXT NOT NULL,
          incidencias TEXT,
          observaciones TEXT,
          operador INTEGER NOT NULL,
          estacion INTEGER NOT NULL,
          estado TEXT DEFAULT 'TRANSMITIDO',
          sincronizar INTEGER DEFAULT 1,
          synced INTEGER DEFAULT 0,
          updated_at TEXT
        )
      ''');
    }
  }

  // ========== MÉTODOS PARA REGISTROS DE DESPLIEGUE (EXISTENTES) ==========

  Future<int> insertRegistroDespliegue(RegistroDespliegue registro) async {
    try {
      final db = await database;
      final result = await db.insert(
        'registros_despliegue',
        registro.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('Registro insertado con ID: $result');
      return result;
    } catch (e) {
      print('Error al insertar registro: $e');
      rethrow;
    }
  }

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

  Future<void> limpiarBaseDatos() async {
    try {
      final db = await database;
      await db.delete('registros_despliegue');
      print('Base de datos limpiada');
    } catch (e) {
      print('Error al limpiar base de datos: $e');
    }
  }

  // ========== MÉTODOS PARA REPORTES DIARIOS (NUEVOS) ==========

  /// Insertar reporte
  Future<int> insertReporte(Map<String, dynamic> data) async {
    try {
      final db = await database;

      // ✅ LIMPIAR DATOS ANTES DE INSERTAR
      final cleanedData = _limpiarDatosParaSQLite(data);

      final mappedData = Map<String, dynamic>.from(cleanedData);

      // ✅ MANTENER EL MAPEO EXISTENTE
      if (mappedData.containsKey('registro_c')) {
        mappedData['contador_c'] = mappedData['registro_c'];
        mappedData.remove('registro_c');
      }
      if (mappedData.containsKey('registro_r')) {
        mappedData['contador_r'] = mappedData['registro_r'];
        mappedData.remove('registro_r');
      }

      final result = await db.insert(
        'reportes_diarios',
        {
          ...mappedData,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ Reporte insertado con ID: $result');
      return result;
    } catch (e) {
      print('❌ Error al insertar reporte: $e');
      rethrow;
    }
  }
  /// Obtener reportes no sincronizados
  Future<List<Map<String, dynamic>>> getUnsyncedReportes() async {
    try {
      final db = await database;
      final result = await db.query(
        'reportes_diarios',
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'updated_at ASC',
      );
      print('📋 Reportes no sincronizados encontrados: ${result.length}');
      return result;
    } catch (e) {
      print('❌ Error al obtener reportes sin sincronizar: $e');
      return [];
    }
  }

  /// Obtener todos los reportes
  Future<List<Map<String, dynamic>>> getReportes() async {
    try {
      final db = await database;
      final result = await db.query(
        'reportes_diarios',
        orderBy: 'fecha_reporte DESC',
      );
      print('📊 Total de reportes: ${result.length}');
      return result;
    } catch (e) {
      print('❌ Error al obtener reportes: $e');
      return [];
    }
  }

  /// Marcar reporte como sincronizado
  Future<int> markReporteAsSynced(int id) async {
    try {
      final db = await database;
      final result = await db.update(
        'reportes_diarios',
        {
          'synced': 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Reporte $id marcado como sincronizado');
      return result;
    } catch (e) {
      print('❌ Error al marcar reporte como sincronizado: $e');
      rethrow;
    }
  }

  /// Obtener reporte por ID
  Future<Map<String, dynamic>?> getReporteById(int id) async {
    try {
      final db = await database;
      final result = await db.query(
        'reportes_diarios',
        where: 'id = ?',
        whereArgs: [id],
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('❌ Error al obtener reporte por ID: $e');
      return null;
    }
  }

  /// Eliminar reporte
  Future<int> deleteReporte(int id) async {
    try {
      final db = await database;
      final result = await db.delete(
        'reportes_diarios',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('🗑️ Reporte $id eliminado');
      return result;
    } catch (e) {
      print('❌ Error al eliminar reporte: $e');
      rethrow;
    }
  }

  /// Elimina de la tabla 'reportes_diarios' las filas que pertenecen a un
  /// operador específico y que ya están marcadas como sincronizadas
  Future<int> deleteSyncedReportesByOperador(int operadorId) async {
    try {
      final db = await database;
      final count = await db.delete(
        'reportes_diarios',
        // La condición es que el 'operador' coincida Y 'synced' sea 1 (verdadero).
        where: 'operador = ? AND synced = ?',
        whereArgs: [operadorId, 1],
      );
      return count; // Devuelve el número de filas eliminadas.
    } catch (e) {
      print('❌ Error al eliminar reportes sincronizados por operador: $e');
      rethrow; // Relanzamos para que ReporteSyncService pueda manejarlo.
    }
  }

  /// Contar reportes pendientes
  Future<int> countUnsyncedReportes() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM reportes_diarios WHERE synced = 0'
      );
      final count = Sqflite.firstIntValue(result) ?? 0;
      print('📈 Reportes pendientes: $count');
      return count;
    } catch (e) {
      print('❌ Error al contar reportes sin sincronizar: $e');
      return 0;
    }
  }

  // Agrega este método a tu DatabaseService
  Future<int> insertRegistroDespliegueFromMap(Map<String, dynamic> data) async {
    try {
      final db = await database;

      // Mapear los datos al formato de la tabla registros_despliegue
      final mappedData = {
        'destino': data['destino'] ?? 'REPORTE DIARIO',
        'latitud': data['latitud'] ?? '',
        'longitud': data['longitud'] ?? '',
        'descripcion_reporte': data['observaciones'] ?? '',
        'estado': data['estado'] ?? 'REPORTE ENVIADO',
        'sincronizar': data['sincronizar'] ?? true ? 1 : 0,
        'observaciones': data['observaciones'] ?? '',
        'incidencias': data['incidencias'] ?? '',
        'fecha_hora': data['fecha_hora'] ?? DateTime.now().toIso8601String(),
        'operador_id': data['operador'] ?? 0,
        'sincronizado': 0,
      };

      final result = await db.insert(
        'registros_despliegue',
        mappedData,
      );
      print('📍 Registro de despliegue insertado con ID: $result');
      return result;
    } catch (e) {
      print('❌ Error al insertar registro de despliegue: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _limpiarDatosParaSQLite(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value == null) {
        return MapEntry(key, '');
      } else if (value is bool) {
        return MapEntry(key, value ? 1 : 0);
      } else {
        return MapEntry(key, value);
      }
    });
  }

}