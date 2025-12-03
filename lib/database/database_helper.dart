import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('manager_key.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    print('📁 Inicializando base de datos en: $path');

    return await openDatabase(
      path,
      version: 4, // Incrementa a 4 para forzar creación
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    print('🆕 Creando tablas desde cero (versión $version)...');
    await _crearTodasLasTablas(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    print('🔄 Actualizando BD de $oldVersion a $newVersion');

    if (oldVersion < 4) {
      // Si viene de versión anterior, crear todas las tablas
      await _crearTodasLasTablas(db);
    }
  }

  Future<void> _crearTodasLasTablas(Database db) async {
    await _crearTablaRegistrosDespliegue(db);
    // Agrega otras tablas si las necesitas
  }

  Future<void> _crearTablaRegistrosDespliegue(Database db) async {
    print('📊 Creando/Verificando tabla registros_despliegue...');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS registros_despliegue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operadorId INTEGER NOT NULL,
        estado TEXT NOT NULL,
        fecha_hora TEXT NOT NULL,
        latitud TEXT,
        longitud TEXT,
        observaciones TEXT,
        centroEmpadronamiento INTEGER,
        sincronizar INTEGER DEFAULT 1,
        sincronizado INTEGER DEFAULT 0,
        fecha_sincronizacion TEXT,
        descripcion_reporte TEXT,
        incidencias TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    print('✅ Tabla registros_despliegue creada/verificada');
  }

  // Método para verificar todas las tablas
  Future<void> verificarTodasLasTablas() async {
    try {
      final db = await database;

      // Obtener todas las tablas
      final tablas = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
      );

      print('📋 LISTA COMPLETA DE TABLAS EN LA BD:');
      if (tablas.isEmpty) {
        print('   ⚠️ No hay tablas en la base de datos');
      } else {
        for (var tabla in tablas) {
          final nombreTabla = tabla['name'] as String;
          print('   - $nombreTabla');

          // Mostrar estructura de cada tabla
          if (nombreTabla != 'sqlite_sequence') {
            final estructura = await db.rawQuery(
                'PRAGMA table_info($nombreTabla)'
            );

            print('     Columnas:');
            for (var col in estructura) {
              final nombre = col['name'];
              final tipo = col['type'];
              final notnull = col['notnull'] == 1 ? 'NOT NULL' : 'NULL';
              print('       $nombre $tipo $notnull');
            }
          }
        }
      }

    } catch (e) {
      print('❌ Error verificando tablas: $e');
    }
  }

  // Método para forzar recreación de tablas
  Future<void> recrearTablas() async {
    try {
      final db = await database;
      print('🔄 Forzando recreación de tablas...');

      // Eliminar tablas si existen
      await db.execute('DROP TABLE IF EXISTS registros_despliegue');

      // Crear tablas nuevamente
      await _crearTablaRegistrosDespliegue(db);

      print('✅ Tablas recreadas exitosamente');
    } catch (e) {
      print('❌ Error recreando tablas: $e');
    }
  }
}