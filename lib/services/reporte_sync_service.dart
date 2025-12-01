import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'dart:convert';
import '../services/api_service.dart';

enum SyncStatus { synced, syncing, pending, error }

class SyncProgress {
  final int actual;
  final int total;
  final int porcentaje;

  SyncProgress({
    required this.actual,
    required this.total,
    required this.porcentaje,
  });
}

class SyncStats {
  final int totalReportes;
  final int sincronizados;
  final int pendientes;

  SyncStats({
    required this.totalReportes,
    required this.sincronizados,
    required this.pendientes,
  });

  double get porcentajeSincronizado {
    if (totalReportes == 0) return 100;
    return (sincronizados / totalReportes * 100);
  }
}

// ✅ NUEVO: Clase SyncState que faltaba
class SyncState {
  final bool hasPendingSync;
  final int pendingReports;
  final int pendingDeployments;
  final bool offlineMode;
  final bool isSyncing;
  final bool success;

  SyncState({
    required this.hasPendingSync,
    required this.pendingReports,
    required this.pendingDeployments,
    this.offlineMode = false,
    this.isSyncing = false,
    this.success = true,
  });
}

// ✅ NUEVO: Clase SyncResult que faltaba
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  SyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
    this.failedCount = 0,
  });
}

class ReporteSyncService {
  static final ReporteSyncService _instance = ReporteSyncService._internal();

  factory ReporteSyncService() => _instance;

  ReporteSyncService._internal();

  late Database _db;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;

  final StreamController<SyncStatus> _syncStatusController =
  StreamController<SyncStatus>.broadcast();
  final StreamController<int> _pendingCountController =
  StreamController<int>.broadcast();
  final StreamController<SyncProgress> _syncProgressController =
  StreamController<SyncProgress>.broadcast();

  bool _isInitialized = false;
  bool _isSyncing = false;
  Timer? _autoSyncTimer;
  ApiService? _apiService;
  bool _offlineMode = false;

  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<int> get pendingCountStream => _pendingCountController.stream;
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

  /// ✅ CORREGIDO: Inicializar con parámetro accessToken
  Future<void> initialize({String? accessToken}) async {
    try {
      if (accessToken != null) {
        _apiService = ApiService(accessToken: accessToken);
        print('✅ ApiService inicializado con token');
      }
    } catch (e) {
      print('⚠️ Error inicializando ApiService: $e');
    }
  }

  /// Inicializar la base de datos
  Future<void> initializeDatabase(Database database) async {
    if (_isInitialized) return;

    _db = database;

    await _db.execute('''
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

    _isInitialized = true;
    await _iniciarMonitorConexion();
    _iniciarSincronizacionAutomatica();
    print('✅ ReporteSyncService inicializado correctamente');
  }

  /// Monitorear cambios de conectividad
  Future<void> _iniciarMonitorConexion() async {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
          (result) async {
        print('📡 Cambio de conectividad detectado: $result');

        _offlineMode = result == ConnectivityResult.none;

        if (!_offlineMode) {
          print('✅ Conexión disponible - iniciando sincronización automática');
          await Future.delayed(const Duration(seconds: 2));
          await sincronizarReportes(apiService: _apiService);
        }
      },
    );
  }

  Future<void> _syncReporte(Map<String, dynamic> reporte) async {
    final dataToSend = Map<String, dynamic>.from(reporte)
      ..removeWhere(
        (key, value) => ['id', 'synced', 'updated_at'].contains(key),
      );

    if (dataToSend.containsKey('contador_c')) {
      dataToSend['registro_c'] = dataToSend['contador_c'];
    }
    if (dataToSend.containsKey('contador_r')) {
      dataToSend['registro_r'] = dataToSend['contador_r'];
    }

    final response = await _apiService!.enviarReporteDiario(dataToSend);

    if (response['success'] != true) {
      throw Exception('Error al sincronizar reporte: ${response['message']}');
    }

    await _databaseService.deleteReporte(reporte['id']);
  }

  // Future<void> _syncRegistroDespliegue(RegistroDespliegue registro) async {
  //   final registroMap = registro.toApiMap();
  //   final enviado = await _apiService!.enviarRegistroDespliegue(registroMap);
  //
  //   if (!enviado) {
  //     throw Exception('Error al sincronizar registro de despliegue');
  //   }
  //
  //   await _databaseService.eliminarRegistroDespliegue(registro.id!);
  // }
  // ✅ ESTA ES LA VERSIÓN CORREGIDA Y MEJORADA
  Future<void> _syncRegistroDespliegue(RegistroDespliegue registro) async {
    // --- INICIO DE LA CORRECCIÓN ---
    // 1. Tomamos los datos del registro local.
    //    Usamos toMap() porque nos da todos los campos, incluyendo los que pueden estar mal.
    final datosLocales = registro.toMap();

    // 2. Creamos un nuevo mapa con los datos que se enviarán a la API,
    //    replicando la misma estructura que funciona en el envío online.
    final datosParaApi = {
      'latitud': datosLocales['latitud'],
      'longitud': datosLocales['longitud'],
      'descripcion_reporte': datosLocales['descripcionReporte'],
      'estado': 'DESPLIEGUE_SYNC', // Un estado para saber que vino de una sincronización
      'sincronizar': true,
      'observaciones': datosLocales['observaciones'],
      'incidencias': datosLocales['incidencias'],
      // 3. Corregimos los campos problemáticos.
      //    Si la fecha está vacía o nula, usamos la del registro local.
      //    Si no, usamos una nueva para asegurar un formato válido.
      'fecha_hora': (datosLocales['fechaHora'] as String?)?.isNotEmpty ?? false
          ? datosLocales['fechaHora']
          : DateTime.now().toIso8601String(),
      'operador': datosLocales['operadorId'], // Usamos el 'operadorId' guardado.
      'centro_empadronamiento': datosLocales['centroEmpadronamiento'],
    };

    print('🔄 Sincronizando Registro de Despliegue ID: ${registro.id}');
    print('📦 Datos corregidos para API: $datosParaApi');
    // --- FIN DE LA CORRECCIÓN ---

    // 4. Enviamos los datos ya corregidos y completos.
    final enviado = await _apiService!.enviarRegistroDespliegue(datosParaApi);

    if (!enviado) {
      // Si aún falla, imprimimos el error que viene del ApiService para tener más detalles.
      print('❌ Fallo al sincronizar el registro de despliegue ID: ${registro.id}');
      throw Exception('Error al sincronizar registro de despliegue');
    }

    print('✅ Registro de despliegue ID: ${registro.id} sincronizado exitosamente.');
    // 5. Si se envió con éxito, lo eliminamos de la base de datos local para no volver a enviarlo.
    await _databaseService.eliminarRegistroDespliegue(registro.id!);
  }


  /// Guardar reporte con geolocalización (método unificado)
  // Future<Map<String, dynamic>> saveReporteGeolocalizacion({
  //   required Map<String, dynamic> reporteData,
  //   required Map<String, dynamic> despliegueData,
  // }) async {
  //   try {
  //     final isOnline = await _isConnected();
  //
  //     if (isOnline) {
  //       return await _sendReporteGeolocalizacionToServer(
  //         reporteData: reporteData,
  //         despliegueData: despliegueData,
  //       );
  //     } else {
  //       return await _saveReporteGeolocalizacionLocally(
  //         reporteData: reporteData,
  //         despliegueData: despliegueData,
  //       );
  //     }
  //   } catch (e) {
  //     return await _saveReporteGeolocalizacionLocally(
  //       reporteData: reporteData,
  //       despliegueData: despliegueData,
  //     );
  //   }
  // }

  Future<Map<String, dynamic>> _sendReporteGeolocalizacionToServer({
    required Map<String, dynamic> reporteData,
    required Map<String, dynamic> despliegueData,
  }) async {
    try {
      _syncStatusController.add(
        SyncStatus(
          isSyncing: true,
          message: 'Enviando reporte con geolocalización...',
        ),
      );

      final reporteResponse = await _apiService!.enviarReporteDiario(
        reporteData,
      );
      final despliegueEnviado = await _apiService!.enviarRegistroDespliegue(
        despliegueData,
      );

      if (reporteResponse['success'] == true && despliegueEnviado == true) {
        _syncStatusController.add(
          SyncStatus(
            isSyncing: false,
            message: 'Reporte y geolocalización enviados exitosamente',
            success: true,
          ),
        );

        return {
          'success': true,
          'message': 'Reporte y geolocalización enviados al servidor',
          'saved_locally': false,
        };
      } else {
        String errorMessage = '';
        if (reporteResponse['success'] != true) {
          errorMessage += 'Reporte: ${reporteResponse['message']}. ';
        }
        if (!despliegueEnviado) {
          errorMessage += 'Geolocalización: Error al enviar despliegue.';
        }

        print('❌ Error al enviar: $errorMessage');
        return await _saveReporteGeolocalizacionLocally(
          reporteData: reporteData,
          despliegueData: despliegueData,
        );
      }
    } catch (e) {
      print('Error al enviar reporte con geolocalización: $e');
      return await _saveReporteGeolocalizacionLocally(
        reporteData: reporteData,
        despliegueData: despliegueData,
      );
    }
  }

  Future<Map<String, dynamic>> _saveReporteGeolocalizacionLocally({
    required Map<String, dynamic> reporteData,
    required Map<String, dynamic> despliegueData,
  }) async {
    try {
      // Guardar reporte diario localmente
      final reporteId = await _databaseService.insertReporte({
        ...reporteData,
        'synced': 0,
      });

      // Guardar registro de despliegue localmente
      final registroDespliegue = RegistroDespliegue(
        latitud: despliegueData['latitud'],
        longitud: despliegueData['longitud'],
        estado: despliegueData['estado'],
        sincronizar: despliegueData['sincronizar'],
        observaciones: despliegueData['observaciones'],
        incidencias: despliegueData['incidencias'] ?? '',
        fechaHora: despliegueData['fecha_hora_salida'],
        sincronizado: false,
        operadorId: despliegueData['operador'],
        centroEmpadronamiento: despliegueData['centroEmpadronamiento'],
      );

      final despliegueId = await _databaseService.insertRegistroDespliegue(
        registroDespliegue,
      );

      _syncStatusController.add(
        SyncStatus(
          isSyncing: false,
          message:
              'Reporte y geolocalización guardados localmente. Se sincronizarán cuando haya conexión.',
          success: true,
          offlineMode: true,
        ),
      );

      return {
        'success': true,
        'message':
            'Reporte y geolocalización guardados localmente. Se sincronizarán cuando haya conexión.',
        'local_reporte_id': reporteId,
        'local_despliegue_id': despliegueId,
        'saved_locally': true,
      };
    } catch (e) {
      print('Error al guardar reporte con geolocalización localmente: $e');
      throw Exception(
        'Error al guardar reporte con geolocalización localmente: $e',
      );
    }
  }

  /// Obtener lista de reportes
  Future<List<Map<String, dynamic>>> getReportes() async {
    return await _databaseService.getReportes();
  }

  /// Contar reportes pendientes
  Future<int> countUnsyncedReportes() async {
    return await _databaseService.countUnsyncedReportes();
  }

  Future<bool> _isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _syncStatusController.close();
  }

  /// Eliminar reporte local por ID
  Future<void> deleteLocalReporte(int id) async {
    try {
      await _databaseService.deleteReporte(id);
      print('✅ Reporte local $id eliminado');
    } catch (e) {
      print('❌ Error eliminando reporte local $id: $e');
      rethrow;
    }
  }

  /// Elimina de la base de datos local todos los reportes de un operador específico
  Future<void> clearSyncedLocalReportes(int operadorId) async {
    try {
      final count = await _databaseService.deleteSyncedReportesByOperador(
        operadorId,
      );
      if (count > 0) {
        print(
          '🧹 Limpieza completada: Se eliminaron $count reportes locales ya sincronizados para el operador $operadorId.',
        );
      }
    } catch (e) {
      print(
        '❌ Error durante la limpieza de reportes locales sincronizados: $e',
      );
    }
  }

  // ✅ MÉTODO ACTUALIZADO: saveReporteGeolocalizacion
  // Busca este método en reporte_sync_service.dart y reemplázalo

  Future<Map<String, dynamic>> saveReporteGeolocalizacion({
    required Map<String, dynamic> reporteData,
    required Map<String, dynamic> despliegueData,
  }) async {
    try {
      final tieneInternet = await _isConnected();

      print('═══════════════════════════════════════════════════════════');
      print('📤 ENVIANDO REPORTE DIARIO');
      print('═══════════════════════════════════════════════════════════');
      print('🌐 ¿Tiene internet?: $tieneInternet');
      print('📋 Datos del reporte: $reporteData');

      if (tieneInternet) {
        final accessToken = await AuthService().getAccessToken();
        if (accessToken == null || accessToken.isEmpty) {
          throw Exception('No se pudo obtener token de autenticación');
        }

        // ✅ URL CORRECTA PARA REPORTES
        final url = '${Enviroment.apiUrlDev}reportesdiarios/';

        print('🔗 URL: $url');
        print('🔑 Token: ${accessToken.substring(0, 20)}...');

        // ✅ CONSTRUIR JSON CORRECTO CON TODOS LOS CAMPOS
        final jsonReporte = {
          // Campos del reporte
          'fecha_reporte': reporteData['fecha_reporte'],
          'contador_inicial_c': reporteData['contador_inicial_c'],
          'contador_final_c': reporteData['contador_final_c'],
          'registro_c': reporteData['registro_c'],
          'contador_inicial_r': reporteData['contador_inicial_r'],
          'contador_final_r': reporteData['contador_final_r'],
          'registro_r': reporteData['registro_r'],
          'incidencias': reporteData['incidencias'] ?? '',
          'observaciones': reporteData['observaciones'] ?? '',
          'estado': reporteData['estado'] ?? 'ENVIO REPORTE',
          'sincronizar': reporteData['sincronizar'] ?? true,
          'operador': reporteData['operador'],
          'estacion': reporteData['estacion'],
          'centro_empadronamiento': reporteData['centro_empadronamiento'],

          // ✅ CORREGIDO: Usar nombres correctos para los nuevos campos
          'observacionC': reporteData['observacionC'] ?? '',
          'observacionR': reporteData['observacionR'] ?? '',
          'saltosenC':
              int.tryParse(reporteData['saltosenC']?.toString() ?? '0') ?? 0,
          'saltosenR':
              int.tryParse(reporteData['saltosenR']?.toString() ?? '0') ?? 0,

          // ✅ NUEVO: Agregar fecha_registro (hora actual)
          'fecha_registro': DateTime.now()
              .toLocal()
              .toIso8601String()
              .replaceAll('Z', ''),
        };

        print('📦 JSON para API: $jsonReporte');

        try {
          final response = await http
              .post(
                Uri.parse(url),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $accessToken',
                },
                body: jsonEncode(jsonReporte),
              )
              .timeout(const Duration(seconds: 30));

          print('📥 Status Code: ${response.statusCode}');
          print('📥 Response: ${response.body}');

          if (response.statusCode == 200 || response.statusCode == 201) {
            print('✅ Reporte enviado exitosamente al servidor');

            // ✅ OPCIONAL: También enviar despliegue si es necesario
            if (despliegueData['latitud'] != null &&
                despliegueData['longitud'] != null) {
              await _enviarDespliegueReporte(despliegueData, accessToken);
            }
          }
        }
      },
    );
  }

  // ✅ NUEVO MÉTODO: Guardar reporte localmente
  // Future<void> _guardarReporteLocalmente(
  //   Map<String, dynamic> reporteData,
  // ) async {
  //   try {
  //     final db = await DatabaseService().database;
  //
  //     // Mapear los datos al formato de la tabla
  //     final datosParaBD = {
  //       'fecha_reporte': reporteData['fecha_reporte'],
  //       'contador_inicial_c': reporteData['contador_inicial_c'],
  //       'contador_final_c': reporteData['contador_final_c'],
  //       'contador_c': reporteData['registro_c'],
  //       'contador_inicial_r': reporteData['contador_inicial_r'],
  //       'contador_final_r': reporteData['contador_final_r'],
  //       'contador_r': reporteData['registro_r'],
  //       'incidencias': reporteData['incidencias'] ?? '',
  //       'observaciones': reporteData['observaciones'] ?? '',
  //       'operador': reporteData['operador'],
  //       'estacion': reporteData['estacion'],
  //       'centro_empadronamiento': reporteData['centro_empadronamiento'],
  //       'estado': reporteData['estado'] ?? 'PENDIENTE_SINCRONIZACION',
  //       'sincronizar': reporteData['sincronizar'] ? 1 : 0,
  //       'synced': 0,
  //       'observacion_c': reporteData['observacion_c'],
  //       'observacion_r': reporteData['observacion_r'],
  //       'saltosen_c': reporteData['saltosen_c'],
  //       'saltosen_r': reporteData['saltosen_r'],
  //       'updated_at': DateTime.now().toLocal().toIso8601String(),
  //     };
  //
  //     final id = await db.insert(
  //       'reportes_diarios',
  //       datosParaBD,
  //       conflictAlgorithm: ConflictAlgorithm.replace,
  //     );
  //
  //     print('✅ Reporte guardado localmente con ID: $id');
  //   } catch (e) {
  //     print('❌ Error guardando reporte localmente: $e');
  //   }
  // }
  Future<void> _guardarReporteLocalmente(
    Map<String, dynamic> reporteData,
  ) async {
    try {
      final db = await DatabaseService().database;

      // Mapear los datos al formato de la tabla
      final datosParaBD = {
        'fecha_reporte': reporteData['fecha_reporte'],
        'contador_inicial_c': reporteData['contador_inicial_c'],
        'contador_final_c': reporteData['contador_final_c'],
        'contador_c': reporteData['registro_c'],
        'contador_inicial_r': reporteData['contador_inicial_r'],
        'contador_final_r': reporteData['contador_final_r'],
        'contador_r': reporteData['registro_r'],
        'incidencias': reporteData['incidencias'] ?? '',
        'observaciones': reporteData['observaciones'] ?? '',
        'operador': reporteData['operador'],
        'estacion': reporteData['estacion'],
        'centro_empadronamiento': reporteData['centro_empadronamiento'],
        'estado': reporteData['estado'] ?? 'PENDIENTE_SINCRONIZACION',
        'sincronizar': reporteData['sincronizar'] ? 1 : 0,
        'synced': 0,

        // ✅ CORREGIDO: Usar nombres correctos observacionR
        'observacionC': reporteData['observacionC'] ?? '',
        'observacionR': reporteData['observacionR'] ?? '',
        'saltosenC':
            int.tryParse(reporteData['saltosenC']?.toString() ?? '0') ?? 0,
        'saltosenR':
            int.tryParse(reporteData['saltosenR']?.toString() ?? '0') ?? 0,

        'updated_at': DateTime.now().toLocal().toIso8601String(),
      };

      final id = await db.insert(
        'reportes_diarios',
        datosParaBD,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ Reporte guardado localmente con ID: $id');
      print('📋 Datos guardados localmente: $datosParaBD');
    } catch (e) {
      print('❌ Error guardando reporte localmente: $e');
    }
  }

  // ✅ NUEVO MÉTODO: Enviar despliegue (ubicación) del reporte
  Future<void> _enviarDespliegueReporte(
    Map<String, dynamic> despliegueData,
    String accessToken,
  ) async {
    try {
      final url = '${Enviroment.apiUrlDev}registrosdespliegue/';

      final jsonDespliegue = {
        'latitud': double.tryParse(despliegueData['latitud'].toString()) ?? 0,
        'longitud': double.tryParse(despliegueData['longitud'].toString()) ?? 0,
        'descripcion_reporte': null,
        'estado': despliegueData['estado'] ?? 'REPORTE ENVIADO',
        'sincronizar': true,
        'observaciones': despliegueData['observaciones'],
        'incidencias': despliegueData['incidencias'],
        'fecha_hora': despliegueData['fecha_hora'],
        'operador': despliegueData['operador'],
      };

      print('📍 Enviando despliegue (ubicación) del reporte...');
      print('🔗 URL: $url');
      print('📦 Datos: $jsonDespliegue');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode(jsonDespliegue),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Despliegue enviado exitosamente');
      } else {
        print('⚠️ Error enviando despliegue: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en _enviarDespliegueReporte: $e');
    }
  }

  // ✅ AGREGAR este método en la clase ReporteSyncService

  /// Verificar si hay conexión a internet
  Future<bool> _verificarConexion() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _offlineMode = result == ConnectivityResult.none;
      return !_offlineMode;
    } catch (e) {
      print('❌ Error verificando conexión: $e');
      return false;
    }
  }

  /// Guardar reporte localmente
  Future<Map<String, dynamic>> saveReporteGeolocalizacion({
    required Map<String, dynamic> reporteData,
    required Map<String, dynamic> despliegueData,
  }) async {
    try {
      if (!_isInitialized) {
        return {
          'success': false,
          'message': 'Base de datos no inicializada',
          'saved_locally': false,
        };
      }

      final ahora = DateTime.now().toIso8601String();

      await _db.insert(
        'reportes_pendientes',
        {
          'reporte_data': jsonEncode(reporteData),
          'despliegue_data': jsonEncode(despliegueData),
          'fecha_creacion': ahora,
          'sincronizado': 0,
          'intentos': 0,
        },
      );

      await _actualizarConteoPendientes();

      print('💾 Reporte guardado localmente');
      return {
        'success': true,
        'message': 'Reporte guardado localmente',
        'saved_locally': true,
      };
    } catch (e) {
      print('❌ Error guardando reporte: $e');
      return {
        'success': false,
        'message': 'Error guardando reporte: $e',
        'saved_locally': false,
      };
    }
  }

  /// Obtener todos los reportes guardados
  Future<List<Map<String, dynamic>>> getReportes() async {
    try {
      if (!_isInitialized) return [];

      final reportes = await _db.query('reportes_pendientes');
      return reportes;
    } catch (e) {
      print('❌ Error obteniendo reportes: $e');
      return [];
    }
  }

  /// Contar reportes pendientes
  Future<int> _contarReportesPendientes() async {
    try {
      if (!_isInitialized) return 0;

      final result = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM reportes_pendientes WHERE sincronizado = 0',
      );
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// ✅ CORREGIDO: Sincronizar reportes pendientes
  Future<void> sincronizarReportes({ApiService? apiService}) async {
    if (_isSyncing) {
      print('⏳ Sincronización ya en progreso');
      return;
    }

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    try {
      final hasConnection = await _verificarConexion();
      if (!hasConnection) {
        print('❌ No hay conexión a internet');
        _syncStatusController.add(SyncStatus.pending);
        _isSyncing = false;
        return;
      }

      // ✅ CORREGIDO: Usar apiService si fue proporcionado
      final serviceToUse = apiService ?? _apiService;
      if (serviceToUse == null) {
        print('⚠️ No hay ApiService disponible');
        _syncStatusController.add(SyncStatus.error);
        _isSyncing = false;
        return;
      }

      final reportesPendientes = await _db.query(
        'reportes_pendientes',
        where: 'sincronizado = ?',
        whereArgs: [0],
      );

      if (reportesPendientes.isEmpty) {
        print('✅ No hay reportes pendientes');
        _syncStatusController.add(SyncStatus.synced);
        _isSyncing = false;
        return;
      }

      print('🔄 Sincronizando ${reportesPendientes.length} reportes...');

      int sincronizados = 0;
      int total = reportesPendientes.length;

      for (int i = 0; i < reportesPendientes.length; i++) {
        final reporte = reportesPendientes[i];
        final id = reporte['id'] as int?; // 1. Hacemos un cast a 'int?' (entero nullable)

        if (id == null) {
          print('❌ Error: Reporte con id nulo encontrado, saltando.');
          continue; // Si el id es nulo, no podemos procesar este reporte
        }

        // ✅ CORREGIDO: Usamos el 'id' verificado
        final success = await _enviarReporte(reporte, serviceToUse);

        if (success) {
          sincronizados++;
          // ✅ CORREGIDO: Línea 309 del archivo original
          await _marcarComoSincronizado(id);
        } else {
          // ✅ CORREGIDO: Línea 311 del archivo original
          await _incrementarIntentos(id);
        }

        _syncProgressController.add(
          SyncProgress(
            actual: i + 1,
            total: total,
            porcentaje: ((i + 1) / total * 100).toInt(),
          ),
        );
      }
      // for (int i = 0; i < reportesPendientes.length; i++) {
      //   final reporte = reportesPendientes[i];
      //   // ✅ CORREGIDO línea 308: Cambiar a _enviarReporte con serviceToUse
      //   final success = await _enviarReporte(reporte, serviceToUse);
      //
      //   if (success) {
      //     sincronizados++;
      //     await _marcarComoSincronizado(reporte['id']);
      //   } else {
      //     await _incrementarIntentos(reporte['id']);
      //   }
      //
      //   _syncProgressController.add(
      //     SyncProgress(
      //       actual: i + 1,
      //       total: total,
      //       porcentaje: ((i + 1) / total * 100).toInt(),
      //     ),
      //   );
      // }

      await _actualizarConteoPendientes();

      print('✅ Sincronización completada: $sincronizados/$total');
      _syncStatusController.add(SyncStatus.synced);
    } catch (e) {
      print('❌ Error durante sincronización: $e');
      _syncStatusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// ✅ NUEVO: Método syncNow para sincronización manual
  Future<SyncResult> syncNow() async {
    try {
      print('🔄 Iniciando sincronización manual...');

      if (!_isInitialized) {
        return SyncResult(
          success: false,
          message: 'Base de datos no inicializada',
        );
      }

      final hasConnection = await _verificarConexion();
      if (!hasConnection) {
        return SyncResult(
          success: false,
          message: 'No hay conexión a internet disponible',
        );
      }

      if (_apiService == null) {
        return SyncResult(
          success: false,
          message: 'Token no disponible. Inicia sesión nuevamente',
        );
      }

      await sincronizarReportes(apiService: _apiService);

      return SyncResult(
        success: true,
        message: 'Sincronización completada exitosamente',
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Error durante sincronización: $e',
      );
    }
  }

  /// ✅ NUEVO: Obtener estado de sincronización
  Future<SyncState> getSyncState() async {
    try {
      final pendientes = await _contarReportesPendientes();

      return SyncState(
        hasPendingSync: pendientes > 0,
        pendingReports: pendientes,
        pendingDeployments: 0,
        offlineMode: _offlineMode,
        isSyncing: _isSyncing,
        success: true,
      );
    } catch (e) {
      return SyncState(
        hasPendingSync: false,
        pendingReports: 0,
        pendingDeployments: 0,
        offlineMode: _offlineMode,
        isSyncing: false,
        success: false,
      );
    }
  }

  /// ✅ CORREGIDO línea 310: Enviar un reporte al servidor
  Future<bool> _enviarReporte(
      Map<String, dynamic> reporte,
      ApiService apiService,
      ) async {
    try {
      final reporteData = jsonDecode(reporte['reporte_data']);
      final despliegueData = jsonDecode(reporte['despliegue_data']);

      final resultReporte = await apiService.enviarReporteDiario(reporteData);
      if (!resultReporte['success']) {
        print('❌ Error enviando reporte diario: ${resultReporte['message']}');
        return false;
      }

      final resultDespliegue =
      await apiService.enviarRegistroDespliegue(despliegueData);
      if (!resultDespliegue) {
        print('❌ Error enviando registro despliegue');
        return false;
      }

      print('✅ Reporte enviado exitosamente');
      return true;
    } catch (e) {
      print('❌ Error enviando reporte: $e');
      return false;
    }
  }

  /// Marcar reporte como sincronizado
  Future<void> _marcarComoSincronizado(int id) async {
    try {
      await _db.update(
        'reportes_pendientes',
        {
          'sincronizado': 1,
          'ultima_tentativa': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Error marcando como sincronizado: $e');
    }
  }

  /// Incrementar contador de intentos
  Future<void> _incrementarIntentos(int id) async {
    try {
      await _db.rawUpdate(
        'UPDATE reportes_pendientes SET intentos = intentos + 1, ultima_tentativa = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), id],
      );
    } catch (e) {
      print('❌ Error incrementando intentos: $e');
    }
  }

  /// Actualizar conteo de reportes pendientes
  Future<void> _actualizarConteoPendientes() async {
    try {
      final result = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM reportes_pendientes WHERE sincronizado = 0',
      );
      final count = (result.first['count'] as int?) ?? 0;
      _pendingCountController.add(count);
      print('📊 Reportes pendientes: $count');
    } catch (e) {
      print('❌ Error actualizando conteo: $e');
    }
  }

  /// Obtener estadísticas de sincronización
  Future<SyncStats> getSyncStats() async {
    try {
      final total = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM reportes_pendientes',
      );
      final sincronizados = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM reportes_pendientes WHERE sincronizado = 1',
      );
      final pendientes = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM reportes_pendientes WHERE sincronizado = 0',
      );

      return SyncStats(
        totalReportes: (total.first['count'] as int?) ?? 0,
        sincronizados: (sincronizados.first['count'] as int?) ?? 0,
        pendientes: (pendientes.first['count'] as int?) ?? 0,
      );
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return SyncStats(
        totalReportes: 0,
        sincronizados: 0,
        pendientes: 0,
      );
    }
  }

  /// Limpiar reportes sincronizados
  Future<void> limpiarReportesSincronizados() async {
    try {
      await _db.delete(
        'reportes_pendientes',
        where: 'sincronizado = ?',
        whereArgs: [1],
      );
      await _actualizarConteoPendientes();
      print('🧹 Reportes sincronizados limpiados');
    } catch (e) {
      print('❌ Error limpiando reportes: $e');
    }
  }

  /// Limpiar recursos
  void dispose() {
    _connectivitySubscription?.cancel();
    _autoSyncTimer?.cancel();
    _syncStatusController.close();
    _pendingCountController.close();
    _syncProgressController.close();
  }
}