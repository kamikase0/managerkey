// lib/database/database_helper.dart

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:manager_key/models/reporte_diario_local.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  // ✅ PASO 1: Incrementar la versión para forzar la ejecución de onUpgrade.
  static const int _databaseVersion = 10;

  // Nombres de las tablas
  static const String tableReportes = 'reportes_diarios';
  static const String tableOperadores = 'operadores';
  static const String tablePuntos = 'puntos_empadronamiento';
  static const String tableUbicaciones = 'ubicaciones';

  // Columnas de la tabla (schema actualizado y correcto)
  static const String columnId = 'id';
  static const String columnIdServer = 'id_server';
  static const String columnContadorInicialR = 'contador_inicial_r';
  static const String columnContadorFinalR = 'contador_final_r';
  static const String columnSaltosenR = 'saltosen_r';
  static const String columnContadorR = 'contador_r';
  static const String columnContadorInicialC = 'contador_inicial_c';
  static const String columnContadorFinalC = 'contador_final_c';
  static const String columnSaltosenC = 'saltosen_c';
  static const String columnContadorC = 'contador_c';
  static const String columnFechaReporte = 'fecha_reporte';
  static const String columnObservaciones = 'observaciones';
  static const String columnIncidencias = 'incidencias';
  static const String columnEstado = 'estado';
  static const String columnIdOperador = 'id_operador';
  static const String columnEstacionId = 'estacion_id';
  static const String columnNroEstacion = 'nro_estacion';
  static const String columnFechaCreacion = 'fecha_creacion';
  static const String columnFechaSincronizacion = 'fecha_sincronizacion';
  static const String columnObservacionC = 'observacion_c';
  static const String columnObservacionR = 'observacion_r';
  static const String columnCentroEmpadronamiento = 'centro_empadronamiento';
  static const String columnSincronizar = 'sincronizar';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'manager_key.db');
    debugPrint("📁 Ruta de BD: $path");

    // 🔥 SOLUCIÓN TEMPORAL: Eliminar BD para forzar recreación
    // try {
    //   await deleteDatabase(path);
    //   debugPrint("🗑️ ✅ Base de datos anterior ELIMINADA");
    // } catch (e) {
    //   debugPrint("⚠️ Error eliminando BD (quizás no existía): $e");
    // }

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint("✅ Creando base de datos desde cero (onCreate) v$version...");
    await _createTables(db);
  }

  // ✅ PASO 2: LÓGICA DE MIGRACIÓN DESTRUCTIVA (La solución definitiva)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint("🔄 Actualizando BD de v$oldVersion a v$newVersion...");

    // Para desarrollo: eliminar todo y recrear
    if (oldVersion < 10) {
      await _dropTables(db);
      await _createTables(db);
      debugPrint("✅ Base de datos recreada completamente");
    }
  }

  Future<void> _dropTables(Database db) async {
    await db.execute('DROP TABLE IF EXISTS $tableReportes');
    await db.execute('DROP TABLE IF EXISTS $tableOperadores');
    await db.execute('DROP TABLE IF EXISTS $tablePuntos');
    await db.execute('DROP TABLE IF EXISTS $tableUbicaciones');
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $tableOperadores(
        id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL,
        usuario TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        activo INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableReportes(
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnIdServer INTEGER UNIQUE,
        $columnIdOperador INTEGER NOT NULL,
        $columnContadorInicialR TEXT NOT NULL,
        $columnContadorFinalR TEXT NOT NULL,
        $columnSaltosenR INTEGER DEFAULT 0,
        $columnContadorR TEXT NOT NULL,
        $columnContadorInicialC TEXT NOT NULL,
        $columnContadorFinalC TEXT NOT NULL,
        $columnSaltosenC INTEGER DEFAULT 0,
        $columnContadorC TEXT NOT NULL,
        $columnFechaReporte TEXT NOT NULL,
        $columnObservaciones TEXT,
        $columnIncidencias TEXT,
        $columnEstado TEXT NOT NULL DEFAULT 'pendiente',
        $columnEstacionId INTEGER,
        $columnNroEstacion TEXT,
        $columnFechaCreacion TEXT NOT NULL,
        $columnFechaSincronizacion TEXT,
        $columnObservacionC TEXT,
        $columnObservacionR TEXT,
        $columnCentroEmpadronamiento INTEGER,
        $columnSincronizar INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE $tablePuntos (
        id INTEGER PRIMARY KEY,
        provincia TEXT,
        punto_de_empadronamiento TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableUbicaciones (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          timestamp TEXT NOT NULL
      )
    ''');

    await _createIndexes(db);
    await _insertSampleData(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_id_operador ON $tableReportes($columnIdOperador)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_server_id ON $tableReportes($columnIdServer)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_estado ON $tableReportes($columnEstado)');
  }

  Future<void> _insertSampleData(Database db) async {
    await db.execute('''
      INSERT OR IGNORE INTO $tableOperadores (id, nombre, usuario, password)
      VALUES (408, 'J. Quisbert A.', 'j.quisbert.a', '123')
    ''');
  }

  // --- El resto de los métodos CRUD y de negocio no necesitan cambios ---

  Future<int> insertReporte(ReporteDiarioLocal reporte) async {
    final db = await database;
    return await db.insert(tableReportes, reporte.toLocalMap());
  }

  Future<int> updateReporte(ReporteDiarioLocal reporte) async {
    final db = await database;
    if (reporte.id == null) {
      throw Exception('El reporte debe tener un ID local para ser actualizado');
    }
    return await db.update(
      tableReportes,
      reporte.toLocalMap(),
      where: '$columnId = ?',
      whereArgs: [reporte.id],
    );
  }

  Future<void> insertarOIgnorarReporte(ReporteDiarioLocal reporte) async {
    final db = await database;
    await db.insert(
      tableReportes,
      reporte.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<ReporteDiarioLocal>> getReportesPorOperador(int idOperador) async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      where: '$columnIdOperador = ?',
      whereArgs: [idOperador],
      orderBy: '$columnFechaCreacion DESC',
    );
    return maps.map((map) => ReporteDiarioLocal.fromLocalMap(map)).toList();
  }

  Future<List<ReporteDiarioLocal>> getReportesPendientes() async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      where: '$columnEstado = ?',
      whereArgs: ['pendiente'],
      orderBy: '$columnFechaCreacion ASC',
    );
    return maps.map((map) => ReporteDiarioLocal.fromLocalMap(map)).toList();
  }

  Future<void> eliminarReportesAntiguosSincronizados(int idOperador, List<int> idsDelServidor) async {
    if (idsDelServidor.isEmpty) return;
    final db = await database;
    String placeholders = idsDelServidor.map((_) => '?').join(',');
    await db.delete(
      tableReportes,
      where: '$columnIdOperador = ? AND $columnEstado = ? AND $columnIdServer NOT IN ($placeholders)',
      whereArgs: [idOperador, 'sincronizado', ...idsDelServidor],
    );
  }

  Future<void> eliminarTodosLosReportesSincronizadosPorOperador(int idOperador) async {
    final db = await database;
    await db.delete(
      tableReportes,
      where: '$columnIdOperador = ? AND $columnEstado = ?',
      whereArgs: [idOperador, 'sincronizado'],
    );
  }

  Future<Map<String, dynamic>> getEstadisticasPorOperador(int idOperador) async {
    final db = await database;
    final totalResult = await db.rawQuery('SELECT COUNT(*) as total FROM $tableReportes WHERE $columnIdOperador = ?', [idOperador]);
    final sincronizadosResult = await db.rawQuery('SELECT COUNT(*) as sincronizados FROM $tableReportes WHERE $columnIdOperador = ? AND $columnEstado = ?', [idOperador, 'sincronizado']);
    final pendientesResult = await db.rawQuery('SELECT COUNT(*) as pendientes FROM $tableReportes WHERE $columnIdOperador = ? AND $columnEstado = ?', [idOperador, 'pendiente']);
    final fallidosResult = await db.rawQuery('SELECT COUNT(*) as fallidos FROM $tableReportes WHERE $columnIdOperador = ? AND $columnEstado = ?', [idOperador, 'fallido']);
    final total = totalResult.first['total'] as int;
    final sincronizados = sincronizadosResult.first['sincronizados'] as int;
    final pendientes = pendientesResult.first['pendientes'] as int;
    final fallidos = fallidosResult.first['fallidos'] as int;
    return {
      'total': total,
      'sincronizados': sincronizados,
      'pendientes': pendientes,
      'fallidos': fallidos,
    };
  }

  // lib/database/database_helper.dart
// AÑADE ESTOS MÉTODOS AL FINAL DE TU CLASE DatabaseHelper

// (Pega esto después del método getEstadisticasPorOperador)

  /// Obtener reporte por fecha y operador
  Future<ReporteDiarioLocal?> getReporteByFecha(String fecha, int idOperador) async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      where: '$columnFechaReporte = ? AND $columnIdOperador = ?',
      whereArgs: [fecha, idOperador],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return ReporteDiarioLocal.fromLocalMap(maps.first);
  }

  /// Verificar si existe un reporte para una fecha específica
  Future<bool> existeReporteParaFecha(String fecha, int idOperador) async {
    final reporte = await getReporteByFecha(fecha, idOperador);
    return reporte != null;
  }

  /// Obtener reporte por ID local
  Future<ReporteDiarioLocal?> getReporteById(int id) async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return ReporteDiarioLocal.fromLocalMap(maps.first);
  }

  /// Marcar reporte como sincronizado (método simplificado)
  Future<int> marcarComoSincronizado(int idLocal, int idServer) async {
    final db = await database;
    return await db.update(
      tableReportes,
      {
        columnIdServer: idServer,
        columnEstado: 'sincronizado',
        columnFechaSincronizacion: DateTime.now().toIso8601String(),
        columnSincronizar: 0,
      },
      where: '$columnId = ?',
      whereArgs: [idLocal],
    );
  }

  /// Obtener total de reportes por operador
  Future<List<ReporteDiarioLocal>> getTotalReportesPorOperador(int idOperador) async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      where: '$columnIdOperador = ?',
      whereArgs: [idOperador],
    );
    return maps.map((map) => ReporteDiarioLocal.fromLocalMap(map)).toList();
  }

  /// Obtener reportes sincronizados por operador
  Future<List<ReporteDiarioLocal>> getReportesSincronizadosPorOperador(int idOperador) async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      where: '$columnIdOperador = ? AND $columnEstado = ?',
      whereArgs: [idOperador, 'sincronizado'],
    );
    return maps.map((map) => ReporteDiarioLocal.fromLocalMap(map)).toList();
  }

  /// Obtener reportes pendientes por operador
  Future<List<ReporteDiarioLocal>> getReportesPendientesPorOperador(int idOperador) async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      where: '$columnIdOperador = ? AND $columnEstado = ?',
      whereArgs: [idOperador, 'pendiente'],
    );
    return maps.map((map) => ReporteDiarioLocal.fromLocalMap(map)).toList();
  }

  /// Limpiar base de datos (solo para desarrollo)
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete(tableReportes);
    debugPrint('🗑️ Tabla de reportes limpiada');
  }

  /// Cerrar conexión (SQLite lo maneja automáticamente, pero por si acaso)
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      debugPrint('🔒 Conexión a base de datos cerrada');
    }
  }
}
