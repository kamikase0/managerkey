// lib/services/database_service.dart - VERSIÓN CORREGIDA Y UNIFICADA
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../config/enviroment.dart';
import '../models/registro_despliegue_model.dart';
import '../models/ubicacion_model.dart';

/// Servicio principal de base de datos
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  /// Obtener instancia de base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initializeDatabase();
    return _database!;
  }

  /// Inicializar base de datos
  Future<Database> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'app_database.db');

    return await openDatabase(
      path,
      version: 10, // Incrementado para forzar migración
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Crear base de datos por primera vez
  Future<void> _createDatabase(Database db, int version) async {
    print('🗄️ Creando base de datos inicial (versión $version)...');

    await _createTableRegistrosDespliegue(db);
    await _createTableReportesDiarios(db);
    await _createTableReportesPendientes(db);
    await _createTableUbicaciones(db);

    print('✅ Base de datos creada exitosamente');
  }

  /// Migrar base de datos
  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    print('🔄 Migrando BD de versión $oldVersion a $newVersion...');

    // Migración paso a paso
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      switch (version) {
        case 2:
          await _upgradeToVersion2(db);
          break;
        case 3:
          await _upgradeToVersion3(db);
          break;
        case 4:
          await _upgradeToVersion4(db);
          break;
        case 5:
          await _upgradeToVersion5(db);
          break;
        case 6:
          await _upgradeToVersion6(db);
          break;
        case 7:
          await _upgradeToVersion7(db);
          break;
        case 8:
          await _upgradeToVersion8(db);
          break;
        case 9:
          await _upgradeToVersion9(db);
          break;
        case 10:
          await _migracionForzadaV10(db);
          break;
      }
    }

    print('✅ Migración completada a versión $newVersion');
  }

  /// ===================================================================
  /// MÉTODOS DE CREACIÓN DE TABLAS
  /// ===================================================================

  /// Crear tabla registros_despliegue (estructura similar al servidor)
  Future<void> _createTableRegistrosDespliegue(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS registros_despliegue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_hora TEXT NOT NULL,
        operador_id INTEGER NOT NULL,
        estado TEXT NOT NULL,
        latitud TEXT NOT NULL,
        longitud TEXT NOT NULL,
        observaciones TEXT,
        sincronizar INTEGER NOT NULL DEFAULT 1,
        descripcion_reporte TEXT,
        incidencias TEXT,
        centro_empadronamiento_id INTEGER,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        fecha_sincronizacion TEXT,
        id_servidor INTEGER,
        fecha_creacion_local TEXT NOT NULL,
        intentos INTEGER DEFAULT 0,
        ultimo_intento TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Crear índices para mejor rendimiento
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_registros_operador ON registros_despliegue(operador_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_registros_sincronizado ON registros_despliegue(sincronizado)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_registros_fecha ON registros_despliegue(fecha_hora)',
    );

    print('✅ Tabla registros_despliegue creada');
  }

  /// Crear tabla reportes_diarios
  Future<void> _createTableReportesDiarios(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reportes_diarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_reporte TEXT NOT NULL,
        contador_inicial_c TEXT NOT NULL,
        contador_final_c TEXT NOT NULL,
        registro_c INTEGER NOT NULL,
        contador_inicial_r TEXT NOT NULL,
        contador_final_r TEXT NOT NULL,
        registro_r INTEGER NOT NULL,
        incidencias TEXT,
        observaciones TEXT,
        operador INTEGER NOT NULL,
        estacion INTEGER NOT NULL,
        centro_empadronamiento_id INTEGER,
        estado TEXT DEFAULT 'ENVIO REPORTE',
        sincronizar INTEGER DEFAULT 1,
        synced INTEGER DEFAULT 0,
        observacionC TEXT,
        observacionR TEXT,
        saltosenC INTEGER DEFAULT 0,
        saltosenR INTEGER DEFAULT 0,
        fecha_creacion_local TEXT NOT NULL,
        intentos INTEGER DEFAULT 0,
        ultima_tentativa TEXT,
        updated_at TEXT
      )
    ''');
    print('✅ Tabla reportes_diarios creada');
  }

  /// Crear tabla reportes_pendientes
  Future<void> _createTableReportesPendientes(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reportes_pendientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reporte_data TEXT NOT NULL,
        despliegue_data TEXT NOT NULL,
        fecha_creacion TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 0,
        intentos INTEGER DEFAULT 0,
        ultima_tentativa TEXT
      )
    ''');
    print('✅ Tabla reportes_pendientes creada');
  }

  /// Crear tabla ubicaciones
  Future<void> _createTableUbicaciones(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ubicaciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        latitud REAL NOT NULL,
        longitud REAL NOT NULL,
        timestamp TEXT NOT NULL,
        tipo_usuario TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 0,
        fecha_creacion TEXT NOT NULL,
        fecha_sincronizacion TEXT
      )
    ''');
    print('✅ Tabla ubicaciones creada');
  }

  /// ===================================================================
  /// MIGRACIONES POR VERSIÓN
  /// ===================================================================

  Future<void> _upgradeToVersion2(Database db) async {
    print('🔧 Migrando a versión 2: Agregar campos de sincronización');

    try {
      await db.execute(
        'ALTER TABLE registros_despliegue ADD COLUMN fecha_sincronizacion TEXT',
      );
      await db.execute(
        'ALTER TABLE registros_despliegue ADD COLUMN id_servidor INTEGER',
      );
      print('✅ Versión 2 migrada');
    } catch (e) {
      print('⚠️ Error en migración versión 2: $e');
    }
  }

  Future<void> _upgradeToVersion3(Database db) async {
    print('🔧 Migrando a versión 3: Agregar centro_empadronamiento_id');

    try {
      await db.execute(
        'ALTER TABLE registros_despliegue ADD COLUMN centro_empadronamiento_id INTEGER',
      );
      await db.execute(
        'ALTER TABLE reportes_diarios ADD COLUMN centro_empadronamiento_id INTEGER',
      );
      print('✅ Versión 3 migrada');
    } catch (e) {
      print('⚠️ Error en migración versión 3: $e');
    }
  }

  Future<void> _upgradeToVersion4(Database db) async {
    print('🔧 Migrando a versión 4: Agregar campos de intentos');

    try {
      await db.execute(
        'ALTER TABLE registros_despliegue ADD COLUMN intentos INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE registros_despliegue ADD COLUMN ultimo_intento TEXT',
      );
      print('✅ Versión 4 migrada');
    } catch (e) {
      print('⚠️ Error en migración versión 4: $e');
    }
  }

  Future<void> _upgradeToVersion5(Database db) async {
    print('🔧 Migrando a versión 5: Normalizar nombres de columnas');

    try {
      // Renombrar columnas camelCase a snake_case si existen
      final columns = await db.rawQuery(
        'PRAGMA table_info(registros_despliegue)',
      );
      final columnNames = columns.map((col) => col['name'] as String).toList();

      if (columnNames.contains('operadorId') &&
          !columnNames.contains('operador_id')) {
        await db.execute(
          'ALTER TABLE registros_despliegue RENAME COLUMN operadorId TO operador_id',
        );
        print('✅ operadorId → operador_id');
      }

      if (columnNames.contains('centroEmpadronamiento') &&
          !columnNames.contains('centro_empadronamiento_id')) {
        await db.execute(
          'ALTER TABLE registros_despliegue RENAME COLUMN centroEmpadronamiento TO centro_empadronamiento_id',
        );
        print('✅ centroEmpadronamiento → centro_empadronamiento_id');
      }

      print('✅ Versión 5 migrada');
    } catch (e) {
      print('⚠️ Error en migración versión 5: $e');
    }
  }

  Future<void> _upgradeToVersion6(Database db) async {
    print('🔧 Migrando a versión 6: Actualizar reportes_diarios');

    try {
      await db.execute(
        'ALTER TABLE reportes_diarios ADD COLUMN fecha_creacion_local TEXT',
      );
      await db.execute(
        'ALTER TABLE reportes_diarios ADD COLUMN intentos INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE reportes_diarios ADD COLUMN ultima_tentativa TEXT',
      );
      print('✅ Versión 6 migrada');
    } catch (e) {
      print('⚠️ Error en migración versión 6: $e');
    }
  }

  Future<void> _upgradeToVersion7(Database db) async {
    print('🔧 Migrando a versión 7: Crear índices para mejor rendimiento');

    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_registros_estado ON registros_despliegue(estado)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_registros_centro ON registros_despliegue(centro_empadronamiento_id)',
      );
      print('✅ Versión 7 migrada');
    } catch (e) {
      print('⚠️ Error en migración versión 7: $e');
    }
  }

  Future<void> _upgradeToVersion8(Database db) async {
    print('🔧 Migrando a versión 8: Limpiar y optimizar');

    try {
      // Eliminar registros duplicados (si existen)
      await db.execute('''
        DELETE FROM registros_despliegue 
        WHERE id NOT IN (
          SELECT MIN(id) 
          FROM registros_despliegue 
          GROUP BY operador_id, fecha_hora, estado
        )
      ''');
      print('✅ Datos limpiados');
    } catch (e) {
      print('⚠️ Error en migración versión 8: $e');
    }
  }

  Future<void> _upgradeToVersion9(Database db) async {
    print('🔧 Migrando a versión 9: Asegurar campos requeridos');

    try {
      // Asegurar que campos críticos tengan valores por defecto
      await db.execute(
        'UPDATE registros_despliegue SET fecha_creacion_local = datetime() WHERE fecha_creacion_local IS NULL',
      );
      await db.execute(
        'UPDATE registros_despliegue SET intentos = 0 WHERE intentos IS NULL',
      );
      print('✅ Versión 9 migrada');
    } catch (e) {
      print('⚠️ Error en migración versión 9: $e');
    }
  }

  /// ===================================================================
  /// MÉTODOS CRUD PARA REGISTROS_DESPLIEGUE
  /// ===================================================================

  /// Insertar un registro de despliegue
  Future<int> insertRegistroDespliegue(RegistroDespliegue registro) async {
    try {
      final db = await database;

      // Verificar estructura primero
      await verificarYRepararEstructura();

      // Usar nombres snake_case consistentes
      final datos = {
        'fecha_hora': registro.fechaHora,
        'operador_id': registro.operadorId,
        'estado': registro.estado,
        'latitud': registro.latitud,
        'longitud': registro.longitud,
        'observaciones': registro.observaciones ?? '',
        'sincronizar': registro.sincronizar ? 1 : 0,
        'descripcion_reporte': registro.descripcionReporte,
        'incidencias': registro.incidencias ?? 'Ubicación capturada',
        'centro_empadronamiento_id': registro.centroEmpadronamiento,
        'sincronizado': 0,
        'fecha_sincronizacion': null,
        'id_servidor': null,
        'fecha_creacion_local': DateTime.now().toIso8601String(),
        'intentos': 0,
        'ultimo_intento': null,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Eliminar campos camelCase si existen
      datos.remove('operadorId');
      datos.remove('centroEmpadronamiento');

      final id = await db.insert(
        'registros_despliegue',
        datos,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ Registro de despliegue insertado con ID: $id');
      print('📋 Datos insertados: $datos');

      return id;
    } catch (e) {
      print('❌ Error insertando registro de despliegue: $e');

      // Intentar reparar y reintentar
      try {
        final db = await database;
        await verificarYRepararEstructura();
        return await insertRegistroDespliegue(registro); // Reintentar
      } catch (e2) {
        print('❌ Error en reintento: $e2');
        return -1;
      }
    }
  }

  /// Obtener registros pendientes de sincronización
  Future<List<RegistroDespliegue>> obtenerRegistrosPendientes() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'registros_despliegue',
        where: 'sincronizar = ? AND sincronizado = ? AND intentos < 3',
        whereArgs: [1, 0],
        orderBy: 'fecha_creacion_local ASC',
      );

      return maps.map((map) => RegistroDespliegue.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error obteniendo registros pendientes: $e');
      return [];
    }
  }

  /// Marcar registro como sincronizado
  Future<void> marcarComoSincronizado(int id, {int? idServidor}) async {
    try {
      final db = await database;
      await db.update(
        'registros_despliegue',
        {
          'sincronizado': 1,
          'fecha_sincronizacion': DateTime.now().toIso8601String(),
          'id_servidor': idServidor,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Registro $id marcado como sincronizado');
    } catch (e) {
      print('❌ Error marcando registro como sincronizado: $e');
    }
  }

  /// Incrementar intentos fallidos
  Future<void> incrementarIntentosFallidos(int id) async {
    try {
      final db = await database;
      await db.rawUpdate(
        'UPDATE registros_despliegue SET intentos = intentos + 1, ultimo_intento = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), id],
      );
      print('⚠️ Intentos incrementados para registro $id');
    } catch (e) {
      print('❌ Error incrementando intentos: $e');
    }
  }

  /// Obtener estadísticas de sincronización
  Future<Map<String, dynamic>> obtenerEstadisticasDespliegue() async {
    try {
      final db = await database;

      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as total FROM registros_despliegue',
      );
      final total = totalResult.first['total'] as int? ?? 0;

      final sincronizadosResult = await db.rawQuery(
        'SELECT COUNT(*) as sincronizados FROM registros_despliegue WHERE sincronizado = 1',
      );
      final sincronizados =
          sincronizadosResult.first['sincronizados'] as int? ?? 0;

      final pendientesResult = await db.rawQuery(
        'SELECT COUNT(*) as pendientes FROM registros_despliegue WHERE sincronizar = 1 AND sincronizado = 0 AND intentos < 3',
      );
      final pendientes = pendientesResult.first['pendientes'] as int? ?? 0;

      final fallidosResult = await db.rawQuery(
        'SELECT COUNT(*) as fallidos FROM registros_despliegue WHERE sincronizar = 1 AND sincronizado = 0 AND intentos >= 3',
      );
      final fallidos = fallidosResult.first['fallidos'] as int? ?? 0;

      final porcentaje = total > 0 ? (sincronizados * 100 / total).round() : 0;

      return {
        'total': total,
        'sincronizados': sincronizados,
        'pendientes': pendientes,
        'fallidos': fallidos,
        'porcentaje': porcentaje,
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {
        'total': 0,
        'sincronizados': 0,
        'pendientes': 0,
        'fallidos': 0,
        'porcentaje': 0,
      };
    }
  }

  /// ===================================================================
  /// MÉTODOS PARA REPORTES_DIARIOS
  /// ===================================================================

  /// Insertar reporte diario
  Future<int> insertReporteDiario(Map<String, dynamic> reporteData) async {
    try {
      final db = await database;

      final datos = {
        'fecha_reporte':
            reporteData['fecha_reporte'] ?? DateTime.now().toIso8601String(),
        'contador_inicial_c':
            reporteData['contador_inicial_c'] ?? 'C-00000-0000-0',
        'contador_final_c': reporteData['contador_final_c'] ?? 'C-00000-0000-0',
        'registro_c': reporteData['registro_c'] ?? 0,
        'contador_inicial_r':
            reporteData['contador_inicial_r'] ?? 'R-00000-0000-0',
        'contador_final_r': reporteData['contador_final_r'] ?? 'R-00000-0000-0',
        'registro_r': reporteData['registro_r'] ?? 0,
        'incidencias': reporteData['incidencias'] ?? '',
        'observaciones': reporteData['observaciones'] ?? '',
        'operador': reporteData['operador'] ?? 0,
        'estacion': reporteData['estacion'] ?? 0,
        'centro_empadronamiento_id': reporteData['centro_empadronamiento_id'],
        'estado': reporteData['estado'] ?? 'ENVIO REPORTE',
        'sincronizar': reporteData['sincronizar'] ?? true ? 1 : 0,
        'synced': 0,
        'observacionC': reporteData['observacionC'] ?? '',
        'observacionR': reporteData['observacionR'] ?? '',
        'saltosenC': reporteData['saltosenC'] ?? 0,
        'saltosenR': reporteData['saltosenR'] ?? 0,
        'fecha_creacion_local': DateTime.now().toIso8601String(),
        'intentos': 0,
        'ultima_tentativa': null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final id = await db.insert('reportes_diarios', datos);
      print('✅ Reporte diario insertado con ID: $id');
      return id;
    } catch (e) {
      print('❌ Error insertando reporte diario: $e');
      return -1;
    }
  }

  /// Obtener reportes no sincronizados
  Future<List<Map<String, dynamic>>> obtenerReportesNoSincronizados() async {
    try {
      final db = await database;
      return await db.query(
        'reportes_diarios',
        where: 'synced = ? AND intentos < 3',
        whereArgs: [0],
        orderBy: 'fecha_creacion_local ASC',
      );
    } catch (e) {
      print('❌ Error obteniendo reportes no sincronizados: $e');
      return [];
    }
  }

  /// Marcar reporte como sincronizado
  Future<void> marcarReporteComoEnviado(int id) async {
    try {
      final db = await database;
      await db.update(
        'reportes_diarios',
        {'synced': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Reporte $id marcado como enviado');
    } catch (e) {
      print('❌ Error marcando reporte como enviado: $e');
    }
  }

  /// ===================================================================
  /// MÉTODOS GENERALES
  /// ===================================================================

  /// Insertar datos genéricos
  Future<int> insert(String table, Map<String, dynamic> values) async {
    try {
      final db = await database;
      return await db.insert(
        table,
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ Error insertando en tabla $table: $e');
      return -1;
    }
  }

  /// Actualizar datos
  Future<int> update(
    String table,
    Map<String, dynamic> values,
    String where,
    List<dynamic> whereArgs,
  ) async {
    try {
      final db = await database;
      return await db.update(table, values, where: where, whereArgs: whereArgs);
    } catch (e) {
      print('❌ Error actualizando tabla $table: $e');
      return 0;
    }
  }

  /// Eliminar datos
  Future<int> delete(
    String table,
    String where,
    List<dynamic> whereArgs,
  ) async {
    try {
      final db = await database;
      return await db.delete(table, where: where, whereArgs: whereArgs);
    } catch (e) {
      print('❌ Error eliminando de tabla $table: $e');
      return 0;
    }
  }

  /// Consulta SQL directa
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async {
    try {
      final db = await database;
      return await db.rawQuery(sql, args);
    } catch (e) {
      print('❌ Error ejecutando query: $e');
      return [];
    }
  }

  /// ===================================================================
  /// MÉTODOS DE MANTENIMIENTO
  /// ===================================================================

  /// Asegurar que todas las tablas existan
  Future<void> ensureTablesCreated() async {
    try {
      final db = await database;

      await _createTableRegistrosDespliegue(db);
      await _createTableReportesDiarios(db);
      await _createTableReportesPendientes(db);
      await _createTableUbicaciones(db);

      print('✅ Todas las tablas verificadas/creadas');
    } catch (e) {
      print('❌ Error verificando/creando tablas: $e');
      rethrow;
    }
  }

  /// Limpiar datos antiguos
  Future<void> limpiarDatosAntiguos({int dias = 30}) async {
    try {
      final db = await database;
      final fechaLimite = DateTime.now()
          .subtract(Duration(days: dias))
          .toIso8601String();

      // Limpiar registros sincronizados antiguos
      final registrosEliminados = await db.delete(
        'registros_despliegue',
        where: 'sincronizado = ? AND fecha_creacion_local < ?',
        whereArgs: [1, fechaLimite],
      );

      // Limpiar reportes sincronizados antiguos
      final reportesEliminados = await db.delete(
        'reportes_diarios',
        where: 'synced = ? AND fecha_creacion_local < ?',
        whereArgs: [1, fechaLimite],
      );

      print(
        '🧹 Limpieza completada: $registrosEliminados registros y $reportesEliminados reportes eliminados',
      );
    } catch (e) {
      print('❌ Error limpiando datos antiguos: $e');
    }
  }

  /// Exportar base de datos (para debug)
  Future<Map<String, dynamic>> exportarParaDebug() async {
    try {
      final db = await database;

      final registros = await db.query('registros_despliegue', limit: 10);
      final reportes = await db.query('reportes_diarios', limit: 10);
      final ubicaciones = await db.query('ubicaciones', limit: 10);

      return {
        'registros_despliegue': registros,
        'reportes_diarios': reportes,
        'ubicaciones': ubicaciones,
        'total_registros': registros.length,
        'total_reportes': reportes.length,
        'total_ubicaciones': ubicaciones.length,
      };
    } catch (e) {
      print('❌ Error exportando datos para debug: $e');
      return {'error': e.toString()};
    }
  }

  /// Método equivalente a obtenerEstadisticasDespliegueOffline
  Future<Map<String, dynamic>> obtenerEstadisticasDespliegueOffline() async {
    // Usar el método existente con nombre diferente
    return await obtenerEstadisticasDespliegue();
  }

  /// Método equivalente a obtenerNoSincronizados
  Future<List<RegistroDespliegue>> obtenerNoSincronizados() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'registros_despliegue',
        where: 'sincronizar = ? AND sincronizado = ? AND intentos < 3',
        whereArgs: [1, 0],
        orderBy: 'fecha_creacion_local ASC',
      );
      return maps.map((map) => RegistroDespliegue.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error en obtenerNoSincronizados: $e');
      return [];
    }
  }

  /// Método equivalente a obtenerRegistrosDesplieguePendientes
  Future<List<RegistroDespliegue>>
  obtenerRegistrosDesplieguePendientes() async {
    // Usar el método existente
    return await obtenerRegistrosPendientes();
  }

  /// Método para obtener llegadas pendientes (estado = "LLEGADA")
  Future<List<RegistroDespliegue>> obtenerLlegadasPendientes() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'registros_despliegue',
        where:
            'estado = ? AND sincronizar = ? AND sincronizado = ? AND intentos < 3',
        whereArgs: ['LLEGADA', 1, 0],
        orderBy: 'fecha_creacion_local ASC',
      );
      return maps.map((map) => RegistroDespliegue.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error obteniendo llegadas pendientes: $e');
      return [];
    }
  }

  /// Método para obtener salidas pendientes (estado = "SALIDA")
  Future<List<RegistroDespliegue>> obtenerSalidasPendientes() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'registros_despliegue',
        where:
            'estado = ? AND sincronizar = ? AND sincronizado = ? AND intentos < 3',
        whereArgs: ['SALIDA', 1, 0],
        orderBy: 'fecha_creacion_local ASC',
      );
      return maps.map((map) => RegistroDespliegue.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error obteniendo salidas pendientes: $e');
      return [];
    }
  }

  /// Método para obtener registros sincronizados
  Future<List<RegistroDespliegue>>
  obtenerRegistrosDespliegueSincronizados() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'registros_despliegue',
        where: 'sincronizado = ?',
        whereArgs: [1],
        orderBy: 'fecha_creacion_local DESC',
      );
      return maps.map((map) => RegistroDespliegue.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error obteniendo registros sincronizados: $e');
      return [];
    }
  }

  /// Verificar y reparar estructura de la base de datos
  Future<void> verificarYRepararEstructura() async {
    try {
      final db = await database;
      await _repararColumnasRegistrosDespliegue(db);
    } catch (e) {
      print('❌ Error verificando estructura: $e');
    }
  }

  /// Diagnosticar tabla registros
  Future<Map<String, dynamic>> diagnosticarTablaRegistros() async {
    try {
      final db = await database;

      final columns = await db.rawQuery('PRAGMA table_info(registros_despliegue)');
      final columnNames = columns.map((col) => col['name'] as String).toList();

      final countResult = await db.rawQuery('SELECT COUNT(*) as total FROM registros_despliegue');
      final total = countResult.first['total'] as int? ?? 0;

      final primerosRegistros = await db.query('registros_despliegue', limit: 3);

      return {
        'columnas': columnNames,
        'total_registros': total,
        'primeros_registros': primerosRegistros,
        'tiene_operador_id': columnNames.contains('operador_id'),
        'tiene_operadorId': columnNames.contains('operadorId'),
        'tiene_centro_empadronamiento_id': columnNames.contains('centro_empadronamiento_id'),
        'tiene_centroEmpadronamiento': columnNames.contains('centroEmpadronamiento'),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Reparar nombres de columnas
  Future<void> _repararColumnasRegistrosDespliegue(Database db) async {
    print('🔧 Reparando nombres de columnas en registros_despliegue...');

    try {
      final columns = await db.rawQuery('PRAGMA table_info(registros_despliegue)');
      final columnNames = columns.map((col) => col['name'] as String).toList();

      print('📋 Columnas actuales: $columnNames');

      if (columnNames.contains('operadorId') && !columnNames.contains('operador_id')) {
        print('🔄 Renombrando operadorId → operador_id');
        await db.execute('ALTER TABLE registros_despliegue RENAME COLUMN operadorId TO operador_id');
      }

      if (columnNames.contains('centroEmpadronamiento') && !columnNames.contains('centro_empadronamiento_id')) {
        print('🔄 Renombrando centroEmpadronamiento → centro_empadronamiento_id');
        await db.execute('ALTER TABLE registros_despliegue RENAME COLUMN centroEmpadronamiento TO centro_empadronamiento_id');
      }

      print('✅ Reparación de columnas completada');
    } catch (e) {
      print('❌ Error en reparación de columnas: $e');
    }
  }

  /// Migración forzada V10 (versión que recibe Database como parámetro)
  Future<void> _migracionForzadaV10(Database db) async {
    print('🔧 Migración forzada V10: Recrear tabla registros_despliegue');

    try {
      // 1. Crear tabla temporal
      await db.execute('CREATE TABLE IF NOT EXISTS registros_despliegue_temp AS SELECT * FROM registros_despliegue');

      // 2. Eliminar tabla original
      await db.execute('DROP TABLE IF EXISTS registros_despliegue');

      // 3. Crear tabla con estructura correcta
      await _createTableRegistrosDespliegue(db);

      // 4. Copiar datos de vuelta
      await db.execute('''
      INSERT INTO registros_despliegue (
        id, fecha_hora, operador_id, estado, latitud, longitud, 
        observaciones, sincronizar, descripcion_reporte, incidencias,
        centro_empadronamiento_id, sincronizado, fecha_sincronizacion,
        id_servidor, fecha_creacion_local, intentos, ultimo_intento,
        created_at, updated_at
      )
      SELECT 
        id, fecha_hora, 
        CASE 
          WHEN operadorId IS NOT NULL THEN operadorId
          ELSE operador_id
        END,
        estado, latitud, longitud, observaciones, sincronizar, 
        descripcion_reporte, incidencias,
        CASE 
          WHEN centroEmpadronamiento IS NOT NULL THEN centroEmpadronamiento
          ELSE centro_empadronamiento_id
        END,
        sincronizado, fecha_sincronizacion, id_servidor, 
        fecha_creacion_local, intentos, ultimo_intento,
        created_at, updated_at
      FROM registros_despliegue_temp
    ''');

      // 5. Eliminar tabla temporal
      await db.execute('DROP TABLE IF EXISTS registros_despliegue_temp');

      print('✅ Migración forzada V10 completada');
    } catch (e) {
      print('❌ Error en migración forzada V10: $e');
      await db.execute('DROP TABLE IF EXISTS registros_despliegue');
      await _createTableRegistrosDespliegue(db);
    }
  }


  /// Migración forzada V10
  /// Migración forzada V10
  Future<void> migracionForzadaV10() async {
    print('🔧 Migración forzada V10: Recrear tabla registros_despliegue');

    Database? db;
    try {
      db = await database;

      // 1. Crear tabla temporal
      await db.execute('CREATE TABLE IF NOT EXISTS registros_despliegue_temp AS SELECT * FROM registros_despliegue');

      // 2. Eliminar tabla original
      await db.execute('DROP TABLE IF EXISTS registros_despliegue');

      // 3. Crear tabla con estructura correcta
      await _createTableRegistrosDespliegue(db);

      // 4. Copiar datos de vuelta
      await db.execute('''
      INSERT INTO registros_despliegue (
        id, fecha_hora, operador_id, estado, latitud, longitud, 
        observaciones, sincronizar, descripcion_reporte, incidencias,
        centro_empadronamiento_id, sincronizado, fecha_sincronizacion,
        id_servidor, fecha_creacion_local, intentos, ultimo_intento,
        created_at, updated_at
      )
      SELECT 
        id, fecha_hora, 
        CASE 
          WHEN operadorId IS NOT NULL THEN operadorId
          ELSE operador_id
        END,
        estado, latitud, longitud, observaciones, sincronizar, 
        descripcion_reporte, incidencias,
        CASE 
          WHEN centroEmpadronamiento IS NOT NULL THEN centroEmpadronamiento
          ELSE centro_empadronamiento_id
        END,
        sincronizado, fecha_sincronizacion, id_servidor, 
        fecha_creacion_local, intentos, ultimo_intento,
        created_at, updated_at
      FROM registros_despliegue_temp
    ''');

      // 5. Eliminar tabla temporal
      await db.execute('DROP TABLE IF EXISTS registros_despliegue_temp');

      print('✅ Migración forzada V10 completada');
    } catch (e) {
      print('❌ Error en migración forzada V10: $e');
      if (db != null) {
        await db.execute('DROP TABLE IF EXISTS registros_despliegue');
        await _createTableRegistrosDespliegue(db);
      }
    }
  }

  // AGREGAR ESTOS MÉTODOS A LA CLASE DatabaseService:

  /// ===================================================================
  /// MÉTODOS PARA UBICACIONES
  /// ===================================================================

  /// Obtener ubicaciones pendientes de sincronización

  /// Marcar ubicación como sincronizada
  Future<void> marcarUbicacionSincronizada(int id) async {
    try {
      final db = await database;
      await db.update(
        'ubicaciones',
        {
          'sincronizado': 1,
          'fecha_sincronizacion': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Ubicación $id marcada como sincronizada');
    } catch (e) {
      print('❌ Error marcando ubicación como sincronizada: $e');
    }
  }

  /// Obtener estadísticas de ubicaciones
  Future<Map<String, dynamic>> obtenerEstadisticasUbicaciones() async {
    try {
      final db = await database;

      // Total de ubicaciones
      final totalResult = await db.rawQuery('SELECT COUNT(*) as total FROM ubicaciones');
      final total = totalResult.first['total'] as int? ?? 0;

      // Ubicaciones pendientes
      final pendientesResult = await db.rawQuery('SELECT COUNT(*) as pendientes FROM ubicaciones WHERE sincronizado = 0');
      final pendientes = pendientesResult.first['pendientes'] as int? ?? 0;

      // Ubicación más antigua pendiente
      final antiguaResult = await db.rawQuery('SELECT MIN(fecha_creacion) as mas_antigua FROM ubicaciones WHERE sincronizado = 0');
      final masAntigua = antiguaResult.first['mas_antigua'] as String?;

      // Ubicaciones sincronizadas
      final sincronizadas = total - pendientes;

      return {
        'total': total,
        'pendientes': pendientes,
        'sincronizadas': sincronizadas,
        'mas_antigua': masAntigua,
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas de ubicaciones: $e');
      return {
        'total': 0,
        'pendientes': 0,
        'sincronizadas': 0,
        'mas_antigua': null,
      };
    }
  }

  /// Sincronizar ubicaciones pendientes
// En DatabaseService, en el método sincronizarUbicacionesPendientes:

  Future<Map<String, dynamic>> sincronizarUbicacionesPendientes(String accessToken) async {
    try {
      final db = await database;

      // Obtener ubicaciones pendientes (ahora devuelve List<UbicacionModel>)
      final ubicacionesPendientes = await obtenerUbicacionesPendientes();

      if (ubicacionesPendientes.isEmpty) {
        return {
          'success': true,
          'message': 'No hay ubicaciones pendientes',
          'sincronizadas': 0,
        };
      }

      print('🔄 Sincronizando ${ubicacionesPendientes.length} ubicaciones pendientes...');

      int sincronizadas = 0;
      int fallidas = 0;

      for (final ubicacion in ubicacionesPendientes) {
        try {
          // ✅ CORRECCIÓN: Usar propiedades del modelo UbicacionModel
          final datosApi = {
            'user_id': ubicacion.userId,  // ✅ ubicacion.userId en lugar de ubicacion['user_id']
            'latitud': ubicacion.latitud,  // ✅ ubicacion.latitud
            'longitud': ubicacion.longitud, // ✅ ubicacion.longitud
            'timestamp': ubicacion.timestamp.toIso8601String(), // ✅ ubicacion.timestamp
            'tipo_usuario': ubicacion.tipoUsuario, // ✅ ubicacion.tipoUsuario
            'sincronizado': 1,
          };

          // Enviar a la API
          final enviado = await _enviarUbicacionApi(datosApi, accessToken);

          if (enviado) {
            await marcarUbicacionSincronizada(ubicacion.id!); // ✅ ubicacion.id!
            sincronizadas++;
            print('✅ Ubicación ${ubicacion.id} sincronizada');
          } else {
            fallidas++;
            print('❌ Error sincronizando ubicación ${ubicacion.id}');
          }
        } catch (e) {
          fallidas++;
          print('❌ Error sincronizando ubicación ${ubicacion.id}: $e');
        }
      }

      return {
        'success': sincronizadas > 0,
        'message': 'Sincronización completada: $sincronizadas exitosas, $fallidas fallidas',
        'sincronizadas': sincronizadas,
        'fallidas': fallidas,
      };
    } catch (e) {
      print('❌ Error en sincronización masiva de ubicaciones: $e');
      return {
        'success': false,
        'message': 'Error en sincronización: ${e.toString()}',
        'sincronizadas': 0,
        'fallidas': 0,
      };
    }
  }

  /// Método auxiliar para enviar ubicación a API
  Future<bool> _enviarUbicacionApi(Map<String, dynamic> datos, String accessToken) async {
    try {
      final url = '${Enviroment.apiUrlDev}ubicaciones-operador/';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(datos),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Error enviando ubicación a API: $e');
      return false;
    }
  }

  /// Limpiar ubicaciones antiguas (más de 7 días)
  Future<void> limpiarUbicacionesAntiguas() async {
    try {
      final db = await database;
      final fechaLimite = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

      final eliminadas = await db.delete(
        'ubicaciones',
        where: 'fecha_creacion < ? AND sincronizado = ?',
        whereArgs: [fechaLimite, 1],
      );

      print('🧹 Ubicaciones antiguas limpiadas: $eliminadas registros');
    } catch (e) {
      print('❌ Error limpiando ubicaciones antiguas: $e');
    }
  }

  // En DatabaseService, actualiza los métodos:

  /// Guardar ubicación localmente (acepta UbicacionModel o Map)
  Future<int> guardarUbicacionLocal(dynamic ubicacionData) async {
    try {
      final db = await database;

      Map<String, dynamic> datos;

      if (ubicacionData is UbicacionModel) {
        // Si es un modelo, convertir a Map
        datos = {
          'user_id': ubicacionData.userId,
          'latitud': ubicacionData.latitud,
          'longitud': ubicacionData.longitud,
          'timestamp': ubicacionData.timestamp.toIso8601String(),
          'tipo_usuario': ubicacionData.tipoUsuario,
          'sincronizado': ubicacionData.sincronizado ?? 0,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'fecha_sincronizacion': ubicacionData.fechaSincronizacion,
        };
      } else if (ubicacionData is Map<String, dynamic>) {
        // Si ya es un Map, usarlo directamente
        datos = {
          'user_id': ubicacionData['user_id'] ?? ubicacionData['userId'],
          'latitud': ubicacionData['latitud'],
          'longitud': ubicacionData['longitud'],
          'timestamp': ubicacionData['timestamp'] ?? DateTime.now().toIso8601String(),
          'tipo_usuario': ubicacionData['tipo_usuario'] ?? ubicacionData['tipoUsuario'],
          'sincronizado': 0,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'fecha_sincronizacion': null,
        };
      } else {
        throw ArgumentError('Tipo de dato no soportado: ${ubicacionData.runtimeType}');
      }

      final id = await db.insert('ubicaciones', datos);
      print('✅ Ubicación guardada localmente con ID: $id');
      return id;
    } catch (e) {
      print('❌ Error guardando ubicación local: $e');
      return -1;
    }
  }

  /// Obtener ubicaciones pendientes de sincronización (devuelve List<UbicacionModel>)
  Future<List<UbicacionModel>> obtenerUbicacionesPendientes() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'ubicaciones',
        where: 'sincronizado = ?',
        whereArgs: [0],
        orderBy: 'fecha_creacion ASC',
      );

      return maps.map((map) => _ubicacionFromMap(map)).toList();
    } catch (e) {
      print('❌ Error obteniendo ubicaciones pendientes: $e');
      return [];
    }
  }

  /// Convertir Map de BD a UbicacionModel
  UbicacionModel _ubicacionFromMap(Map<String, dynamic> map) {
    return UbicacionModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      latitud: (map['latitud'] as num).toDouble(),
      longitud: (map['longitud'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      tipoUsuario: map['tipo_usuario'] as String,
      sincronizado: map['sincronizado'] as int?,
      fechaSincronizacion: map['fecha_sincronizacion'] as String?,
    );
  }

  // En DatabaseService, agrega este método:
  Future<int> insertRegistroConCorreccion(Map<String, dynamic> datos) async {
    try {
      final db = await database;

      // ✅ CORRECCIÓN AUTOMÁTICA: Convertir camelCase a snake_case
      final datosCorregidos = Map<String, dynamic>.from(datos);

      // Mapeo de conversiones
      final conversiones = {
        'operadorId': 'operador_id',
        'centroEmpadronamiento': 'centro_empadronamiento_id',
        'fechaHora': 'fecha_hora',
        'descripcionReporte': 'descripcion_reporte',
        'fechaSincronizacion': 'fecha_sincronizacion',
        'idServidor': 'id_servidor',
        'fechaCreacionLocal': 'fecha_creacion_local',
        'ultimoIntento': 'ultimo_intento',
      };

      // Aplicar conversiones
      conversiones.forEach((camelCase, snakeCase) {
        if (datosCorregidos.containsKey(camelCase)) {
          datosCorregidos[snakeCase] = datosCorregidos[camelCase];
          datosCorregidos.remove(camelCase);
        }
      });

      // Asegurar campos requeridos
      final ahora = DateTime.now().toIso8601String();
      datosCorregidos['fecha_creacion_local'] ??= ahora;
      datosCorregidos['created_at'] ??= ahora;
      datosCorregidos['updated_at'] ??= ahora;
      datosCorregidos['intentos'] ??= 0;

      print('🔍 Datos corregidos para inserción:');
      datosCorregidos.forEach((key, value) {
        print('  - $key: $value');
      });

      final id = await db.insert(
        'registros_despliegue',
        datosCorregidos,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ Registro insertado con ID: $id');
      return id;
    } catch (e) {
      print('❌ Error en insertRegistroConCorreccion: $e');

      // Diagnosticar error
      if (e.toString().contains('no column named')) {
        final match = RegExp(r"no column named '(\w+)'").firstMatch(e.toString());
        if (match != null) {
          final columnaErronea = match.group(1)!;
          print('🔴 Columna errónea detectada: $columnaErronea');
        }
      }

      return -1;
    }
  }
}
