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
      version: 6, // Incrementado para asegurar la migración si es necesario
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    print('🗄️ Creando BD versión $version...');

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
        observacionC TEXT,
        observacionR TEXT,
        saltosenC INTEGER DEFAULT 0,
        saltosenR INTEGER DEFAULT 0,
        centro_empadronamiento INTEGER
      )
    ''');
    print('✅ Tabla reportes_diarios creada');

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
    print('✅ Tabla ubicaciones creada');

    await db.execute('''
      CREATE TABLE puntos_empadronamiento (
        id INTEGER PRIMARY KEY,
        provincia TEXT,
        punto_de_empadronamiento TEXT
      )
    ''');
    print('✅ Tabla puntos_empadronamiento creada');

    print('✅ Todas las tablas creadas exitosamente');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
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
          observacionC TEXT,
          observacionR TEXT,
          saltosenC INTEGER DEFAULT 0,
          saltosenR INTEGER DEFAULT 0,
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
        {'sincronizado': 1, 'fechaSincronizacion': DateTime.now().toIso8601String()},
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
      return result.isNotEmpty ? RegistroDespliegue.fromMap(result.first) : null;
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

  Future<void> limpiarBaseDatos() async {
    try {
      final db = await database;
      await db.delete('registros_despliegue');
      print('✅ Base de datos (registros_despliegue) limpiada');
    } catch (e) {
      print('❌ Error al limpiar base de datos: $e');
    }
  }

  Future<List<RegistroDespliegue>> obtenerRegistrosDespliegueNoSincronizados() async {
    return obtenerNoSincronizados();
  }

  // ========== MÉTODOS PARA REPORTES DIARIOS ==========

  Future<int> insertReporte(Map<String, dynamic> data) async {
    try {
      final db = await database;
      final cleanedData = _limpiarDatosParaSQLite(data);
      final mappedData = Map<String, dynamic>.from(cleanedData);

      if (mappedData.containsKey('registro_c')) {
        mappedData['contador_c'] = mappedData['registro_c'];
        mappedData.remove('registro_c');
      }
      if (mappedData.containsKey('registro_r')) {
        mappedData['contador_r'] = mappedData['registro_r'];
        mappedData.remove('registro_r');
      }

      final datosParaInsertar = {
        ...mappedData,
        'updated_at': DateTime.now().toIso8601String(),
        'observacionC': mappedData['observacionC'] ?? '',
        'observacionR': mappedData['observacionR'] ?? '',
        'saltosenC': mappedData['saltosenC'] ?? 0,
        'saltosenR': mappedData['saltosenR'] ?? 0,
        'centro_empadronamiento': mappedData['centro_empadronamiento'],
      };

      final result = await db.insert(
        'reportes_diarios',
        datosParaInsertar,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ Reporte insertado con ID: $result');
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
      final result = await db.query('reportes_diarios', orderBy: 'fecha_reporte DESC');
      print('📊 Total de reportes: ${result.length}');
      return result;
    } catch (e) {
      print('❌ Error al obtener reportes: $e');
      return [];
    }
  }

  // ========== MÉTODOS ADICIONALES PARA REPORTES DIARIOS ==========

  /// Elimina un reporte específico de la base de datos local por su ID.
  /// Se usa después de que un reporte ha sido sincronizado exitosamente.
  Future<void> deleteReporte(int id) async {
    try {
      final db = await database;
      final count = await db.delete(
        'reportes_diarios',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count > 0) {
        print('✅ Reporte local con ID $id eliminado exitosamente.');
      } else {
        print('⚠️ No se encontró el reporte local con ID $id para eliminar.');
      }
    } catch (e) {
      print('❌ Error al eliminar el reporte local con ID $id: $e');
      rethrow;
    }
  }

  /// Cuenta cuántos reportes están pendientes de sincronizar en la BD local.
  /// Útil para mostrar un indicador en la UI.
  Future<int> countUnsyncedReportes() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) FROM reportes_diarios WHERE synced = ?',
        [0],
      );
      final count = Sqflite.firstIntValue(result);
      print('🔄 Hay $count reportes pendientes de sincronizar.');
      return count ?? 0;
    } catch (e) {
      print('❌ Error al contar los reportes no sincronizados: $e');
      return 0;
    }
  }

  /// Elimina todos los reportes de un operador que ya han sido sincronizados (synced = 1).
  /// Ayuda a mantener limpia la base de datos local.
  Future<int> deleteSyncedReportesByOperador(int operadorId) async {
    try {
      final db = await database;
      final count = await db.delete(
        'reportes_diarios',
        where: 'operador = ? AND synced = ?',
        whereArgs: [operadorId, 1], // Elimina solo los sincronizados (1) de este operador
      );
      print('🧹 Se eliminaron $count reportes locales ya sincronizados para el operador $operadorId.');
      return count;
    } catch (e) {
      print('❌ Error al limpiar los reportes sincronizados del operador $operadorId: $e');
      return 0;
    }
  }


  /// ==========================================================
  /// ✅ MÉTODO AÑADIDO: OBTENER REPORTES DIARIOS NO SINCRONIZADOS
  /// ==========================================================
  // Future<List<Map<String, dynamic>>> getReportesDiariosNoSincronizados() async {
  //   try {
  //     final db = await database;
  //     // La columna en tu CREATE TABLE se llama 'synced', no 'sincronizado'
  //     final List<Map<String, dynamic>> maps = await db.query(
  //       'reportes_diarios',
  //       where: 'synced = ?', // ✅ CORREGIDO: Usar el nombre de columna correcto
  //       whereArgs: [0],      // 0 para 'false' en SQLite
  //       orderBy: 'id DESC',
  //     );
  //     print('💾 Encontrados ${maps.length} reportes no sincronizados localmente.');
  //     return maps;
  //   } catch (e) {
  //     print('❌ Error al obtener reportes locales no sincronizados: $e');
  //     return [];
  //   }
  // }

  // ========== MÉTODOS PARA UBICACIONES ==========

  Future<void> guardarUbicacionLocal(UbicacionModel ubicacion) async {
    try {
      final db = await database;
      final data = ubicacion.toJson();
      data.remove('id');
      await db.insert('ubicaciones', data);
      print('✅ Ubicación guardada localmente');
    } catch (e) {
      print('❌ ERROR guardando ubicación local: $e');
      rethrow;
    }
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

  Future<void> guardarPuntosEmpadronamiento(List<Map<String, dynamic>> puntos) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('puntos_empadronamiento');
        for (var punto in puntos) {
          await txn.insert('puntos_empadronamiento', punto);
        }
      });
      print('✅ Puntos de empadronamiento guardados: ${puntos.length}');
    } catch (e) {
      print('❌ Error al guardar puntos de empadronamiento: $e');
      rethrow;
    }
  }

  // ========== MÉTODOS DE INSERCIÓN Y ACTUALIZACIÓN CORREGIDOS ==========

  Future<int> insertRegistroDespliegue(RegistroDespliegue registro) async {
    try {
      final db = await database;
      final Map<String, dynamic> datosParaInsertar = {
        'latitud': registro.latitud,
        'longitud': registro.longitud,
        'descripcionReporte': registro.descripcionReporte,
        'estado': registro.estado,
        'sincronizar': registro.sincronizar ? 1 : 0,
        'observaciones': registro.observaciones,
        'incidencias': registro.incidencias,
        'fechaHora': registro.fechaHora,
        'operadorId': registro.operadorId,
        'sincronizado': registro.sincronizado ? 1 : 0,
        'centroEmpadronamiento': registro.centroEmpadronamiento,
        'fechaSincronizacion': registro.fechaSincronizacion,
      };
      final result = await db.insert(
        'registros_despliegue',
        datosParaInsertar,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ Registro insertado con ID: $result');
      return result;
    } catch (e) {
      print('❌ Error al insertar registro: $e');
      return -1;
    }
  }


  Future<int> actualizarRegistroDespliegue(RegistroDespliegue registro) async {
    try {
      final db = await database;
      if (registro.id == null) throw Exception('El registro debe tener un ID para actualizarse');

      final result = await db.update(
        'registros_despliegue',
        registro.toMap(), // ✅ CORREGIDO: Llama al método toMap()
        where: 'id = ?',
        whereArgs: [registro.id],
      );
      print('✅ Registro actualizado: $result filas afectadas');
      return result;
    } catch (e) {
      print('❌ Error al actualizar registro: $e');
      return -1;
    }
  }

  // ========== MÉTODO AUXILIAR ==========

  Map<String, dynamic> _limpiarDatosParaSQLite(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is bool) {
        return MapEntry(key, value ? 1 : 0);
      }
      return MapEntry(key, value);
    });
  }

  //OBTENER REPORTE DEIARIOS NO SINCRONIZADOS DE SQLITE
  Future<List<Map<String, dynamic>>> getReportesDiariosNoSincronizados() async {
    try {
      final db = await database;

      final List<Map<String, dynamic>> maps = await db.query(
        'reportes_diarios',
        where: 'sincronizado = ?',
        whereArgs: [0],
        orderBy: 'id DESC',
      );

      print('Encontrados ${maps.length} reportes no sincronizados localmente.');
      return maps;
    } catch (e) {
      print('❌ Error al obtener reportes locales no sincronizados: $e');
      return [];
    }
  }

  // Pega este bloque de código dentro de tu clase DatabaseService
// en el archivo lib/services/database_service.dart

// ========== MÉTODOS ADICIONALES PARA UBICACIONES ==========

  /// Obtiene una lista de todas las ubicaciones que aún no han sido sincronizadas.
  Future<List<UbicacionModel>> obtenerUbicacionesPendientes() async {
    try {
      final db = await database;
      final result = await db.query(
        'ubicaciones',
        where: 'sincronizado = ?',
        whereArgs: [0], // 0 representa 'false'
        orderBy: 'timestamp ASC', // Ordena para sincronizar las más antiguas primero
      );
      // Mapea el resultado a una lista de modelos UbicacionModel
      return result.map((json) => UbicacionModel.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error al obtener ubicaciones pendientes: $e');
      return []; // Devuelve una lista vacía en caso de error
    }
  }

  /// Actualiza el estado de una ubicación a 'sincronizado' en la base de datos local.
  Future<void> marcarUbicacionSincronizada(int id) async {
    try {
      final db = await database;
      await db.update(
        'ubicaciones',
        {'sincronizado': 1}, // 1 representa 'true'
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Ubicación local con ID $id marcada como sincronizada.');
    } catch (e) {
      print('❌ Error al marcar la ubicación $id como sincronizada: $e');
      rethrow;
    }
  }

  /// Obtiene estadísticas sobre las ubicaciones guardadas en la base de datos local.
  Future<Map<String, dynamic>> obtenerEstadisticasUbicaciones() async {
    try {
      final db = await database;

      // Contar el total de registros
      final totalResult = await db.rawQuery('SELECT COUNT(*) FROM ubicaciones');
      final total = Sqflite.firstIntValue(totalResult) ?? 0;

      // Contar los registros pendientes de sincronizar
      final pendientesResult = await db.rawQuery('SELECT COUNT(*) FROM ubicaciones WHERE sincronizado = 0');
      final pendientes = Sqflite.firstIntValue(pendientesResult) ?? 0;

      // Obtener la fecha del registro pendiente más antiguo
      String masAntigua = 'N/A';
      if (pendientes > 0) {
        final masAntiguaResult = await db.rawQuery('SELECT MIN(timestamp) as ts FROM ubicaciones WHERE sincronizado = 0');
        if (masAntiguaResult.isNotEmpty && masAntiguaResult.first['ts'] != null) {
          masAntigua = masAntiguaResult.first['ts'] as String;
        }
      }

      return {
        'total': total,
        'pendientes': pendientes,
        'mas_antigua': masAntigua,
      };
    } catch (e) {
      print('❌ Error al obtener estadísticas de ubicaciones: $e');
      // Devuelve un mapa con valores por defecto en caso de error
      return {
        'total': 0,
        'pendientes': 0,
        'mas_antigua': 'Error',
      };
    }
  }

}