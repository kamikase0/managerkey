import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/registro_despliegue_model.dart';
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
  ApiService? _apiService; // Cambiado a nullable

  ReporteSyncService({
    required DatabaseService databaseService,
  }) : _databaseService = databaseService;

  // Stream para notificar cambios en el estado de sincronización
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  Future<void> initialize({required String accessToken}) async {
    _accessToken = accessToken;
    _apiService = ApiService(accessToken: accessToken); // Inicializar ApiService con token
    _setupConnectivityListener();
    _setupPeriodicSync();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen((ConnectivityResult result) {
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
  Future<Map<String, dynamic>> saveReporte(Map<String, dynamic> reporteData) async {
    try {
      final isOnline = await _isConnected();

      if (isOnline) {
        // Enviar directamente al servidor
        return await _sendReporteToServer(reporteData);
      } else {
        // Guardar localmente para sincronización posterior
        return await _saveReporteLocally(reporteData);
      }
    } catch (e) {
      // Fallback: guardar localmente si falla el envío
      return await _saveReporteLocally(reporteData);
    }
  }

  Future<Map<String, dynamic>> _sendReporteToServer(
      Map<String, dynamic> reporteData,
      ) async {
    try {
      _syncStatusController.add(SyncStatus(
        isSyncing: true,
        message: 'Enviando reporte al servidor...',
      ));

      // ✅ CORREGIDO: Sin parámetro accessToken
      final response = await _apiService!.enviarReporteDiario(reporteData);

      // ✅ CORREGIDO: Verificación correcta del Map
      if (response['success'] == true) {
        _syncStatusController.add(SyncStatus(
          isSyncing: false,
          message: 'Reporte enviado exitosamente',
          success: true,
        ));

        return {
          'success': true,
          'message': 'Reporte enviado al servidor',
          'data': response['data'],
          'saved_locally': false,
        };
      } else {
        // Si falla, guardar localmente
        return await _saveReporteLocally(reporteData);
      }
    } catch (e) {
      print('Error al enviar reporte: $e');
      // Fallback: guardar localmente
      return await _saveReporteLocally(reporteData);
    }
  }

  Future<Map<String, dynamic>> _saveReporteLocally(
      Map<String, dynamic> reporteData,
      ) async {
    try {
      final id = await _databaseService.insertReporte({
        ...reporteData,
        'synced': 0, // 0 = no sincronizado, 1 = sincronizado
      });

      _syncStatusController.add(SyncStatus(
        isSyncing: false,
        message: 'Reporte guardado localmente. Se sincronizará cuando haya conexión.',
        success: true,
        offlineMode: true,
      ));

      return {
        'success': true,
        'message': 'Reporte guardado localmente. Se sincronizará cuando haya conexión.',
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
        _syncStatusController.add(SyncStatus(
          isSyncing: false,
          message: 'Sin conexión. Los reportes se sincronizarán cuando haya red.',
          offlineMode: true,
        ));
        return;
      }

      _syncStatusController.add(SyncStatus(
        isSyncing: true,
        message: 'Sincronizando reportes pendientes...',
      ));

      final reportesPendientes = await _databaseService.getUnsyncedReportes();

      if (reportesPendientes.isEmpty) {
        _syncStatusController.add(SyncStatus(
          isSyncing: false,
          message: 'Todo sincronizado',
          success: true,
        ));
        return;
      }

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

      final message = failedCount > 0
          ? 'Se sincronizaron $syncedCount reportes. $failedCount fallaron.'
          : 'Se sincronizaron $syncedCount reportes exitosamente y se eliminaron localmente.';

      _syncStatusController.add(SyncStatus(
        isSyncing: false,
        message: message,
        success: failedCount == 0,
        syncedCount: syncedCount,
      ));
    } catch (e) {
      print('Error durante la sincronización: $e');
      _syncStatusController.add(SyncStatus(
        isSyncing: false,
        message: 'Error durante la sincronización: $e',
        success: false,
      ));
    } finally {
      _isSyncing = false;
    }
  }

  // En DatabaseService
  // Future<List<RegistroDespliegue>> obtenerRegistrosDespliegueNoSincronizados() async {
  //   final db = await database;
  //   final maps = await db.query(
  //     'registros_despliegue',
  //     where: 'sincronizado = ?',
  //     whereArgs: [0],
  //   );
  //   return maps.map((map) => RegistroDespliegue.fromMap(map)).toList();
  // }

  // Future<void> eliminarRegistroDespliegue(int id) async {
  //   final db = await database;
  //   await db.delete(
  //     'registros_despliegue',
  //     where: 'id = ?',
  //     whereArgs: [id],
  //   );
  // }

  Future<void> _syncReporte(Map<String, dynamic> reporte) async {
    // Preparar datos para envío (remover campos de BD local)
    final dataToSend = Map<String, dynamic>.from(reporte)
      ..removeWhere((key, value) =>
          ['id', 'synced', 'updated_at'].contains(key));

    // Mapear nombres de columnas si es necesario
    if (dataToSend.containsKey('contador_c')) {
      dataToSend['registro_c'] = dataToSend['contador_c'];
    }
    if (dataToSend.containsKey('contador_r')) {
      dataToSend['registro_r'] = dataToSend['contador_r'];
    }

    // ✅ CORREGIDO: Sin parámetro accessToken
    final response = await _apiService!.enviarReporteDiario(dataToSend);

    // ✅ CORREGIDO: Verificación correcta del Map
    if (response['success'] != true) {
      throw Exception('Error al sincronizar reporte: ${response['message']}');
    }

    // ✅ ELIMINAR el registro local en lugar de solo marcarlo como sincronizado
    await _databaseService.deleteReporte(reporte['id']);
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
      // Delegamos la operación de borrado directamente al servicio de base de datos.
      final count = await _databaseService.deleteSyncedReportesByOperador(operadorId);
      if (count > 0) {
        print('🧹 Limpieza completada: Se eliminaron $count reportes locales ya sincronizados para el operador $operadorId.');
      }
    } catch (e) {
      print('❌ Error durante la limpieza de reportes locales sincronizados: $e');
      // No relanzamos el error para no interrumpir la experiencia del usuario,
      // ya que esta es una tarea de mantenimiento en segundo plano.
    }
  }

  // Agrega este método a tu ReporteSyncService
  Future<Map<String, dynamic>> saveReporteConGeolocalizacion({
    required Map<String, dynamic> reporteData,
    required Map<String, dynamic> despliegueData,
  }) async {
    try {
      final isOnline = await _isConnected();

      if (isOnline) {
        // Enviar ambos directamente al servidor
        return await _sendReporteConGeolocalizacionToServer(
          reporteData: reporteData,
          despliegueData: despliegueData,
        );
      } else {
        // Guardar ambos localmente para sincronización posterior
        return await _saveReporteConGeolocalizacionLocally(
          reporteData: reporteData,
          despliegueData: despliegueData,
        );
      }
    } catch (e) {
      // Fallback: guardar localmente si falla el envío
      return await _saveReporteConGeolocalizacionLocally(
        reporteData: reporteData,
        despliegueData: despliegueData,
      );
    }
  }

  // ✅ AGREGAR MÉTODO PARA SINCRONIZAR REGISTROS DE DESPLIEGUE PENDIENTES
  Future<void> sincronizarRegistrosDesplieguePendientes() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      final isOnline = await _isConnected();

      if (!isOnline) {
        _syncStatusController.add(SyncStatus(
          isSyncing: false,
          message: 'Sin conexión. Los registros se sincronizarán cuando haya internet.',
          offlineMode: true,
        ));
        return;
      }

      _syncStatusController.add(SyncStatus(
        isSyncing: true,
        message: 'Sincronizando registros de despliegue pendientes...',
      ));

      // Obtener registros de despliegue no sincronizados
      final registrosPendientes = await _databaseService.obtenerRegistrosDespliegueNoSincronizados();

      if (registrosPendientes.isEmpty) {
        _syncStatusController.add(SyncStatus(
          isSyncing: false,
          message: 'Todos los registros de despliegue están sincronizados',
          success: true,
        ));
        return;
      }

      int sincronizadosCount = 0;
      int falladosCount = 0;

      for (final registro in registrosPendientes) {
        try {
          final registroMap = registro.toApiMap();
          final enviado = await _apiService!.enviarRegistroDespliegue(registroMap);

          if (enviado) {
            // ✅ ELIMINAR el registro local después de sincronizar exitosamente
            await _databaseService.eliminarRegistroDespliegue(registro.id!);
            sincronizadosCount++;
          } else {
            falladosCount++;
          }
        } catch (e) {
          print('Error sincronizando registro ${registro.id}: $e');
          falladosCount++;
        }
      }

      final message = falladosCount > 0
          ? 'Se sincronizaron $sincronizadosCount registros. $falladosCount fallaron.'
          : 'Se sincronizaron $sincronizadosCount registros exitosamente.';

      _syncStatusController.add(SyncStatus(
        isSyncing: false,
        message: message,
        success: falladosCount == 0,
        syncedCount: sincronizadosCount,
      ));
    } catch (e) {
      print('Error durante la sincronización de registros de despliegue: $e');
      _syncStatusController.add(SyncStatus(
        isSyncing: false,
        message: 'Error durante la sincronización: $e',
        success: false,
      ));
    } finally {
      _isSyncing = false;
    }
  }

  Future<Map<String, dynamic>> _sendReporteConGeolocalizacionToServer({
    required Map<String, dynamic> reporteData,
    required Map<String, dynamic> despliegueData,
  }) async {
    try {
      _syncStatusController.add(SyncStatus(
        isSyncing: true,
        message: 'Enviando reporte con geolocalización...',
      ));

      // ✅ CORREGIDO: Sin parámetro accessToken
      final reporteResponse = await _apiService!.enviarReporteDiario(reporteData);

      // ✅ CORREGIDO: Para enviarRegistroDespliegue que retorna bool
      final despliegueEnviado = await _apiService!.enviarRegistroDespliegue(despliegueData);

      // ✅ CORREGIDO: Verificación correcta para bool
      if (reporteResponse['success'] == true && despliegueEnviado == true) {
        _syncStatusController.add(SyncStatus(
          isSyncing: false,
          message: 'Reporte y geolocalización enviados exitosamente',
          success: true,
        ));

        return {
          'success': true,
          'message': 'Reporte y geolocalización enviados al servidor',
          'saved_locally': false,
        };
      } else {
        // Si falla alguno, guardar ambos localmente
        return await _saveReporteConGeolocalizacionLocally(
          reporteData: reporteData,
          despliegueData: despliegueData,
        );
      }
    } catch (e) {
      print('Error al enviar reporte con geolocalización: $e');
      // Fallback: guardar localmente
      return await _saveReporteConGeolocalizacionLocally(
        reporteData: reporteData,
        despliegueData: despliegueData,
      );
    }
  }
  Future<Map<String, dynamic>> _saveReporteConGeolocalizacionLocally({
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
        destino: despliegueData['destino'],
        latitud: despliegueData['latitud_despliegue'],
        longitud: despliegueData['longitud_despliegue'],
        estado: despliegueData['estado'],
        sincronizar: despliegueData['sincronizar'],
        observaciones: despliegueData['observaciones'],
        incidencias: despliegueData['incidencias'] ?? '',
        fechaHora: despliegueData['fecha_hora_salida'],
        operadorId: despliegueData['operador'],
      );

      final despliegueId = await _databaseService.insertRegistroDespliegue(registroDespliegue);

      _syncStatusController.add(SyncStatus(
        isSyncing: false,
        message: 'Reporte y geolocalización guardados localmente. Se sincronizarán cuando haya conexión.',
        success: true,
        offlineMode: true,
      ));

      return {
        'success': true,
        'message': 'Reporte y geolocalización guardados localmente. Se sincronizarán cuando haya conexión.',
        'local_reporte_id': reporteId,
        'local_despliegue_id': despliegueId,
        'saved_locally': true,
      };
    } catch (e) {
      print('Error al guardar reporte con geolocalización localmente: $e');
      throw Exception('Error al guardar reporte con geolocalización localmente: $e');
    }
  }

  // En tu archivo reporte_sync_service.dart, agrega estos métodos:

  /// Guardar reporte diario con geolocalización
// En ReporteSyncService, actualiza el método saveReporteGeolocalizacion
  Future<Map<String, dynamic>> saveReporteGeolocalizacion({
    required Map<String, dynamic> reporteData,
    required Map<String, dynamic> despliegueData,
  }) async {
    try {
      final isOnline = await _isConnected();

      if (isOnline) {
        // Enviar ambos directamente al servidor
        return await _sendReporteGeolocalizacionToServer(
          reporteData: reporteData,
          despliegueData: despliegueData,
        );
      } else {
        // ✅ GUARDAR AMBOS LOCALMENTE PARA SINCRONIZACIÓN POSTERIOR
        return await _saveReporteGeolocalizacionLocally(
          reporteData: reporteData,
          despliegueData: despliegueData,
        );
      }
    } catch (e) {
      // Fallback: guardar localmente si falla el envío
      return await _saveReporteGeolocalizacionLocally(
        reporteData: reporteData,
        despliegueData: despliegueData,
      );
    }
  }

  Future<Map<String, dynamic>> _sendReporteGeolocalizacionToServer({
    required Map<String, dynamic> reporteData,
    required Map<String, dynamic> despliegueData,
  }) async {
    try {
      _syncStatusController.add(SyncStatus(
        isSyncing: true,
        message: 'Enviando reporte con geolocalización...',
      ));

      // ✅ CORREGIDO: Sin parámetro accessToken
      final reporteResponse = await _apiService!.enviarReporteDiario(reporteData);

      // ✅ CORREGIDO: Para enviarRegistroDespliegue que retorna bool
      final despliegueEnviado = await _apiService!.enviarRegistroDespliegue(despliegueData);

      // ✅ CORREGIDO: Verificación correcta para bool
      if (reporteResponse['success'] == true && despliegueEnviado == true) {
        _syncStatusController.add(SyncStatus(
          isSyncing: false,
          message: 'Reporte y geolocalización enviados exitosamente',
          success: true,
        ));

        return {
          'success': true,
          'message': 'Reporte y geolocalización enviados al servidor',
          'saved_locally': false,
        };
      } else {
        // Si falla alguno, guardar ambos localmente
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
      // Fallback: guardar localmente
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
        destino: despliegueData['destino'],
        latitud: despliegueData['latitud_despliegue'],
        longitud: despliegueData['longitud_despliegue'],
        estado: despliegueData['estado'],
        sincronizar: despliegueData['sincronizar'],
        observaciones: despliegueData['observaciones'],
        incidencias: despliegueData['incidencias'] ?? '',
        fechaHora: despliegueData['fecha_hora_salida'],
        operadorId: despliegueData['operador'],
      );

      final despliegueId = await _databaseService.insertRegistroDespliegue(registroDespliegue);

      _syncStatusController.add(SyncStatus(
        isSyncing: false,
        message: 'Reporte y geolocalización guardados localmente. Se sincronizarán cuando haya conexión.',
        success: true,
        offlineMode: true,
      ));

      return {
        'success': true,
        'message': 'Reporte y geolocalización guardados localmente. Se sincronizarán cuando haya conexión.',
        'local_reporte_id': reporteId,
        'local_despliegue_id': despliegueId,
        'saved_locally': true,
      };
    } catch (e) {
      print('Error al guardar reporte con geolocalización localmente: $e');
      throw Exception('Error al guardar reporte con geolocalización localmente: $e');
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