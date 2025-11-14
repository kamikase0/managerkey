

import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'dart:async';

class ReporteSyncService {
  final DatabaseService _databaseService;
  final ApiService _apiService;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription? _connectivitySubscription;
  Timer? _syncTimer;
  bool _isSyncing = false;
  String? _accessToken;

  ReporteSyncService({
    required DatabaseService databaseService,
    required ApiService apiService,
  })  : _databaseService = databaseService,
        _apiService = apiService;

  // Stream para notificar cambios en el estado de sincronización
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  Future<void> initialize({required String accessToken}) async {
    _accessToken = accessToken;
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
  Future<Map<String, dynamic>> saveReporte(
      Map<String, dynamic> reporteData,
      ) async {
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

      final response = await _apiService.enviarReporteDiario(
        reporteData,
        accessToken: _accessToken ?? '',
      );

      if (response['success']) {
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
    if (_isSyncing) return;

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
          : 'Se sincronizaron $syncedCount reportes exitosamente.';

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
    // Preparar datos para envío (remover campos de BD local)
    final dataToSend = Map<String, dynamic>.from(reporte)
      ..removeWhere((key, value) =>
          ['id', 'synced', 'updated_at'].contains(key));

    final response = await _apiService.enviarReporteDiario(
      dataToSend,
      accessToken: _accessToken ?? '',
    );

    if (!response['success']) {
      throw Exception('Error al sincronizar reporte: ${response['message']}');
    }

    // Marcar como sincronizado
    await _databaseService.markReporteAsSynced(reporte['id']);
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