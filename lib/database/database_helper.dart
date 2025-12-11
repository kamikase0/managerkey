import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:manager_key/models/reporte_diario_local.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const int _databaseVersion = 4;

  // Nombre de la tabla
  static const String tableReportes = 'reportes_diarios';

  // Columnas de la tabla
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

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Crear tabla de operadores
    await db.execute('''
      CREATE TABLE IF NOT EXISTS operadores(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        usuario TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        activo INTEGER DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Crear tabla principal de reportes
    await db.execute('''
      CREATE TABLE $tableReportes(
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnIdServer INTEGER,
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
        $columnIdOperador INTEGER NOT NULL,
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

    // Crear índices
    await _createIndexes(db);

    // Insertar datos de ejemplo
    await _insertSampleData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Implementación de migración...
    // (Mantén tu implementación actual aquí)
    //     // Migración paso a paso
    if (oldVersion < 4) {
      await _migrateV3toV4(db);
    }
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_fecha_reporte ON $tableReportes($columnFechaReporte)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_id_operador ON $tableReportes($columnIdOperador)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_estado ON $tableReportes($columnEstado)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sincronizar ON $tableReportes($columnSincronizar)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_fecha_creacion ON $tableReportes($columnFechaCreacion)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_usuario ON operadores(usuario)');
  }

  Future<void> _insertSampleData(Database db) async {
    await db.execute('''
      INSERT OR IGNORE INTO operadores (id, nombre, usuario, password)
      VALUES (1, 'Operador Principal', 'operador', '123456')
    ''');
  }

  // ========== MÉTODOS CRUD CORREGIDOS ==========

  // Insertar reporte usando toLocalMap()
  Future<int> insertReporte(ReporteDiarioLocal reporte) async {
    final db = await database;

    if (reporte.idOperador == 0) {
      throw Exception('id_operador es requerido para guardar el reporte');
    }

    return await db.insert(tableReportes, reporte.toLocalMap());
  }

  // Obtener reporte por ID
  Future<ReporteDiarioLocal?> getReporte(int id) async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      where: '$columnId = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _mapToReporteDiarioLocal(maps.first);
    }
    return null;
  }

  // Obtener todos los reportes
  Future<List<ReporteDiarioLocal>> getAllReportes() async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      orderBy: '$columnFechaCreacion DESC',
    );

    return maps.map((map) => _mapToReporteDiarioLocal(map)).toList();
  }

  // Obtener reportes por estado
  Future<List<ReporteDiarioLocal>> getReportesByEstado(String estado) async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      where: '$columnEstado = ?',
      whereArgs: [estado],
      orderBy: '$columnFechaCreacion DESC',
    );

    return maps.map((map) => _mapToReporteDiarioLocal(map)).toList();
  }

  // Obtener reportes pendientes
  Future<List<ReporteDiarioLocal>> getReportesPendientes() async {
    return await getReportesByEstado('pendiente');
  }

  // Obtener reportes fallidos
  Future<List<ReporteDiarioLocal>> getReportesFallidos() async {
    return await getReportesByEstado('fallido');
  }

  // Obtener reportes sincronizados
  Future<List<ReporteDiarioLocal>> getReportesSincronizados() async {
    return await getReportesByEstado('sincronizado');
  }

  // Actualizar reporte
  Future<int> updateReporte(ReporteDiarioLocal reporte) async {
    final db = await database;

    if (reporte.id == null) {
      throw Exception('El reporte no tiene ID para actualizar');
    }

    return await db.update(
      tableReportes,
      reporte.toLocalMap(),
      where: '$columnId = ?',
      whereArgs: [reporte.id],
    );
  }

  // Eliminar reporte
  Future<int> deleteReporte(int id) async {
    final db = await database;
    return await db.delete(
      tableReportes,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Marcar reporte como sincronizado
  Future<int> marcarComoSincronizado(int id, int serverId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return await db.update(
      tableReportes,
      {
        columnEstado: 'sincronizado',
        columnIdServer: serverId,
        columnFechaSincronizacion: now,
      },
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Marcar reporte como fallido
  Future<int> marcarComoFallido(int id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return await db.update(
      tableReportes,
      {
        columnEstado: 'fallido',
        columnFechaSincronizacion: now,
      },
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // ========== MÉTODOS ESPECÍFICOS POR OPERADOR ==========

  // Obtener reportes por operador
  Future<List<ReporteDiarioLocal>> getReportesPorOperador(int idOperador) async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      where: '$columnIdOperador = ?',
      whereArgs: [idOperador],
      orderBy: '$columnFechaCreacion DESC',
    );

    return maps.map((map) => _mapToReporteDiarioLocal(map)).toList();
  }

  // Obtener reportes pendientes por operador
  Future<List<ReporteDiarioLocal>> getReportesPendientesPorOperador(int idOperador) async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      where: '$columnEstado = ? AND $columnIdOperador = ?',
      whereArgs: ['pendiente', idOperador],
      orderBy: '$columnFechaCreacion ASC',
    );

    return maps.map((map) => _mapToReporteDiarioLocal(map)).toList();
  }

  // Obtener reportes sincronizados por operador
  Future<List<ReporteDiarioLocal>> getReportesSincronizadosPorOperador(int idOperador) async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      where: '$columnEstado = ? AND $columnIdOperador = ?',
      whereArgs: ['sincronizado', idOperador],
      orderBy: '$columnFechaCreacion DESC',
    );

    return maps.map((map) => _mapToReporteDiarioLocal(map)).toList();
  }

  // Obtener reporte por fecha y operador
  Future<ReporteDiarioLocal?> getReporteByFecha(String fecha, int idOperador) async {
    final db = await database;
    final maps = await db.query(
      tableReportes,
      where: '$columnFechaReporte = ? AND $columnIdOperador = ?',
      whereArgs: [fecha, idOperador],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return _mapToReporteDiarioLocal(maps.first);
    }
    return null;
  }

  // Verificar si ya existe un reporte para la fecha y operador
  Future<bool> existeReporteParaFecha(String fecha, int idOperador) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableReportes WHERE $columnFechaReporte = ? AND $columnIdOperador = ?',
      [fecha, idOperador],
    );

    return (result.first['count'] as int) > 0;
  }

  // Obtener estadísticas por operador
  Future<Map<String, dynamic>> getEstadisticasPorOperador(int idOperador) async {
    final db = await database;

    // Total reportes
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM $tableReportes WHERE $columnIdOperador = ?',
      [idOperador],
    );
    final total = totalResult.first['total'] as int;

    // Reportes sincronizados
    final sincronizadosResult = await db.rawQuery(
      'SELECT COUNT(*) as sincronizados FROM $tableReportes WHERE $columnIdOperador = ? AND $columnEstado = ?',
      [idOperador, 'sincronizado'],
    );
    final sincronizados = sincronizadosResult.first['sincronizados'] as int;

    // Reportes pendientes
    final pendientesResult = await db.rawQuery(
      'SELECT COUNT(*) as pendientes FROM $tableReportes WHERE $columnIdOperador = ? AND $columnEstado = ?',
      [idOperador, 'pendiente'],
    );
    final pendientes = pendientesResult.first['pendientes'] as int;

    // Reportes fallidos
    final fallidosResult = await db.rawQuery(
      'SELECT COUNT(*) as fallidos FROM $tableReportes WHERE $columnIdOperador = ? AND $columnEstado = ?',
      [idOperador, 'fallido'],
    );
    final fallidos = fallidosResult.first['fallidos'] as int;

    return {
      'total': total,
      'sincronizados': sincronizados,
      'pendientes': pendientes,
      'fallidos': fallidos,
      'porcentajeSincronizado': total > 0 ? (sincronizados / total * 100).toStringAsFixed(1) : '0.0',
    };
  }

  // ========== MÉTODOS DE SINCRONIZACIÓN ==========

  // Guardar reportes del servidor
  Future<void> guardarReportesServidor(List<Map<String, dynamic>> reportes) async {
    final db = await database;
    final batch = db.batch();

    for (var reporte in reportes) {
      final idServer = reporte['id'] as int?;

      if (idServer != null) {
        // Verificar si ya existe
        final existente = await db.query(
          tableReportes,
          where: '$columnIdServer = ?',
          whereArgs: [idServer],
          limit: 1,
        );

        if (existente.isEmpty) {
          batch.insert(tableReportes, {
            columnIdServer: idServer,
            columnFechaReporte: reporte['fecha_reporte'],
            columnContadorInicialC: reporte['contador_inicial_c'],
            columnContadorFinalC: reporte['contador_final_c'],
            // CORRECCIÓN 1: Usar 'registro_c' del servidor para la columna 'contador_c'
            columnContadorC: (reporte['registro_c'] ?? 0).toString(),
            // CORRECCIÓN 2: Añadir 'saltosen_c'
            columnSaltosenC: reporte['saltosen_c'] ?? 0,
            columnContadorInicialR: reporte['contador_inicial_r'],
            columnContadorFinalR: reporte['contador_final_r'],
            // CORRECCIÓN 3: Usar 'registro_r' del servidor para la columna 'contador_r'
            columnContadorR: (reporte['registro_r'] ?? 0).toString(),
            // CORRECCIÓN 4: Añadir 'saltosen_r'
            columnSaltosenR: reporte['saltosen_r'] ?? 0,
            columnIncidencias: reporte['incidencias'],
            columnObservaciones: reporte['observaciones'],
            // CORRECCIÓN 5: Usar el estado del servidor o 'sincronizado' como default
            columnEstado: reporte['estado'] ?? 'sincronizado',
            columnIdOperador: reporte['operador'],
            columnEstacionId: reporte['estacion'],
            columnFechaCreacion: reporte['fecha_registro'] ?? DateTime.now().toIso8601String(),
            columnFechaSincronizacion: DateTime.now().toIso8601String(),
            // CORRECCIÓN 6: Usar nombres de campo en minúsculas (snake_case)
            columnObservacionC: reporte['observacion_c'],
            columnObservacionR: reporte['observacion_r'],
            columnCentroEmpadronamiento: reporte['centro_empadronamiento'],
            // CORRECCIÓN 7: Añadir 'sincronizar'
            columnSincronizar: reporte['sincronizar'] ?? 0, // Asume 0 si no viene
          });
        }
      }
    }

    await batch.commit();
    print('💾 Guardados ${reportes.length} reportes del servidor');
  }

  // Método auxiliar para convertir Map a ReporteDiarioLocal
  ReporteDiarioLocal _mapToReporteDiarioLocal(Map<String, dynamic> map) {
    return ReporteDiarioLocal(
      id: map['id'] as int?,
      idServer: map['id_server'] as int?,
      contadorInicialR: map['contador_inicial_r'] as String? ?? '',
      contadorFinalR: map['contador_final_r'] as String? ?? '',
      saltosenR: map['saltosen_r'] as int? ?? 0,
      contadorR: map['contador_r'] as String? ?? '0',
      contadorInicialC: map['contador_inicial_c'] as String? ?? '',
      contadorFinalC: map['contador_final_c'] as String? ?? '',
      saltosenC: map['saltosen_c'] as int? ?? 0,
      contadorC: map['contador_c'] as String? ?? '0',
      fechaReporte: map['fecha_reporte'] as String? ?? '',
      observaciones: map['observaciones'] as String?,
      incidencias: map['incidencias'] as String?,
      estado: map['estado'] as String? ?? 'pendiente',
      idOperador: map['id_operador'] as int? ?? 0,
      estacionId: map['estacion_id'] as int?,
      nroEstacion: map['nro_estacion'] as String?,
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'] as String)
          : DateTime.now(),
      fechaSincronizacion: map['fecha_sincronizacion'] != null
          ? DateTime.parse(map['fecha_sincronizacion'] as String)
          : null,
      observacionC: map['observacion_c'] as String?,
      observacionR: map['observacion_r'] as String?,
      centroEmpadronamiento: map['centro_empadronamiento'] as int?,
    );
  }

  // Métodos de conveniencia para compatibilidad
  Future<int> insertReporteDiario(ReporteDiarioLocal reporte) async {
    return await insertReporte(reporte);
  }

  Future<int> updateReporteDiario(ReporteDiarioLocal reporte) async {
    return await updateReporte(reporte);
  }

  Future<List<ReporteDiarioLocal>> getTotalReportesPorOperador(int idOperador) async {
    return await getReportesPorOperador(idOperador);
  }

  // Métodos de utilidad
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete(tableReportes);
    await db.delete('operadores');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

    Future<void> _migrateV3toV4(Database db) async {
    try {
      // Crear nuevos índices
      await _createIndexes(db);
      print('✅ Migración v3->v4 completada');
    } catch (e) {
      print('❌ Error en migración v3->v4: $e');
    }
  }

  static DatabaseHelper get instance => _instance;
}
