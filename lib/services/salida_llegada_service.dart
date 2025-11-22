// lib/services/salida_llegada_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:manager_key/config/enviroment.dart';
import 'package:sqflite/sqflite.dart';
import '../models/registro_despliegue_model.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'location_service.dart';
import 'sync_service.dart';
import 'auth_service.dart';

/// Servicio integrado para manejar Salida y Llegada con sincronización inteligente
class SalidaLlegadaService {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final SyncService _syncService = SyncService();

  /// CASO 1 & 2: Registrar SALIDA
  /// - Con Internet: Envía al servidor inmediatamente
  /// - Sin Internet: Guarda localmente como DESPLIEGUE con estado pendiente
  Future<Map<String, dynamic>> registrarSalida({
    required String destino,
    required String observaciones,
    required int idOperador,
    bool sincronizarConServidor = true,
    required int centroEmpadronamiento,
  }) async {
    try {
      // Obtener ubicación
      final location = await LocationService().getCurrentLocation();
      if (location == null) {
        return {
          'exitoso': false,
          'mensaje': 'No se pudo obtener la ubicación',
          'localId': null,
        };
      }

      final ahora = DateTime.now();

      // Crear registro de salida (DESPLIEGUE)
      final registroSalida = RegistroDespliegue(
        latitud: location.latitude.toString(),
        longitud: location.longitude.toString(),
        descripcionReporte: null,
        estado: "DESPLIEGUE",
        sincronizar: sincronizarConServidor,
        observaciones: observaciones,
        incidencias: "",
        fechaHora: ahora.toIso8601String(),
        operadorId: idOperador,
        sincronizado: false,
        centroEmpadronamiento: centroEmpadronamiento,
      );

      // Guardar localmente primero
      final localId = await _databaseService.insertRegistroDespliegue(
        registroSalida,
      );
      print('✅ Salida guardada localmente con ID: $localId');

      // Verificar conectividad
      final tieneInternet = await _syncService.verificarConexion();

      if (tieneInternet && sincronizarConServidor) {
        // CASO 1: Enviar inmediatamente al servidor
        final resultado = await _enviarRegistroAlServidor(registroSalida);

        if (resultado) {
          // Eliminar del local si se envió exitosamente
          await _databaseService.eliminarRegistroDespliegue(localId);
          print('✅ Salida enviada al servidor y eliminada localmente');
          return {
            'exitoso': true,
            'mensaje': '✅ Salida registrada y enviada al servidor',
            'localId': null,
            'enviado': true,
          };
        } else {
          print('⚠️ Fallo al enviar, guardado localmente');
          return {
            'exitoso': true,
            'mensaje':
                '⚠️ Salida guardada localmente. Se sincronizará cuando haya conexión',
            'localId': localId,
            'enviado': false,
          };
        }
      } else {
        // CASO 2: Sin internet, guardado solo localmente
        print('📡 Sin conexión. Salida guardada localmente');
        return {
          'exitoso': true,
          'mensaje':
              '💾 Salida guardada localmente. Se sincronizará cuando haya conexión',
          'localId': localId,
          'enviado': false,
        };
      }
    } catch (e) {
      print('❌ Error al registrar salida: $e');
      return {
        'exitoso': false,
        'mensaje': 'Error al registrar salida: $e',
        'localId': null,
      };
    }
  }

  /// NUEVO MÉTODO: Registrar salida con empadronamiento
  // En SalidaLlegadaService - versión con parámetro opcional
  // En SalidaLlegadaService - VERSIÓN CORRECTA (Opción 1)
  Future<Map<String, dynamic>> registrarSalidaConEmpadronamiento({
    //required String destino,
    required String observaciones,
    required int idOperador,
    required bool sincronizarConServidor,
    required int puntoEmpadronamientoId,
    String? latitud,
    String? longitud,
    // ❌ NO incluir datosDespliegue aquí
  }) async {
    try {
      // ✅ Asegurar que la tabla esté migrada antes de cualquier operación
      await migrateRegistrosDespliegueTable();

      final datos = {
        "latitud": latitud ?? '-16.3453',
        "longitud": longitud ?? '-22.890',
        "descripcion_reporte": null,
        "estado": "DESPLIEGUE",
        "sincronizar": true,
        "observaciones": observaciones.isNotEmpty ? observaciones : "FFF",
        "incidencias": latitud != null
            ? 'Ubicación capturada'
            : 'GPS desactivado',
        "fecha_hora": DateTime.now().toIso8601String(),
        "operador": idOperador,
        "centro_empadronamiento": puntoEmpadronamientoId,
      };

      print('🚀 Intentando registrar salida con empadronamiento...');

      if (sincronizarConServidor) {
        return await _enviarDespliegueDirecto(datos);
      } else {
        return await _guardarSalidaLocalmente(datos);
      }
    } catch (e) {
      return {
        'exitoso': false,
        'mensaje': 'Error: ${e.toString()}',
        'localId': null,
      };
    }
  }

  /// CASO 1, 2, 3, 4: Registrar LLEGADA
  /// Inteligentemente sincroniza la salida correspondiente si es necesario
  Future<Map<String, dynamic>> registrarLlegada({
    required int idOperador,
    required String observaciones,
    required int? salidaLocalId, // ID local de la salida correspondiente
    bool sincronizarConServidor = true,
  }) async {
    try {
      // Obtener la salida correspondiente
      RegistroDespliegue? salidaRegistro;

      if (salidaLocalId != null) {
        salidaRegistro = await _databaseService.obtenerRegistroPorId(
          salidaLocalId,
        );
      } else {
        // Buscar la salida más reciente sin sincronizar
        salidaRegistro = await _obtenerSalidaActivaDelOperador(idOperador);
      }

      if (salidaRegistro == null) {
        return {
          'exitoso': false,
          'mensaje': 'No hay registro de salida activo para esta llegada',
          'localId': null,
        };
      }

      // Obtener ubicación de llegada
      final location = await LocationService().getCurrentLocation();
      if (location == null) {
        return {
          'exitoso': false,
          'mensaje': 'No se pudo obtener la ubicación de llegada',
          'localId': null,
        };
      }

      final ahora = DateTime.now();

      // Crear registro de llegada
      final registroLlegada = RegistroDespliegue(
        // Mismo destino de la salida
        latitud: location.latitude.toString(),
        longitud: location.longitude.toString(),
        descripcionReporte: salidaRegistro.descripcionReporte,
        estado: "LLEGADA",
        sincronizar: sincronizarConServidor,
        observaciones: observaciones.isNotEmpty
            ? observaciones
            : salidaRegistro.observaciones,
        incidencias: salidaRegistro.incidencias,
        fechaHora: ahora.toIso8601String(),
        operadorId: idOperador,
        sincronizado: false,
        centroEmpadronamiento: salidaRegistro.centroEmpadronamiento,
      );

      // Guardar llegada localmente
      final llegadaLocalId = await _databaseService.insertRegistroDespliegue(
        registroLlegada,
      );
      print('✅ Llegada guardada localmente con ID: $llegadaLocalId');

      // Verificar conectividad
      final tieneInternet = await _syncService.verificarConexion();

      if (tieneInternet && sincronizarConServidor) {
        // CASO 1 & 3: Intentar sincronizar
        return await _sincronizarSalidaYLlegada(
          salidaRegistro: salidaRegistro,
          llegadaRegistro: registroLlegada,
          salidaLocalId: salidaLocalId,
          llegadaLocalId: llegadaLocalId,
        );
      } else {
        // CASO 2 & 4: Sin internet, ambas guardadas localmente
        print('📡 Sin conexión. Llegada guardada localmente junto a la salida');
        return {
          'exitoso': true,
          'mensaje':
              '💾 Llegada guardada localmente. Se sincronizará con la salida cuando haya conexión',
          'localId': llegadaLocalId,
          'enviado': false,
          'salidaLocalId': salidaLocalId,
        };
      }
    } catch (e) {
      print('❌ Error al registrar llegada: $e');
      return {
        'exitoso': false,
        'mensaje': 'Error al registrar llegada: $e',
        'localId': null,
      };
    }
  }

  /// Sincroniza salida y llegada inteligentemente
  /// Evita duplicados y maneja los 4 casos
  Future<Map<String, dynamic>> _sincronizarSalidaYLlegada({
    required RegistroDespliegue salidaRegistro,
    required RegistroDespliegue llegadaRegistro,
    required int? salidaLocalId,
    required int llegadaLocalId,
  }) async {
    try {
      final accessToken = await _authService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('No se pudo obtener token de autenticación');
      }

      final apiService = ApiService(accessToken: accessToken);
      bool salidaEnviada = false;
      bool llegadaEnviada = false;

      // PASO 1: Enviar SALIDA si no está sincronizada
      if (salidaLocalId != null && !salidaRegistro.sincronizado) {
        print('📤 Enviando salida...');
        salidaEnviada = await _enviarRegistroAlServidor(salidaRegistro);

        if (salidaEnviada) {
          await _databaseService.eliminarRegistroDespliegue(salidaLocalId);
          print('✅ Salida enviada y eliminada localmente');
        } else {
          print('⚠️ Fallo envío de salida');
        }
      }

      // PASO 2: Enviar LLEGADA
      print('📤 Enviando llegada...');
      llegadaEnviada = await _enviarRegistroAlServidor(llegadaRegistro);

      if (llegadaEnviada) {
        await _databaseService.eliminarRegistroDespliegue(llegadaLocalId);
        print('✅ Llegada enviada y eliminada localmente');
      }

      // PASO 3: Retornar resultado combinado
      if (salidaEnviada && llegadaEnviada) {
        return {
          'exitoso': true,
          'mensaje':
              '✅ Salida y Llegada registradas y sincronizadas correctamente',
          'localId': null,
          'enviado': true,
          'salidaEnviada': true,
          'llegadaEnviada': true,
        };
      } else if (llegadaEnviada) {
        return {
          'exitoso': true,
          'mensaje': '⚠️ Llegada enviada. Salida se sincronizará después',
          'localId': llegadaLocalId > 0 ? null : llegadaLocalId,
          'enviado': true,
          'salidaEnviada': salidaEnviada,
          'llegadaEnviada': true,
        };
      } else {
        return {
          'exitoso': true,
          'mensaje':
              '⚠️ Registros guardados localmente. Se sincronizarán cuando haya conexión',
          'localId': llegadaLocalId,
          'enviado': false,
          'salidaEnviada': salidaEnviada,
          'llegadaEnviada': false,
        };
      }
    } catch (e) {
      print('❌ Error en sincronización: $e');
      return {
        'exitoso': true,
        'mensaje':
            '💾 Registros guardados localmente. Se sincronizarán después: $e',
        'localId': llegadaLocalId,
        'enviado': false,
      };
    }
  }

  /// Obtener salida activa del operador desde el servidor o local
  Future<RegistroDespliegue?> _obtenerSalidaActivaDelOperador(
    int idOperador,
  ) async {
    try {
      final tieneInternet = await _syncService.verificarConexion();

      // PRIMERO: Intentar obtener del servidor si hay internet
      if (tieneInternet) {
        print('🔄 Obteniendo salidas del servidor...');
        final salidas = await _obtenerSalidasDelServidor(idOperador);

        if (salidas.isNotEmpty) {
          // Filtrar por estado DESPLIEGUE y más reciente
          final salidaActiva =
              salidas.where((r) => r['estado'] == 'DESPLIEGUE').toList()
                ..sort((a, b) {
                  final fechaA = DateTime.parse(
                    a['fecha_hora'] ?? DateTime.now().toIso8601String(),
                  );
                  final fechaB = DateTime.parse(
                    b['fecha_hora'] ?? DateTime.now().toIso8601String(),
                  );
                  return fechaB.compareTo(fechaA);
                });

          if (salidaActiva.isNotEmpty) {
            print('✅ Salida encontrada en servidor');
            return _convertirMapARegistro(salidaActiva.first);
          }
        }
      }

      // FALLBACK: Obtener del local si no hay internet o no hay en servidor
      print('💾 Obteniendo salidas locales...');
      final registrosLocales = await _databaseService.obtenerTodosRegistros();
      final salidaLocal =
          registrosLocales
              .where(
                (r) => r.operadorId == idOperador && r.estado == 'DESPLIEGUE',
              )
              .toList()
            ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

      if (salidaLocal.isNotEmpty) {
        print('✅ Salida encontrada en local');
        return salidaLocal.first;
      }

      print('⚠️ No hay salida activa');
      return null;
    } catch (e) {
      print('❌ Error obtener salida activa: $e');
      return null;
    }
  }

  /// Obtener todas las salidas del servidor para un operador
  Future<List<Map<String, dynamic>>> _obtenerSalidasDelServidor(
    int idOperador,
  ) async {
    try {
      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) throw Exception('Sin token de autenticación');

      final apiService = ApiService(accessToken: accessToken);

      print('📡 Obtener salidas del operador $idOperador del servidor...');

      try {
        // Usar el método del ApiService para obtener registros del operador
        final respuesta = await apiService
            .obtenerRegistrosDespliegueDelOperador(idOperador);

        if (respuesta.isNotEmpty) {
          print('✅ ${respuesta.length} salidas encontradas en servidor');
          // Filtrar solo registros con estado DESPLIEGUE
          final salidas = respuesta
              .where((r) => r['estado'] == 'DESPLIEGUE')
              .toList();

          if (salidas.isNotEmpty) {
            print(
              '✅ ${salidas.length} salidas activas (DESPLIEGUE) encontradas',
            );
            return salidas;
          } else {
            print('⚠️ No hay salidas activas para este operador');
            return [];
          }
        } else {
          print('⚠️ No hay salidas para este operador en el servidor');
          return [];
        }
      } catch (e) {
        print('⚠️ Error al obtener registros del servidor: $e');
        return [];
      }
    } catch (e) {
      print('❌ Error al obtener salidas del servidor: $e');
      return [];
    }
  }

  /// Enviar registro al servidor
  Future<bool> _enviarRegistroAlServidor(RegistroDespliegue registro) async {
    try {
      final accessToken = await _authService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Sin token');
      }

      final apiService = ApiService(accessToken: accessToken);
      final registroMap = registro.toApiMap();

      print('📤 Enviando ${registro.estado} al servidor...');
      final resultado = await apiService.enviarRegistroDespliegue(registroMap);

      return resultado;
    } catch (e) {
      print('❌ Error al enviar registro: $e');
      return false;
    }
  }

  /// Convertir Map del servidor a RegistroDespliegue
  RegistroDespliegue _convertirMapARegistro(Map<String, dynamic> data) {
    return RegistroDespliegue(
      id: data['id'],
      centroEmpadronamiento: data['centroEmpadronamiento'],
      latitud: data['latitud'].toString(),
      longitud: data['longitud'].toString(),
      descripcionReporte: data['descripcion_reporte'],
      estado: data['estado'],
      sincronizar: data['sincronizar'] ?? true,
      observaciones: data['observaciones'],
      incidencias: data['incidencias'],
      fechaHora: data['fecha_hora'],
      operadorId: data['operador'],
      sincronizado: true,
    );
  }

  /// Sincronizar registros pendientes (para ejecutar periódicamente)
  Future<void> sincronizarPendientes(int idOperador) async {
    try {
      final tieneInternet = await _syncService.verificarConexion();
      if (!tieneInternet) {
        print('📡 Sin internet. Sincronización pospuesta');
        return;
      }

      final pendientes = await _databaseService.obtenerNoSincronizados();
      final delOperador = pendientes
          .where((r) => r.operadorId == idOperador)
          .toList();

      print('🔄 Sincronizando ${delOperador.length} registros pendientes...');

      for (var registro in delOperador) {
        final enviado = await _enviarRegistroAlServidor(registro);
        if (enviado && registro.id != null) {
          await _databaseService.eliminarRegistroDespliegue(registro.id!);
          print('✅ Registro ${registro.id} sincronizado y eliminado');
        }
      }
    } catch (e) {
      print('❌ Error en sincronización de pendientes: $e');
    }
  }

  // ========== MÉTODOS NUEVOS PARA EMPADRONAMIENTO ==========

  /// Enviar despliegue directo al servidor
  Future<Map<String, dynamic>> _enviarDespliegueDirecto(
    Map<String, dynamic> datos,
  ) async {
    try {
      final authService = AuthService();
      final token = await authService.getAccessToken();

      if (token == null) {
        throw Exception('No hay token de autenticación disponible');
      }

      // ✅ CORREGIDO: Usar el endpoint correcto de registrosdespliegue
      final url = '${Enviroment.apiUrlDev}/registrosdespliegue/';

      print('📤 Enviando a: $url');
      print('📦 Datos: $datos');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(datos),
          )
          .timeout(const Duration(seconds: 20));

      print('📥 Respuesta - Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Éxito - Despliegue registrado en servidor');
        return {
          'exitoso': true,
          'mensaje': 'Salida registrada exitosamente en servidor',
          'localId': null,
        };
      } else {
        // Si falla, guardar localmente
        final errorBody = utf8.decode(response.bodyBytes);
        print('⚠️ Error del servidor: ${response.statusCode}');
        print('📄 Response body: $errorBody');
        print('💾 Guardando localmente como fallback...');
        return await _guardarSalidaLocalmente(datos);
      }
    } catch (e) {
      print('❌ Error de conexión: $e');
      // Fallback a guardado local
      return await _guardarSalidaLocalmente(datos);
    }
  }

  /// Guardar salida localmente con empadronamiento
  Future<Map<String, dynamic>> _guardarSalidaLocalmente(
    Map<String, dynamic> datos,
  ) async {
    try {
      final db = await DatabaseService().database;
      final ahora = DateTime.now();

      // ✅ VERIFICAR QUE LA TABLA EXISTE ANTES DE INSERTAR
      await _ensureRegistrosDespliegueTableExists(db);

      final id = await db.insert('registros_despliegue', {
        'destino': datos['observaciones'] ?? 'Despliegue',
        'latitud': datos['latitud'],
        'longitud': datos['longitud'],
        'observaciones': datos['observaciones'],
        'incidencias': datos['incidencias'],
        'fecha_hora': datos['fecha_hora'],
        'operador': datos['operador'],
        // ✅ CORREGIDO: usar 'operador' no 'operador_id'
        'centro_empadronamiento': datos['centro_empadronamiento'],
        'estado': 'PENDIENTE_SINCRONIZACION',
        'sincronizado': 0,
        'fecha_creacion': ahora.toIso8601String(),
        'fecha_modificacion': ahora.toIso8601String(),
      });

      print('💾 Salida guardada localmente con ID: $id');

      return {
        'exitoso': true,
        'mensaje':
            'Salida guardada localmente. Se sincronizará cuando haya internet.',
        'localId': id,
      };
    } catch (e) {
      print('❌ Error guardando localmente: $e');
      return {
        'exitoso': false,
        'mensaje': 'Error guardando localmente: ${e.toString()}',
        'localId': null,
      };
    }
  }

  /// Asegurar que la tabla existe
  Future<void> _ensureRegistrosDespliegueTableExists(Database db) async {
    try {
      // Verificar si la tabla existe
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='registros_despliegue'",
      );

      if (result.isEmpty) {
        // Crear la tabla si no existe
        await db.execute('''
        CREATE TABLE registros_despliegue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          destino TEXT,
          latitud TEXT,
          longitud TEXT,
          observaciones TEXT,
          incidencias TEXT,
          fecha_hora TEXT,
          operador INTEGER,
          centro_empadronamiento INTEGER,
          estado TEXT,
          sincronizado INTEGER DEFAULT 0,
          fecha_creacion TEXT,
          fecha_modificacion TEXT
        )
      ''');
        print('✅ Tabla registros_despliegue creada exitosamente');
      }
    } catch (e) {
      print('❌ Error verificando/creando tabla: $e');
      rethrow;
    }
  }

  /// Migrar la tabla si ya existe con estructura incorrecta
  // ✅ CORREGIDO: Método de migración mejorado
  Future<void> migrateRegistrosDespliegueTable() async {
    try {
      final db = await DatabaseService().database;

      // 1. Verificar si la tabla existe y su estructura
      final tableExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='registros_despliegue'"
      );

      if (tableExists.isNotEmpty) {
        // Verificar las columnas existentes
        final columns = await db.rawQuery("PRAGMA table_info(registros_despliegue)");
        final columnNames = columns.map((col) => col['name'] as String).toList();

        print('📊 Columnas existentes: $columnNames');

        // Verificar si falta alguna columna necesaria
        final columnasNecesarias = [
          'centro_empadronamiento', 'operador', 'fecha_creacion', 'fecha_modificacion'
        ];

        final columnasFaltantes = columnasNecesarias.where(
                (col) => !columnNames.contains(col)
        ).toList();

        if (columnasFaltantes.isNotEmpty) {
          print('⚠️ Faltan columnas: $columnasFaltantes. Actualizando tabla...');

          // Crear tabla temporal con estructura completa
          await db.execute('''
          CREATE TABLE IF NOT EXISTS registros_despliegue_temp (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            destino TEXT,
            latitud TEXT,
            longitud TEXT,
            observaciones TEXT,
            incidencias TEXT,
            fecha_hora TEXT,
            operador INTEGER,
            centro_empadronamiento INTEGER,
            estado TEXT,
            sincronizado INTEGER DEFAULT 0,
            fecha_creacion TEXT,
            fecha_modificacion TEXT
          )
        ''');

          // Copiar datos existentes (solo las columnas que existen)
          final columnasExistentesParaCopiar = columnNames.where(
                  (col) => col != 'id'
          ).join(', ');

          final columnasDestino = [
            'destino', 'latitud', 'longitud', 'observaciones', 'incidencias',
            'fecha_hora', 'operador', 'centro_empadronamiento', 'estado',
            'sincronizado', 'fecha_creacion', 'fecha_modificacion'
          ].where((col) => columnNames.contains(col) ||
              col == 'operador' ||
              col == 'centro_empadronamiento' ||
              col == 'fecha_creacion' ||
              col == 'fecha_modificacion').join(', ');

          // Manejar mapeo de columnas viejas a nuevas
          String operadorColumn = 'operador_id';
          if (!columnNames.contains('operador_id')) {
            operadorColumn = columnNames.contains('operador') ? 'operador' : '0';
          }

          await db.execute('''
          INSERT INTO registros_despliegue_temp ($columnasDestino)
          SELECT 
            destino, latitud, longitud, observaciones, incidencias,
            fecha_hora, $operadorColumn as operador, 
            ${columnNames.contains('centro_empadronamiento') ? 'centro_empadronamiento' : 'NULL'} as centro_empadronamiento,
            estado, sincronizado,
            ${columnNames.contains('fecha_creacion') ? 'fecha_creacion' : 'datetime("now")'} as fecha_creacion,
            ${columnNames.contains('fecha_modificacion') ? 'fecha_modificacion' : 'datetime("now")'} as fecha_modificacion
          FROM registros_despliegue
        ''');

          // Eliminar tabla original y renombrar temporal
          await db.execute('DROP TABLE registros_despliegue');
          await db.execute('ALTER TABLE registros_despliegue_temp RENAME TO registros_despliegue');

          print('✅ Migración completada exitosamente');
        } else {
          print('✅ La tabla ya tiene la estructura correcta');
        }
      } else {
        // Crear tabla nueva si no existe
        await db.execute('''
        CREATE TABLE registros_despliegue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          destino TEXT,
          latitud TEXT,
          longitud TEXT,
          observaciones TEXT,
          incidencias TEXT,
          fecha_hora TEXT,
          operador INTEGER,
          centro_empadronamiento INTEGER,
          estado TEXT,
          sincronizado INTEGER DEFAULT 0,
          fecha_creacion TEXT,
          fecha_modificacion TEXT
        )
      ''');
        print('✅ Tabla registros_despliegue creada exitosamente');
      }
    } catch (e) {
      print('❌ Error en migración: $e');
      // En caso de error, intentar crear la tabla desde cero
      try {
        final db = await DatabaseService().database;
        await db.execute('DROP TABLE IF EXISTS registros_despliegue');
        await db.execute('''
        CREATE TABLE registros_despliegue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          destino TEXT,
          latitud TEXT,
          longitud TEXT,
          observaciones TEXT,
          incidencias TEXT,
          fecha_hora TEXT,
          operador INTEGER,
          centro_empadronamiento INTEGER,
          estado TEXT,
          sincronizado INTEGER DEFAULT 0,
          fecha_creacion TEXT,
          fecha_modificacion TEXT
        )
      ''');
        print('✅ Tabla recreada desde cero exitosamente');
      } catch (e2) {
        print('❌ Error crítico recreando tabla: $e2');
      }
    }
  }

  /// Sincronizar registros pendientes con empadronamiento
  Future<void> sincronizarRegistrosPendientesConEmpadronamiento() async {
    try {
      final db = await DatabaseService().database;
      final registrosPendientes = await db.query(
        'registros_despliegue',
        where: 'sincronizado = ? AND estado = ?',
        whereArgs: [0, 'PENDIENTE_SINCRONIZACION'],
      );

      print(
        '🔄 Sincronizando ${registrosPendientes.length} registros pendientes...',
      );

      for (final registro in registrosPendientes) {
        try {
          final datos = {
            "latitud": registro['latitud'],
            "longitud": registro['longitud'],
            "descripcion_reporte": null,
            "estado": "DESPLIEGUE",
            "sincronizar": true,
            "observaciones": registro['observaciones'],
            "incidencias": registro['incidencias'],
            "fecha_hora": registro['fecha_hora'],
            "operador": registro['operador'],
            "centro_empadronamiento": registro['centro_empadronamiento'],
          };

          final resultado = await _enviarDespliegueDirecto(datos);

          if (resultado['exitoso'] == true) {
            // Marcar como sincronizado
            await db.update(
              'registros_despliegue',
              {'sincronizado': 1, 'estado': 'DESPLIEGUE'},
              where: 'id = ?',
              whereArgs: [registro['id']],
            );
            print('✅ Registro ${registro['id']} sincronizado exitosamente');
          }
        } catch (e) {
          print('❌ Error sincronizando registro ${registro['id']}: $e');
        }
      }
    } catch (e) {
      print('❌ Error en sincronizarRegistrosPendientes: $e');
    }
  }
}
