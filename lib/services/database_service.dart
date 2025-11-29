// lib/services/database_service.dart - VERSIÓN FINAL CORREGIDA
import 'package:manager_key/models/ubicacion_model.dart';
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
    if (_database != null) return _database!;
    _database = await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'app_database.db');

    return await openDatabase(
      path,
      version: 5, // ✅ INCREMENTADO A 5 PARA FORZAR RECREACIÓN
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    print('🗄️ Creando BD versión $version...');

    // ✅ TABLA REGISTROS DE DESPLIEGUE CON CAMELCASE CONSISTENTE
    await db.execute('''
      CREATE TABLE registros_despliegue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitud TEXT NOT NULL,
        longitud TEXT NOT NULL,
        descripcionReporte TEXT,
        estado TEXT NOT NULL DEFAULT 'DESPLIEGUE',
        sincronizar INTEGER NOT NULL DEFAULT 0,
        observaciones TEXT,
        incidencias TEXT,
        fechaHora TEXT NOT NULL,
        operadorId INTEGER NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        centroEmpadronamiento INTEGER,
        fechaSincronizacion TEXT
      )
    ''');
    print('✅ Tabla registros_despliegue creada');

    // Tabla reportes diarios
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
        updated_at TEXT,
        // ✅ NUEVOS CAMPOS
        observacionC TEXT,
        observacionR TEXT,
        saltosenC INTEGER DEFAULT 0,
        saltosenR INTEGER DEFAULT 0,
        centro_empadronamiento INTEGER
      )
    ''');

    // Tabla de ubicaciones
    await db.execute('''
      CREATE TABLE ubicaciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        latitud REAL NOT NULL,
        longitud REAL NOT NULL,
        timestamp TEXT NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        tipoUsuario TEXT NOT NULL
      )
    ''');

    // Tabla puntos de empadronamiento
    await db.execute('''
      CREATE TABLE puntos_empadronamiento (
        id INTEGER PRIMARY KEY,
        provincia TEXT,
        punto_de_empadronamiento TEXT
      )
    ''');

    print('✅ Todas las tablas creadas exitosamente');
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    print('🔄 Migrando BD de versión $oldVersion a $newVersion...');

    // Versión 2: Crear tabla de reportes
    if (oldVersion < 2) {
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

    // Versión 3: Crear tabla de ubicaciones
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ubicaciones (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER NOT NULL,
          latitud REAL NOT NULL,
          longitud REAL NOT NULL,
          timestamp TEXT NOT NULL,
          sincronizado INTEGER NOT NULL DEFAULT 0,
          tipoUsuario TEXT NOT NULL
        )
      ''');
    }

    // ✅ VERSIÓN 4 & 5: GARANTIZAR ESTRUCTURA CONSISTENTE EN CAMELCASE
    if (oldVersion < 5) {
      print('🔧 Aplicando correcciones finales...');

      try {
        // Verificar si la tabla existe
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='registros_despliegue'",
        );

        if (tables.isNotEmpty) {
          // Obtener estructura actual
          final columns = await db.rawQuery(
            'PRAGMA table_info(registros_despliegue)',
          );
          final columnNames = columns
              .map((col) => col['name'] as String)
              .toList();

          print('📋 Columnas existentes: $columnNames');

          // Verificar si necesita migración
          if (columnNames.contains('descripcion_reporte') ||
              columnNames.contains('fecha_hora') ||
              columnNames.contains('operador_id')) {
            print('⚠️  Detectada estructura antiga (snake_case), migrando...');

            // Renombrar tabla antigua
            await db.execute(
              'ALTER TABLE registros_despliegue RENAME TO registros_despliegue_backup',
            );

            // Crear tabla nueva con estructura correcta (camelCase)
            await db.execute('''
              CREATE TABLE registros_despliegue (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                latitud TEXT NOT NULL,
                longitud TEXT NOT NULL,
                descripcionReporte TEXT,
                estado TEXT NOT NULL DEFAULT 'DESPLIEGUE',
                sincronizar INTEGER NOT NULL DEFAULT 0,
                observaciones TEXT,
                incidencias TEXT,
                fechaHora TEXT NOT NULL,
                operadorId INTEGER NOT NULL,
                sincronizado INTEGER NOT NULL DEFAULT 0,
                centroEmpadronamiento INTEGER,
                fechaSincronizacion TEXT
              )
            ''');

            // Copiar datos con mapeo correcto
            try {
              await db.execute('''
                INSERT INTO registros_despliegue 
                (id, latitud, longitud, descripcionReporte, estado, sincronizar,
                 observaciones, incidencias, fechaHora, operadorId, sincronizado,
                 centroEmpadronamiento, fechaSincronizacion)
                SELECT 
                  id, latitud, longitud, 
                  COALESCE(descripcion_reporte, descripcionReporte) as descripcionReporte,
                  estado, sincronizar, observaciones, incidencias,
                  COALESCE(fecha_hora, fechaHora) as fechaHora,
                  COALESCE(operador_id, operadorId) as operadorId,
                  sincronizado, centroEmpadronamiento, fechaSincronizacion
                FROM registros_despliegue_backup
              ''');
              print('✅ Datos migrados exitosamente');
            } catch (e) {
              print('⚠️  Error migrando datos (tabla vacía?): $e');
            }

            // Eliminar backup
            await db.execute('DROP TABLE registros_despliegue_backup');
            print('✅ Tabla limpiada y reorganizada');
          } else if (!columnNames.contains('centroEmpadronamiento')) {
            // La tabla existe pero le faltan columnas nuevas
            print('⚠️  Agregando columnas faltantes...');

            try {
              if (!columnNames.contains('centroEmpadronamiento')) {
                await db.execute(
                  'ALTER TABLE registros_despliegue ADD COLUMN centroEmpadronamiento INTEGER',
                );
              }
              if (!columnNames.contains('fechaSincronizacion')) {
                await db.execute(
                  'ALTER TABLE registros_despliegue ADD COLUMN fechaSincronizacion TEXT',
                );
              }
              print('✅ Columnas añadidas');
            } catch (e) {
              print('⚠️  Las columnas podrían ya existir: $e');
            }
          } else {
            print('✅ Tabla ya tiene la estructura correcta');
          }
        } else {
          // La tabla no existe, crearla
          await db.execute('''
            CREATE TABLE registros_despliegue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              latitud TEXT NOT NULL,
              longitud TEXT NOT NULL,
              descripcionReporte TEXT,
              estado TEXT NOT NULL DEFAULT 'DESPLIEGUE',
              sincronizar INTEGER NOT NULL DEFAULT 0,
              observaciones TEXT,
              incidencias TEXT,
              fechaHora TEXT NOT NULL,
              operadorId INTEGER NOT NULL,
              sincronizado INTEGER NOT NULL DEFAULT 0,
              centroEmpadronamiento INTEGER,
              fechaSincronizacion TEXT
            )
          ''');
          print('✅ Tabla registros_despliegue creada en migración');
        }
      } catch (e) {
        print('❌ Error crítico en migración: $e');
        rethrow;
      }
    }

    if (oldVersion < 6) {
      print('🔧 Aplicando migración versión 6: Agregando nuevos campos...');

      try {
        // Verificar si la tabla reportes_diarios existe
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='reportes_diarios'",
        );

        if (tables.isNotEmpty) {
          // Agregar nuevos campos si no existen
          final columns = await db.rawQuery('PRAGMA table_info(reportes_diarios)');
          final columnNames = columns.map((col) => col['name'] as String).toList();

          if (!columnNames.contains('observacionC')) {
            await db.execute('ALTER TABLE reportes_diarios ADD COLUMN observacionC TEXT');
            print('✅ Columna observacionC agregada');
          }

          if (!columnNames.contains('observacionR')) {
            await db.execute('ALTER TABLE reportes_diarios ADD COLUMN observacionR TEXT');
            print('✅ Columna observacionR agregada');
          }

          if (!columnNames.contains('saltosenC')) {
            await db.execute('ALTER TABLE reportes_diarios ADD COLUMN saltosenC INTEGER DEFAULT 0');
            print('✅ Columna saltosenC agregada');
          }

          if (!columnNames.contains('saltosenR')) {
            await db.execute('ALTER TABLE reportes_diarios ADD COLUMN saltosenR INTEGER DEFAULT 0');
            print('✅ Columna saltosenR agregada');
          }

          if (!columnNames.contains('centro_empadronamiento')) {
            await db.execute('ALTER TABLE reportes_diarios ADD COLUMN centro_empadronamiento INTEGER');
            print('✅ Columna centro_empadronamiento agregada');
          }
        }
      } catch (e) {
        print('❌ Error en migración versión 6: $e');
      }
    }
    print('✅ Migración finalizada');
  }

  // ========== MÉTODOS PARA REGISTROS DE DESPLIEGUE ==========

  Future<List<RegistroDespliegue>> obtenerTodosRegistros() async {
    try {
      final db = await database;
      final result = await db.query('registros_despliegue');
      return result.map((json) => RegistroDespliegue.fromMap(json)).toList();
    } catch (e) {
      print('❌ Error al obtener registros: $e');
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
      print('❌ Error al obtener no sincronizados: $e');
      return [];
    }
  }

  Future<List<RegistroDespliegue>> obtenerRegistrosActivos() async {
    try {
      final db = await database;
      final result = await db.query(
        'registros_despliegue',
        where: 'estado = ?',
        whereArgs: ['DESPLIEGUE'],
      );
      return result.map((json) => RegistroDespliegue.fromMap(json)).toList();
    } catch (e) {
      print('❌ Error al obtener registros activos: $e');
      return [];
    }
  }

  Future<void> marcarComoSincronizado(int id) async {
    try {
      final db = await database;
      await db.update(
        'registros_despliegue',
        {
          'sincronizado': 1,
          'fechaSincronizacion': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Registro $id marcado como sincronizado');
    } catch (e) {
      print('❌ Error al marcar como sincronizado: $e');
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
      print('❌ Error al obtener registro por ID: $e');
      return null;
    }
  }

  Future<void> eliminarRegistroDespliegue(int id) async {
    try {
      final db = await database;
      await db.delete('registros_despliegue', where: 'id = ?', whereArgs: [id]);
      print('✅ Registro $id eliminado');
    } catch (e) {
      print('❌ Error al eliminar registro: $e');
    }
  }

  Future<void> eliminarRegistro(int id) async {
    await eliminarRegistroDespliegue(id);
  }

  Future<void> limpiarBaseDatos() async {
    try {
      final db = await database;
      await db.delete('registros_despliegue');
      print('✅ Base de datos limpiada');
    } catch (e) {
      print('❌ Error al limpiar base de datos: $e');
    }
  }

  Future<List<RegistroDespliegue>>
  obtenerRegistrosDespliegueNoSincronizados() async {
    return obtenerNoSincronizados();
  }

  // ========== MÉTODOS PARA REPORTES DIARIOS ==========

  // Future<int> insertReporte(Map<String, dynamic> data) async {
  //   try {
  //     final db = await database;
  //     final cleanedData = _limpiarDatosParaSQLite(data);
  //     final mappedData = Map<String, dynamic>.from(cleanedData);
  //
  //     if (mappedData.containsKey('registro_c')) {
  //       mappedData['contador_c'] = mappedData['registro_c'];
  //       mappedData.remove('registro_c');
  //     }
  //     if (mappedData.containsKey('registro_r')) {
  //       mappedData['contador_r'] = mappedData['registro_r'];
  //       mappedData.remove('registro_r');
  //     }
  //
  //     final result = await db.insert('reportes_diarios', {
  //       ...mappedData,
  //       'updated_at': DateTime.now().toIso8601String(),
  //     }, conflictAlgorithm: ConflictAlgorithm.replace);
  //     print('✅ Reporte insertado con ID: $result');
  //     return result;
  //   } catch (e) {
  //     print('❌ Error al insertar reporte: $e');
  //     rethrow;
  //   }
  // }
  Future<int> insertReporte(Map<String, dynamic> data) async {
    try {
      final db = await database;
      final cleanedData = _limpiarDatosParaSQLite(data);
      final mappedData = Map<String, dynamic>.from(cleanedData);

      // Mapeo de campos existentes
      if (mappedData.containsKey('registro_c')) {
        mappedData['contador_c'] = mappedData['registro_c'];
        mappedData.remove('registro_c');
      }
      if (mappedData.containsKey('registro_r')) {
        mappedData['contador_r'] = mappedData['registro_r'];
        mappedData.remove('registro_r');
      }

      // ✅ NUEVO: Mapeo de campos adicionales
      final datosParaInsertar = {
        ...mappedData,
        'updated_at': DateTime.now().toIso8601String(),
        // Campos nuevos con valores por defecto si no existen
        'observacionC': mappedData['observacionC'] ?? '',
        'observacionR': mappedData['observacionR'] ?? '',
        'saltosenC': mappedData['saltosenC'] ?? 0,
        'saltosenR': mappedData['saltosenR'] ?? 0,
        'centro_empadronamiento': mappedData['centro_empadronamiento'],
      };

      final result = await db.insert(
          'reportes_diarios',
          datosParaInsertar,
          conflictAlgorithm: ConflictAlgorithm.replace
      );

      print('✅ Reporte insertado con ID: $result');
      print('📋 Datos insertados: $datosParaInsertar');

      return result;
    } catch (e) {
      print('❌ Error al insertar reporte: $e');
      rethrow;
    }
  }

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

  Future<int> markReporteAsSynced(int id) async {
    try {
      final db = await database;
      final result = await db.update(
        'reportes_diarios',
        {'synced': 1, 'updated_at': DateTime.now().toIso8601String()},
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

  Future<int> deleteSyncedReportesByOperador(int operadorId) async {
    try {
      final db = await database;
      final count = await db.delete(
        'reportes_diarios',
        where: 'operador = ? AND synced = ?',
        whereArgs: [operadorId, 1],
      );
      return count;
    } catch (e) {
      print('❌ Error al eliminar reportes sincronizados por operador: $e');
      rethrow;
    }
  }

  Future<int> countUnsyncedReportes() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM reportes_diarios WHERE synced = 0',
      );
      final count = Sqflite.firstIntValue(result) ?? 0;
      print('📈 Reportes pendientes: $count');
      return count;
    } catch (e) {
      print('❌ Error al contar reportes sin sincronizar: $e');
      return 0;
    }
  }

  // ========== MÉTODOS PARA UBICACIONES ==========

  Future<void> guardarUbicacionLocal(UbicacionModel ubicacion) async {
    final db = await database;
    final data = ubicacion.toJson();
    data.remove('id');

    try {
      await db.insert('ubicaciones', data);
      print('✅ Ubicación guardada localmente');
    } catch (e) {
      print('❌ ERROR guardando ubicación local: $e');
      rethrow;
    }
  }

  Future<List<UbicacionModel>> obtenerUbicacionesPendientes() async {
    final db = await database;
    final results = await db.query(
      'ubicaciones',
      where: 'sincronizado = ?',
      whereArgs: [0],
    );
    return results.map((json) => UbicacionModel.fromJson(json)).toList();
  }

  Future<void> marcarUbicacionSincronizada(int id) async {
    final db = await database;
    await db.update(
      'ubicaciones',
      {'sincronizado': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>> obtenerEstadisticasUbicaciones() async {
    final db = await database;

    final total = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ubicaciones',
    );

    final pendientes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ubicaciones WHERE sincronizado = 0',
    );

    final masAntigua = await db.rawQuery(
      'SELECT timestamp FROM ubicaciones WHERE sincronizado = 0 ORDER BY timestamp ASC LIMIT 1',
    );

    return {
      'total': Sqflite.firstIntValue(total) ?? 0,
      'pendientes': Sqflite.firstIntValue(pendientes) ?? 0,
      'mas_antigua': masAntigua.isNotEmpty
          ? masAntigua.first['timestamp']
          : null,
    };
  }

  Future<void> limpiarUbicacionesSincronizadas() async {
    final db = await database;
    final result = await db.delete(
      'ubicaciones',
      where: 'sincronizado = ?',
      whereArgs: [1],
    );
    print('🗑️ Ubicaciones sincronizadas eliminadas: $result');
  }

  Future<UbicacionModel?> obtenerUbicacionPorId(int id) async {
    final db = await database;
    final results = await db.query(
      'ubicaciones',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? UbicacionModel.fromJson(results.first) : null;
  }

  // ========== MÉTODO AUXILIAR ==========

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

  // ========== MÉTODOS PARA PUNTOS DE EMPADRONAMIENTO ==========

  Future<List<Map<String, dynamic>>> obtenerPuntosEmpadronamiento() async {
    try {
      final db = await database;
      final result = await db.query('puntos_empadronamiento');
      return result;
    } catch (e) {
      print('❌ Error al obtener puntos de empadronamiento: $e');
      return [];
    }
  }

  Future<void> guardarPuntosEmpadronamiento(
    List<Map<String, dynamic>> puntos,
  ) async {
    try {
      final db = await database;
      await db.delete('puntos_empadronamiento');
      for (var punto in puntos) {
        await db.insert('puntos_empadronamiento', punto);
      }
      print('✅ Puntos de empadronamiento guardados: ${puntos.length}');
    } catch (e) {
      print('❌ Error al guardar puntos de empadronamiento: $e');
      rethrow;
    }
  }

  // âœ… SECCIÓN CORREGIDA: MÃ©todo insertRegistroDespliegue
  Future<int> insertRegistroDespliegue(RegistroDespliegue registro) async {
    try {
      print('ðŸ" Insertando registro: ${registro.toMap()}');
      final db = await database;

      // âœ… MAPEO CORRECTO CON CONVERSIONES NECESARIAS
      final Map<String, dynamic> datosParaInsertar = {
        'latitud': registro.latitud ?? '0',
        'longitud': registro.longitud ?? '0',
        'descripcionReporte':
            registro.descripcionReporte ?? '', // âœ… CONVIERTE null A ""
        'estado': registro.estado,
        'sincronizar': registro.sincronizar ? 1 : 0,
        'observaciones': registro.observaciones ?? '',
        'incidencias': registro.incidencias ?? '',
        'fechaHora': registro.fechaHora,
        'operadorId': registro.operadorId,
        'sincronizado': registro.sincronizado ? 1 : 0,
        'centroEmpadronamiento': registro.centroEmpadronamiento,
        'fechaSincronizacion': registro.fechaSincronizacion,
      };

      print('ðŸ"¦ Datos con mapeo correcto: $datosParaInsertar');

      final result = await db.insert(
        'registros_despliegue',
        datosParaInsertar,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('âœ… Registro insertado con ID: $result');
      return result;
    } catch (e) {
      print('âŒ Error al insertar registro: $e');
      print('ðŸ" Tipo de error: ${e.runtimeType}');
      // âœ… NO relanzar para que no rompa la app
      return -1;
    }
  }

  // âœ… TAMBIÉN CORREGIR: MÃ©todo actualizarRegistroDespliegue
  Future<int> actualizarRegistroDespliegue(RegistroDespliegue registro) async {
    try {
      final db = await database;
      if (registro.id == null) {
        throw Exception('El registro debe tener un ID para actualizarse');
      }
      final result = await db.update(
        'registros_despliegue',
        {
          'latitud': registro.latitud ?? '0',
          'longitud': registro.longitud ?? '0',
          'descripcionReporte': registro.descripcionReporte ?? '',
          'estado': registro.estado,
          'sincronizar': registro.sincronizar ? 1 : 0,
          'observaciones': registro.observaciones ?? '',
          'incidencias': registro.incidencias ?? '',
          'fechaHora': registro.fechaHora,
          'operadorId': registro.operadorId,
          'sincronizado': registro.sincronizado ? 1 : 0,
          'centroEmpadronamiento': registro.centroEmpadronamiento,
          'fechaSincronizacion': registro.fechaSincronizacion,
        },
        where: 'id = ?',
        whereArgs: [registro.id],
      );
      print('âœ… Registro actualizado: $result filas afectadas');
      return result;
    } catch (e) {
      print('âŒ Error al actualizar registro: $e');
      return -1;
    }
  }
}
