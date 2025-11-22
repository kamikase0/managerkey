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
  ApiService? _apiService;

  ReporteSyncService({
    required DatabaseService databaseService,
  }) : _databaseService = databaseService;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  Future<void> initialize({required String accessToken}) async {
    _accessToken = accessToken;
    _apiService = ApiService(accessToken: accessToken);
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
      _syncStatusController.add(SyncStatus(
        isSyncing: true,
        message: 'Enviando reporte al servidor...',
      ));

      final response = await _apiService!.enviarReporteDiario(reporteData);

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
      final registrosDesplieguePendientes = await _databaseService.obtenerRegistrosDespliegueNoSincronizados();
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

  Future<void> _syncReporte(Map<String, dynamic> reporte) async {
    final dataToSend = Map<String, dynamic>.from(reporte)
      ..removeWhere((key, value) =>
          ['id', 'synced', 'updated_at'].contains(key));

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

  Future<void> _syncRegistroDespliegue(RegistroDespliegue registro) async {
    final registroMap = registro.toApiMap();
    final enviado = await _apiService!.enviarRegistroDespliegue(registroMap);

    if (!enviado) {
      throw Exception('Error al sincronizar registro de despliegue');
    }

    await _databaseService.eliminarRegistroDespliegue(registro.id!);
  }

  /// Guardar reporte con geolocalización (método unificado)
  Future<Map<String, dynamic>> saveReporteGeolocalizacion({
    required Map<String, dynamic> reporteData,
    required Map<String, dynamic> despliegueData,
  }) async {
    try {
      final isOnline = await _isConnected();

      if (isOnline) {
        return await _sendReporteGeolocalizacionToServer(
          reporteData: reporteData,
          despliegueData: despliegueData,
        );
      } else {
        return await _saveReporteGeolocalizacionLocally(
          reporteData: reporteData,
          despliegueData: despliegueData,
        );
      }
    } catch (e) {
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

      final reporteResponse = await _apiService!.enviarReporteDiario(reporteData);
      final despliegueEnviado = await _apiService!.enviarRegistroDespliegue(despliegueData);

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
      final count = await _databaseService.deleteSyncedReportesByOperador(operadorId);
      if (count > 0) {
        print('🧹 Limpieza completada: Se eliminaron $count reportes locales ya sincronizados para el operador $operadorId.');
      }
    } catch (e) {
      print('❌ Error durante la limpieza de reportes locales sincronizados: $e');
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