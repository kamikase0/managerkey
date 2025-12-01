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

    // En el método _createDatabase, actualizar la tabla registros_despliegue:
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
        fechaSincronizacion TEXT,
        idServidor INTEGER,
        fechaCreacionLocal TEXT,
        intentos INTEGER DEFAULT 0,
        ultimoIntento TEXT,
        operador_id INTEGER,
        centro_empadronamiento_id INTEGER
      )
    ''');
    print('✅ Tabla registros_despliegue creada con campos extendidos');

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

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    print('🔄 Migrando BD de versión $oldVersion a $newVersion...');

// En _upgradeDatabase, agregar:
    if (oldVersion < 8) {
      print('🔧 Aplicando migración versión 8: Extender tabla registros_despliegue...');

      try {
        // Verificar columnas existentes
        final columns = await db.rawQuery('PRAGMA table_info(registros_despliegue)');
        final columnNames = columns.map((col) => col['name'] as String).toList();

        print('📋 Columnas actuales en registros_despliegue: $columnNames');

        // Agregar columnas faltantes
        final nuevasColumnas = {
          'idServidor': 'ALTER TABLE registros_despliegue ADD COLUMN idServidor INTEGER',
          'fechaCreacionLocal': 'ALTER TABLE registros_despliegue ADD COLUMN fechaCreacionLocal TEXT',
          'intentos': 'ALTER TABLE registros_despliegue ADD COLUMN intentos INTEGER DEFAULT 0',
          'ultimoIntento': 'ALTER TABLE registros_despliegue ADD COLUMN ultimoIntento TEXT',
          'operador_id': 'ALTER TABLE registros_despliegue ADD COLUMN operador_id INTEGER',
          'centro_empadronamiento_id': 'ALTER TABLE registros_despliegue ADD COLUMN centro_empadronamiento_id INTEGER',
        };

        for (final entry in nuevasColumnas.entries) {
          if (!columnNames.contains(entry.key)) {
            try {
              await db.execute(entry.value);
              print('✅ Columna ${entry.key} agregada a registros_despliegue');
            } catch (e) {
              print('⚠️ Error agregando columna ${entry.key}: $e');
            }
          } else {
            print('✅ Columna ${entry.key} ya existe');
          }
        }

        print('🎯 Estructura final de registros_despliegue actualizada');
      } catch (e) {
        print('❌ Error en migración versión 8: $e');
      }
    }

    // Migraciones anteriores (mantener para compatibilidad)
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

    print('✅ Migración finalizada');
  }

  // ✅ NUEVO: Método para recrear tabla reportes_diarios si hay errores críticos
  Future<void> _recrearTablaReportesDiarios(Database db) async {
    try {
      print('🔄 Recreando tabla reportes_diarios...');

      // 1. Crear tabla temporal
      await db.execute('''
        CREATE TABLE reportes_diarios_temp (
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

      // 2. Copiar datos existentes si los hay
      try {
        final datosExistentes = await db.rawQuery('''
          SELECT * FROM reportes_diarios
        ''');

        if (datosExistentes.isNotEmpty) {
          for (final dato in datosExistentes) {
            await db.insert('reportes_diarios_temp', dato);
          }
          print('✅ ${datosExistentes.length} registros migrados');
        }
      } catch (e) {
        print('⚠️  No se pudieron migrar datos existentes: $e');
      }

      // 3. Eliminar tabla original
      await db.execute('DROP TABLE reportes_diarios');

      // 4. Renombrar tabla temporal
      await db.execute(
        'ALTER TABLE reportes_diarios_temp RENAME TO reportes_diarios',
      );

      print('✅ Tabla reportes_diarios recreada exitosamente');
    } catch (e) {
      print('❌ Error crítico recreando tabla: $e');
      rethrow;
    }
  }

  // ✅ NUEVO: Método para resetear base de datos (solo desarrollo)
  Future<void> resetDatabase() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'app_database.db');
      await deleteDatabase(path);

      print('🗑️ Base de datos reseteada exitosamente');
    } catch (e) {
      print('❌ Error reseteando base de datos: $e');
    }
  }

  // ✅ NUEVO: Método para verificar estructura de tablas
  Future<void> verificarEstructura() async {
    try {
      final db = await database;

      print('🔍 Verificando estructura de la base de datos...');

      // Verificar reportes_diarios
      final columnasReportes = await db.rawQuery(
        'PRAGMA table_info(reportes_diarios)',
      );
      final nombresReportes = columnasReportes
          .map((col) => col['name'] as String)
          .toList();
      print('📋 Estructura de reportes_diarios: $nombresReportes');

      // Verificar columnas requeridas
      final columnasRequeridas = [
        'observacionC',
        'observacionR',
        'saltosenC',
        'saltosenR',
        'centro_empadronamiento',
      ];

      for (final columna in columnasRequeridas) {
        if (!nombresReportes.contains(columna)) {
          print('❌ COLUMNA FALTANTE: $columna');
        } else {
          print('✅ Columna presente: $columna');
        }
      }
    } catch (e) {
      print('❌ Error verificando estructura: $e');
    }
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
      return result.isNotEmpty
          ? RegistroDespliegue.fromMap(result.first)
          : null;
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

  Future<List<RegistroDespliegue>>
  obtenerRegistrosDespliegueNoSincronizados() async {
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
        whereArgs: [
          operadorId,
          1,
        ], // Elimina solo los sincronizados (1) de este operador
      );
      print(
        '🧹 Se eliminaron $count reportes locales ya sincronizados para el operador $operadorId.',
      );
      return count;
    } catch (e) {
      print(
        '❌ Error al limpiar los reportes sincronizados del operador $operadorId: $e',
      );
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

  Future<void> guardarPuntosEmpadronamiento(
    List<Map<String, dynamic>> puntos,
  ) async {
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
      if (registro.id == null)
        throw Exception('El registro debe tener un ID para actualizarse');

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
        orderBy:
            'timestamp ASC', // Ordena para sincronizar las más antiguas primero
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
      final pendientesResult = await db.rawQuery(
        'SELECT COUNT(*) FROM ubicaciones WHERE sincronizado = 0',
      );
      final pendientes = Sqflite.firstIntValue(pendientesResult) ?? 0;

      // Obtener la fecha del registro pendiente más antiguo
      String masAntigua = 'N/A';
      if (pendientes > 0) {
        final masAntiguaResult = await db.rawQuery(
          'SELECT MIN(timestamp) as ts FROM ubicaciones WHERE sincronizado = 0',
        );
        if (masAntiguaResult.isNotEmpty &&
            masAntiguaResult.first['ts'] != null) {
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
      return {'total': 0, 'pendientes': 0, 'mas_antigua': 'Error'};
    }
  }

  // ========== MÉTODOS PARA REGISTROS DE DESPLIEGUE (OFFLINE) ==========

  /// ✅ Insertar registro de despliegue offline
  Future<int> insertRegistroDespliegueOffline(Map<String, dynamic> datos) async {
    try {
      final db = await database;

      // Mapear datos snake_case a camelCase para la tabla existente
      final datosParaInsertar = {
        'latitud': datos['latitud']?.toString() ?? '0',
        'longitud': datos['longitud']?.toString() ?? '0',
        'descripcionReporte': datos['descripcion_reporte'],
        'estado': datos['estado'] ?? 'DESPLIEGUE',
        'sincronizar': (datos['sincronizar'] ?? true) ? 1 : 0,
        'observaciones': datos['observaciones'] ?? '',
        'incidencias': datos['incidencias'] ?? 'Ubicación capturada',
        'fechaHora': datos['fecha_hora'] ?? DateTime.now().toIso8601String(),
        'operadorId': datos['operador_id'] ?? datos['operador'],
        'sincronizado': 0,
        'centroEmpadronamiento': datos['centro_empadronamiento_id'] ?? datos['centro_empadronamiento'],
        'fechaSincronizacion': null,
        'idServidor': null,
        'fechaCreacionLocal': DateTime.now().toIso8601String(),
        'intentos': 0,
        'ultimoIntento': null,
        // Campos de compatibilidad
        'operador_id': datos['operador_id'] ?? datos['operador'],
        'centro_empadronamiento_id': datos['centro_empadronamiento_id'] ?? datos['centro_empadronamiento'],
      };

      // Eliminar valores nulos
      datosParaInsertar.removeWhere((key, value) => value == null);

      final id = await db.insert(
        'registros_despliegue',
        datosParaInsertar,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ Registro guardado en registros_despliegue (offline) con ID: $id');
      return id;
    } catch (e) {
      print('❌ Error insertando registro offline: $e');
      return -1;
    }
  }

  /// ✅ Obtener registros pendientes de sincronización
  Future<List<Map<String, dynamic>>> obtenerRegistrosDesplieguePendientes() async {
    try {
      final db = await database;
      return await db.query(
        'registros_despliegue',
        where: 'sincronizado = ?',
        whereArgs: [0],
        orderBy: 'fechaCreacionLocal ASC',
      );
    } catch (e) {
      print('❌ Error obteniendo registros pendientes: $e');
      return [];
    }
  }

  /// ✅ Actualizar registro como sincronizado
  Future<void> marcarRegistroDespliegueSincronizado(int idLocal, int idServidor) async {
    try {
      final db = await database;
      await db.update(
        'registros_despliegue',
        {
          'sincronizado': 1,
          'idServidor': idServidor,
          'fechaSincronizacion': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [idLocal],
      );
      print('✅ Registro $idLocal marcado como sincronizado');
    } catch (e) {
      print('❌ Error marcando registro como sincronizado: $e');
    }
  }

  /// ✅ Incrementar intentos de un registro
  Future<void> incrementarIntentosRegistro(int idLocal) async {
    try {
      final db = await database;
      await db.rawUpdate(
        '''
      UPDATE registros_despliegue 
      SET intentos = intentos + 1, 
          ultimoIntento = ?
      WHERE id = ?
      ''',
        [DateTime.now().toIso8601String(), idLocal],
      );
      print('⚠️ Intentos incrementados para registro $idLocal');
    } catch (e) {
      print('❌ Error incrementando intentos: $e');
    }
  }

  /// ✅ Obtener estadísticas de sincronización
  Future<Map<String, dynamic>> obtenerEstadisticasDespliegueOffline() async {
    try {
      final db = await database;

      // Total registros offline (no sincronizados)
      final totalResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM registros_despliegue WHERE sincronizado = 0'
      );
      final totalPendientes = (totalResult.first['count'] as int?) ?? 0;

      // Total de todos los registros
      final totalTodosResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM registros_despliegue'
      );
      final totalTodos = (totalTodosResult.first['count'] as int?) ?? 0;

      // Registros sincronizados
      final sincronizadosResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM registros_despliegue WHERE sincronizado = 1'
      );
      final sincronizados = (sincronizadosResult.first['count'] as int?) ?? 0;

      // Registros con más de 3 intentos fallidos
      final fallidosResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM registros_despliegue WHERE sincronizado = 0 AND intentos >= 3'
      );
      final fallidos = (fallidosResult.first['count'] as int?) ?? 0;

      return {
        'total': totalTodos,
        'sincronizados': sincronizados,
        'pendientes': totalPendientes,
        'fallidos': fallidos,
        'porcentaje': totalTodos > 0 ? ((sincronizados / totalTodos) * 100).round() : 0,
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

  /// ✅ Obtener todos los registros de un operador (para debug)
  Future<List<Map<String, dynamic>>> obtenerRegistrosCompletos() async {
    try {
      final db = await database;
      return await db.query(
        'registros_despliegue',
        orderBy: 'fechaHora DESC',
      );
    } catch (e) {
      print('❌ Error obteniendo registros completos: $e');
      return [];
    }
  }
}
