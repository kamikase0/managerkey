import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../config/enviroment.dart';
import '../models/registro_despliegue_model.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'dart:async';

class ReporteSyncService {
  final DatabaseService _databaseService;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription? _connectivitySubscription;
  Timer? _syncTimer;
  bool _isSyncing = false;
  String? _accessToken;
  ApiService? _apiService;

  ReporteSyncService({required DatabaseService databaseService})
    : _databaseService = databaseService;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();

  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  Future<void> initialize({required String accessToken}) async {
    _accessToken = accessToken;
    _apiService = ApiService(accessToken: accessToken);
    _setupConnectivityListener();
    _setupPeriodicSync();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      if (result != ConnectivityResult.none) {
        _performSync();
      }
    });
  }

  void _setupPeriodicSync() {
    _syncTimer = Timer.periodic(Duration(minutes: 5), (_) {
      _performSync();
    });
  }

  /// Guardar reporte (online o offline)
  Future<Map<String, dynamic>> saveReporte(
    Map<String, dynamic> reporteData,
  ) async {
    try {
      final isOnline = await _isConnected();

      if (isOnline) {
        return await _sendReporteToServer(reporteData);
      } else {
        return await _saveReporteLocally(reporteData);
      }
    } catch (e) {
      return await _saveReporteLocally(reporteData);
    }
  }

  Future<Map<String, dynamic>> _sendReporteToServer(
    Map<String, dynamic> reporteData,
  ) async {
    try {
      _syncStatusController.add(
        SyncStatus(isSyncing: true, message: 'Enviando reporte al servidor...'),
      );

      final response = await _apiService!.enviarReporteDiario(reporteData);

      if (response['success'] == true) {
        _syncStatusController.add(
          SyncStatus(
            isSyncing: false,
            message: 'Reporte enviado exitosamente',
            success: true,
          ),
        );

        return {
          'success': true,
          'message': 'Reporte enviado al servidor',
          'data': response['data'],
          'saved_locally': false,
        };
      } else {
        return await _saveReporteLocally(reporteData);
      }
    } catch (e) {
      print('Error al enviar reporte: $e');
      return await _saveReporteLocally(reporteData);
    }
  }

  Future<Map<String, dynamic>> _saveReporteLocally(
    Map<String, dynamic> reporteData,
  ) async {
    try {
      final id = await _databaseService.insertReporte({
        ...reporteData,
        'synced': 0,
      });

      _syncStatusController.add(
        SyncStatus(
          isSyncing: false,
          message:
              'Reporte guardado localmente. Se sincronizará cuando haya conexión.',
          success: true,
          offlineMode: true,
        ),
      );

      return {
        'success': true,
        'message':
            'Reporte guardado localmente. Se sincronizará cuando haya conexión.',
        'local_id': id,
        'saved_locally': true,
      };
    } catch (e) {
      print('Error al guardar reporte localmente: $e');
      throw Exception('Error al guardar reporte localmente: $e');
    }
  }

  /// Sincronización automática de reportes pendientes
  Future<void> _performSync() async {
    if (_isSyncing || _apiService == null) return;

    try {
      _isSyncing = true;
      final isOnline = await _isConnected();

      if (!isOnline) {
        _syncStatusController.add(
          SyncStatus(
            isSyncing: false,
            message:
                'Sin conexión. Los reportes se sincronizarán cuando haya red.',
            offlineMode: true,
          ),
        );
        return;
      }

      _syncStatusController.add(
        SyncStatus(
          isSyncing: true,
          message: 'Sincronizando reportes pendientes...',
        ),
      );

      // Sincronizar reportes diarios
      final reportesPendientes = await _databaseService.getUnsyncedReportes();
      int syncedCount = 0;
      int failedCount = 0;

      for (final reporte in reportesPendientes) {
        try {
          await _syncReporte(reporte);
          syncedCount++;
        } catch (e) {
          print('Error sincronizando reporte ${reporte['id']}: $e');
          failedCount++;
        }
      }

      // Sincronizar registros de despliegue
      final registrosDesplieguePendientes = await _databaseService
          .obtenerRegistrosDespliegueNoSincronizados();
      for (final registro in registrosDesplieguePendientes) {
        try {
          await _syncRegistroDespliegue(registro);
          syncedCount++;
        } catch (e) {
          print('Error sincronizando registro despliegue ${registro.id}: $e');
          failedCount++;
        }
      }

      final message = failedCount > 0
          ? 'Se sincronizaron $syncedCount registros. $failedCount fallaron.'
          : 'Se sincronizaron $syncedCount registros exitosamente.';

      _syncStatusController.add(
        SyncStatus(
          isSyncing: false,
          message: message,
          success: failedCount == 0,
          syncedCount: syncedCount,
        ),
      );
    } catch (e) {
      print('Error durante la sincronización: $e');
      _syncStatusController.add(
        SyncStatus(
          isSyncing: false,
          message: 'Error durante la sincronización: $e',
          success: false,
        ),
      );
    } finally {
      _isSyncing = false;
    }
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

            return {
              'success': true,
              'message': '✅ Reporte enviado exitosamente',
              'saved_locally': false,
            };
          } else {
            print('❌ Error del servidor: ${response.statusCode}');
            print('📄 Response body: ${response.body}');

            // Guardar localmente si falla
            print('💾 Guardando reporte localmente como fallback...');
            await _guardarReporteLocalmente(jsonReporte);

            return {
              'success': true,
              'message': '⚠️ Error al enviar. Reporte guardado localmente.',
              'saved_locally': true,
            };
          }
        } catch (e) {
          print('❌ Error de conexión: $e');
          print('💾 Guardando reporte localmente como fallback...');
          await _guardarReporteLocalmente(jsonReporte);

          return {
            'success': true,
            'message': '⚠️ Error de conexión. Reporte guardado localmente.',
            'saved_locally': true,
          };
        }
      } else {
        // Sin internet
        print('📡 Sin conexión a internet');
        print('💾 Guardando reporte localmente...');
        await _guardarReporteLocalmente(reporteData);

        return {
          'success': true,
          'message': '📱 Sin internet. Reporte guardado localmente.',
          'saved_locally': true,
        };
      }
    } catch (e) {
      print('❌ Error en saveReporteGeolocalizacion: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'saved_locally': false,
      };
    }
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
  Future<bool> verificarConexion() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final tieneConexion = result != ConnectivityResult.none;
      print(
        '🌐 Verificación de conexión: ${tieneConexion ? "CONECTADO" : "SIN CONEXIÓN"}',
      );
      return tieneConexion;
    } catch (e) {
      print('❌ Error verificando conexión: $e');
      return false;
    }
  }

  // /// Método privado (mantener para compatibilidad)
  // Future<bool> _isConnected() async {
  //   return await verificarConexion();
  // }
  /// ✅ NUEVO: Sincronizar reportes pendientes (método público)
  Future<void> syncPendingReportes() async {
    if (_isSyncing || _apiService == null) return;

    try {
      _isSyncing = true;
      final isOnline = await _isConnected();

      if (!isOnline) {
        print('📡 Sin conexión. No se pueden sincronizar reportes pendientes.');
        return;
      }

      print('🔄 Sincronizando reportes pendientes...');

      // Sincronizar reportes diarios
      final reportesPendientes = await _databaseService.getUnsyncedReportes();
      int syncedCount = 0;
      int failedCount = 0;

      for (final reporte in reportesPendientes) {
        try {
          await _syncReporte(reporte);
          syncedCount++;
        } catch (e) {
          print('❌ Error sincronizando reporte ${reporte['id']}: $e');
          failedCount++;
        }
      }

      // Sincronizar registros de despliegue
      final registrosDesplieguePendientes = await _databaseService
          .obtenerRegistrosDespliegueNoSincronizados();
      for (final registro in registrosDesplieguePendientes) {
        try {
          await _syncRegistroDespliegue(registro);
          syncedCount++;
        } catch (e) {
          print('❌ Error sincronizando registro despliegue ${registro.id}: $e');
          failedCount++;
        }
      }

      if (syncedCount > 0) {
        print('✅ Se sincronizaron $syncedCount registros exitosamente');
      }
      if (failedCount > 0) {
        print('⚠️ $failedCount registros fallaron al sincronizar');
      }
    } catch (e) {
      print('❌ Error durante la sincronización: $e');
    } finally {
      _isSyncing = false;
    }
  }
}

class SyncStatus {
  final bool isSyncing;
  final String message;
  final bool success;
  final bool offlineMode;
  final int syncedCount;

  SyncStatus({
    required this.isSyncing,
    required this.message,
    this.success = false,
    this.offlineMode = false,
    this.syncedCount = 0,
  });
}
