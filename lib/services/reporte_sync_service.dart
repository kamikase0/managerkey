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

  /// Iniciar sincronización automática cada 30 segundos
  void _iniciarSincronizacionAutomatica() {
    _autoSyncTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) async {
        if (!_isSyncing && _isInitialized && !_offlineMode) {
          final hasConnection = await _verificarConexion();
          if (hasConnection) {
            final pendientes = await _contarReportesPendientes();
            if (pendientes > 0) {
              print('⏰ Sincronización automática programada');
              await sincronizarReportes(apiService: _apiService);
            }
          }
        }
      },
    );
  }

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