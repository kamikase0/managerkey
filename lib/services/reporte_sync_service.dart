import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:manager_key/services/connectivity_service.dart';
import 'package:sqflite/sqflite.dart';

import '../../config/enviroment.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

// --- ENUMS Y CLASES DE MODELO ---

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

class SyncState {
  final bool hasPendingSync;
  final int pendingReports;
  final int? pendingDeployments;
  final bool offlineMode;
  final bool isSyncing;
  final bool success;

  SyncState({
    required this.hasPendingSync,
    required this.pendingReports,
    this.pendingDeployments,
    this.offlineMode = false,
    this.isSyncing = false,
    this.success = true,
  });
}

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

// --- SERVICIO DE SINCRONIZACIÓN ---

class ReporteSyncService extends ChangeNotifier {
  final DatabaseService _databaseService;
  final ConnectivityService _connectivityService;
  late ApiService _apiService;
  String? _accessToken;

  ReporteSyncService({
    required DatabaseService databaseService,
    required ConnectivityService connectivityService,
  })  : _databaseService = databaseService,
        _connectivityService = connectivityService {
    print('✅ ReporteSyncService instanciado con sus dependencias.');
    _initializeService();
  }

  // Variables de estado
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
  Timer? _autoSyncTimer; // Esta es la variable correcta para el temporizador
  bool _offlineMode = false;
  bool _apiServiceReady = false;

  // Streams públicos
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<int> get pendingCountStream => _pendingCountController.stream;
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

  // Inicialización del servicio
  Future<void> _initializeService() async {
    if (_isInitialized) return;

    try {
      await _databaseService.ensureTablesCreated();
      _isInitialized = true;
      await _iniciarMonitorConexion();
      _iniciarSincronizacionAutomatica();
      await _actualizarConteoPendientes();
      print('✅ ReporteSyncService inicializado correctamente');
    } catch (e) {
      print('❌ Error inicializando ReporteSyncService: $e');
    }
  }

  Future<void> initialize({String? accessToken}) async {
    try {
      if (accessToken != null && accessToken.isNotEmpty) {
        _apiService = ApiService(accessToken: accessToken);
        _apiServiceReady = true;
        print('✅ ApiService inicializado con token en ReporteSyncService');
        // Intenta una sincronización inmediata si hay conexión
        sincronizarReportes();
      } else {
        print('⚠️ Token de acceso no disponible - sincronización solo local');
        _apiServiceReady = false;
      }
    } catch (e) {
      print('❌ Error inicializando ApiService: $e');
      _apiServiceReady = false;
    }
  }

  Future<void> _iniciarMonitorConexion() async {
    _connectivitySubscription = _connectivityService.connectivityStream.listen(
          (result) async {
        print('📡 Cambio de conectividad detectado: $result');
        _offlineMode = result == ConnectivityResult.none;

        if (!_offlineMode && _apiServiceReady) {
          print('✅ Conexión disponible - iniciando sincronización automática');
          await Future.delayed(const Duration(seconds: 2));
          await sincronizarReportes();
        }
      },
    );
  }

  void _iniciarSincronizacionAutomatica(
      {Duration interval = const Duration(minutes: 5)}) { // Intervalo más razonable
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(interval, (timer) {
      if (_apiServiceReady && !_isSyncing) {
        print('⏰ Timer: Disparando sincronización automática periódica...');
        sincronizarReportes();
      }
    });
  }

  // Guardar reporte localmente o enviar si hay conexión
  Future<Map<String, dynamic>> saveReporteGeolocalizacion({
    required Map<String, dynamic> reporteData,
    required Map<String, dynamic> despliegueData,
  }) async {
    final tieneInternet = await _verificarConexion();

    print('═══════════════════════════════════════════════════════════');
    print('🔤 PROCESANDO REPORTE DIARIO');
    print('═══════════════════════════════════════════════════════════');
    print('🌐 ¿Tiene internet?: $tieneInternet');
    print('🌐 ¿ApiService listo?: $_apiServiceReady');

    if (tieneInternet && _apiServiceReady) {
      try {
        await _enviarReporteYDespliegueOnline(reporteData, despliegueData);
        return {
          'success': true,
          'message': 'Reporte enviado al servidor',
          'saved_locally': false
        };
      } catch (e) {
        print('⚠️ Falló el envío online, guardando localmente. Error: $e');
        await _guardarReporteLocalmente(reporteData, despliegueData);
        return {
          'success': true,
          'message': 'Falló el envío, reporte guardado localmente',
          'saved_locally': true
        };
      }
    } else {
      print('🔌 Sin conexión o sin ApiService, guardando reporte localmente.');
      await _guardarReporteLocalmente(reporteData, despliegueData);
      return {
        'success': true,
        'message': 'Reporte guardado localmente',
        'saved_locally': true
      };
    }
  }

  Future<void> _enviarReporteYDespliegueOnline(
      Map<String, dynamic> reporteData,
      Map<String, dynamic> despliegueData,
      ) async {
    if (!_apiServiceReady) {
      throw Exception('ApiService no está listo');
    }

    final reporteResult = await _apiService.enviarReporteDiario(reporteData);
    if (!reporteResult['success']) {
      throw Exception('Error al enviar reporte diario: ${reporteResult['message']}');
    }

    if (despliegueData['latitud'] != null && despliegueData['longitud'] != null) {
      final despliegueResult = await _apiService.enviarRegistroDespliegue(despliegueData);
      if (!despliegueResult) {
        // No lanzamos excepción para no revertir el guardado, pero sí lo registramos
        print('⚠️ Error al enviar despliegue, pero el reporte principal se envió.');
      }
    }
  }

  Future<void> _guardarReporteLocalmente(
      Map<String, dynamic> reporteData,
      Map<String, dynamic> despliegueData,
      ) async {
    if (!_isInitialized) {
      throw Exception('Base de datos no inicializada');
    }

    try {
      final db = await _databaseService.database;
      await db.insert(
        'reportes_pendientes',
        {
          'reporte_data': jsonEncode(reporteData),
          'despliegue_data': jsonEncode(despliegueData),
          'fecha_creacion': DateTime.now().toIso8601String(),
          'sincronizado': 0,
          'intentos': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ Reporte guardado localmente');
      await _actualizarConteoPendientes();
    } catch (e) {
      print('❌ Error guardando reporte localmente: $e');
      rethrow;
    }
  }

  // Sincronización de reportes pendientes
  Future<void> sincronizarReportes({ApiService? apiService}) async {
    if (_isSyncing) {
      print('⏳ Sincronización ya en progreso');
      return;
    }

    if (!_apiServiceReady && apiService == null) {
      print('⚠️ ApiService no disponible, saltando sincronización');
      return;
    }

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);
    notifyListeners(); // Notificar que la sincronización ha comenzado

    try {
      final hasConnection = await _verificarConexion();
      if (!hasConnection) {
        print('❌ No hay conexión a internet');
        _syncStatusController.add(SyncStatus.pending);
        return;
      }

      final serviceToUse = apiService ?? _apiService;

      final db = await _databaseService.database;
      final reportesPendientes = await db.query(
        'reportes_pendientes',
        where: 'sincronizado = ?',
        whereArgs: [0],
      );

      if (reportesPendientes.isEmpty) {
        print('✅ No hay reportes pendientes');
        _syncStatusController.add(SyncStatus.synced);
        return;
      }

      print('📄 Sincronizando ${reportesPendientes.length} reportes...');
      int sincronizados = 0;
      int total = reportesPendientes.length;

      for (int i = 0; i < reportesPendientes.length; i++) {
        final reporte = reportesPendientes[i];
        final id = reporte['id'] as int?;
        if (id == null) continue;

        final success = await _enviarReportePendiente(reporte, serviceToUse);
        if (success) {
          sincronizados++;
          await _marcarComoSincronizado(db, id);
        } else {
          await _incrementarIntentos(db, id);
        }

        _syncProgressController.add(SyncProgress(
          actual: i + 1,
          total: total,
          porcentaje: ((i + 1) / total * 100).toInt(),
        ));
      }

      await _actualizarConteoPendientes();
      print('✅ Sincronización completada: $sincronizados/$total');
      _syncStatusController.add(SyncStatus.synced);
    } catch (e) {
      print('❌ Error durante sincronización: $e');
      _syncStatusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
      notifyListeners(); // Notificar que la sincronización ha terminado
    }
  }

  Future<bool> _enviarReportePendiente(
      Map<String, dynamic> reportePendiente,
      ApiService apiService,
      ) async {
    try {
      final reporteData = jsonDecode(reportePendiente['reporte_data'] as String);
      final despliegueData = jsonDecode(reportePendiente['despliegue_data'] as String);

      final resultReporte = await apiService.enviarReporteDiario(reporteData);
      if (!resultReporte['success']) {
        print('❌ Error sincronizando reporte: ${resultReporte['message']}');
        return false;
      }

      // Solo intentar enviar despliegue si tiene datos válidos
      if (despliegueData['latitud'] != null && despliegueData['longitud'] != null) {
        final resultDespliegue = await apiService.enviarRegistroDespliegue(despliegueData);
        if (!resultDespliegue) {
          print('⚠️ Error sincronizando despliegue, pero el reporte fue exitoso.');
          // Decidimos retornar `true` porque el reporte principal, que es el
          // más importante, se sincronizó.
        }
      }

      print('✅ Reporte ID ${reportePendiente['id']} sincronizado exitosamente');
      return true;
    } catch (e) {
      print('❌ Error fatal enviando reporte pendiente: $e');
      return false;
    }
  }

  // Estos métodos ya no son necesarios aquí si la lógica está en ApiService
  /*
  Future<void> _enviarReporteDiario(...) async { ... }
  Future<void> _enviarDespliegueReporte(...) async { ... }
  */

  // Métodos auxiliares
  Future<void> _marcarComoSincronizado(Database db, int id) async {
    await db.update(
      'reportes_pendientes',
      {'sincronizado': 1, 'ultima_tentativa': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _incrementarIntentos(Database db, int id) async {
    await db.rawUpdate(
      'UPDATE reportes_pendientes SET intentos = intentos + 1, ultima_tentativa = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  Future<void> _actualizarConteoPendientes() async {
    try {
      final count = await _contarReportesPendientes();
      if (!_pendingCountController.isClosed) {
        _pendingCountController.add(count);
      }
      print('📊 Reportes pendientes: $count');
    } catch (e) {
      print('❌ Error actualizando conteo: $e');
    }
  }

  Future<int> _contarReportesPendientes() async {
    if (!_isInitialized) return 0;
    try {
      final db = await _databaseService.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM reportes_pendientes WHERE sincronizado = 0',
      );
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      print('❌ Error contando reportes: $e');
      return 0;
    }
  }

  Future<bool> _verificarConexion() async {
    try {
      return await _connectivityService.hasInternetConnection();
    } catch (e) {
      return false;
    }
  }

  // Métodos públicos
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
        offlineMode: _offlineMode,
        isSyncing: false,
        success: false,
      );
    }
  }

  Future<SyncStats> getSyncStats() async {
    if (!_isInitialized) {
      return SyncStats(totalReportes: 0, sincronizados: 0, pendientes: 0);
    }

    try {
      final db = await _databaseService.database;
      final totalResult =
      await db.rawQuery('SELECT COUNT(*) as count FROM reportes_pendientes');
      final total = (totalResult.first['count'] as int?) ?? 0;

      final sincronizadosResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM reportes_pendientes WHERE sincronizado = 1',
      );
      final sincronizados = (sincronizadosResult.first['count'] as int?) ?? 0;

      return SyncStats(
        totalReportes: total,
        sincronizados: sincronizados,
        pendientes: total - sincronizados,
      );
    } catch (e) {
      print('❌ Error obteniendo stats: $e');
      return SyncStats(totalReportes: 0, sincronizados: 0, pendientes: 0);
    }
  }

  Future<SyncResult> syncNow() async {
    print('▶️ Iniciando sincronización manual');
    if (!_apiServiceReady) {
      return SyncResult(success: false, message: 'Servicio no listo. Inicia sesión.');
    }

    final pendientesAntes = await _contarReportesPendientes();
    if (pendientesAntes == 0) {
      return SyncResult(success: true, message: 'Sin reportes pendientes');
    }

    try {
      await sincronizarReportes();
      final pendientesDespues = await _contarReportesPendientes();
      final sincronizados = pendientesAntes - pendientesDespues;

      return SyncResult(
        success: pendientesDespues == 0,
        message: 'Sincronizados: $sincronizados de $pendientesAntes',
        syncedCount: sincronizados,
        failedCount: pendientesDespues,
      );
    } catch (e) {
      return SyncResult(success: false, message: 'Error: $e');
    }
  }

  Future<List<dynamic>> getReportes() async {
    if (!_isInitialized) return [];

    try {
      final db = await _databaseService.database;
      final reportes = await db.query('reportes_pendientes', orderBy: 'id DESC');
      return reportes
          .map((r) {
        final reporteData = jsonDecode(r['reporte_data'] as String);
        reporteData['id_local'] = r['id'];
        reporteData['synced'] = (r['sincronizado'] == 1);
        reporteData['attempts'] = r['intentos'];
        reporteData['last_attempt'] = r['ultima_tentativa'];
        return reporteData;
      }).toList();
    } catch (e) {
      print('❌ Error obteniendo reportes: $e');
      return [];
    }
  }

  Future<void> limpiarReportesSincronizados() async {
    try {
      final db = await _databaseService.database;
      final count = await db.delete('reportes_pendientes', where: 'sincronizado = ?', whereArgs: [1]);
      await _actualizarConteoPendientes();
      print('🧹 $count reportes sincronizados han sido limpiados');
    } catch (e) {
      print('❌ Error limpiando reportes: $e');
    }
  }

  // ✅ CORRECCIÓN: Nuevo método para detener el temporizador
  /// Detiene la sincronización automática periódica.
  /// Útil al cerrar sesión para evitar que el servicio siga intentando sincronizar.
  void stopSync() {
    print('🛑 Deteniendo el temporizador de sincronización automática...');
    // ✅ CORRECCIÓN: Se usa _autoSyncTimer, que es la variable correcta.
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    print('✅ Temporizador de sincronización detenido.');
  }

  // ✅ CORRECCIÓN: Método `dispose` único y corregido.
  @override
  void dispose() {
    print('🧹 Limpiando recursos de ReporteSyncService...');
    // Detiene el temporizador automático
    stopSync();

    // Cancela la suscripción a los cambios de conectividad
    _connectivitySubscription?.cancel();

    // Cierra todos los StreamControllers para evitar fugas de memoria
    _syncStatusController.close();
    _pendingCountController.close();
    _syncProgressController.close();

    print('✅ ReporteSyncService limpiado correctamente.');
    super.dispose();
  }
}




// import 'dart:async';
// import 'dart:convert';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:http/http.dart' as http;
// import 'package:manager_key/services/connectivity_service.dart';
// import 'package:sqflite/sqflite.dart';
//
// import '../../config/enviroment.dart';
// import '../services/api_service.dart';
// import '../services/auth_service.dart';
// import '../services/database_service.dart';
//
// // --- ENUMS Y CLASES DE MODELO ---
//
// enum SyncStatus { synced, syncing, pending, error }
//
// class SyncProgress {
//   final int actual;
//   final int total;
//   final int porcentaje;
//
//   SyncProgress({
//     required this.actual,
//     required this.total,
//     required this.porcentaje,
//   });
// }
//
// class SyncStats {
//   final int totalReportes;
//   final int sincronizados;
//   final int pendientes;
//
//   SyncStats({
//     required this.totalReportes,
//     required this.sincronizados,
//     required this.pendientes,
//   });
//
//   double get porcentajeSincronizado {
//     if (totalReportes == 0) return 100;
//     return (sincronizados / totalReportes * 100);
//   }
// }
//
// class SyncState {
//   final bool hasPendingSync;
//   final int pendingReports;
//   final int? pendingDeployments;
//   final bool offlineMode;
//   final bool isSyncing;
//   final bool success;
//
//   SyncState({
//     required this.hasPendingSync,
//     required this.pendingReports,
//     this.pendingDeployments,
//     this.offlineMode = false,
//     this.isSyncing = false,
//     this.success = true,
//   });
// }
//
// class SyncResult {
//   final bool success;
//   final String message;
//   final int syncedCount;
//   final int failedCount;
//
//   SyncResult({
//     required this.success,
//     required this.message,
//     this.syncedCount = 0,
//     this.failedCount = 0,
//   });
// }
//
// // --- SERVICIO DE SINCRONIZACIÓN ---
//
// class ReporteSyncService extends ChangeNotifier {
//   final DatabaseService _databaseService;
//   final ConnectivityService _connectivityService;
//   //final AuthService _authService;
//   late ApiService _apiService;
//   String? _accessToken;
//
//   ReporteSyncService({
//     required DatabaseService databaseService,
//     required ConnectivityService connectivityService,
//     // Puedes inyectar AuthService también si lo necesitas desde el principio.
//     // required AuthService authService,
//   })  : _databaseService = databaseService,
//         _connectivityService = connectivityService
//   // _authService = authService
//   {
//     print('✅ ReporteSyncService instanciado con sus dependencias (vía constructor nombrado).');
//     _initializeService();
//   }
//
//   // Variables de estado
//   final Connectivity _connectivity = Connectivity();
//   StreamSubscription? _connectivitySubscription;
//
//   final StreamController<SyncStatus> _syncStatusController =
//   StreamController<SyncStatus>.broadcast();
//   final StreamController<int> _pendingCountController =
//   StreamController<int>.broadcast();
//   final StreamController<SyncProgress> _syncProgressController =
//   StreamController<SyncProgress>.broadcast();
//
//   bool _isInitialized = false;
//   bool _isSyncing = false;
//   Timer? _autoSyncTimer;
//   bool _offlineMode = false;
//   bool _apiServiceReady = false;
//
//   // Streams públicos
//   Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
//   Stream<int> get pendingCountStream => _pendingCountController.stream;
//   Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;
//
//   // Inicialización del servicio
//   Future<void> _initializeService() async {
//     if (_isInitialized) return;
//
//     try {
//       await _databaseService.ensureTablesCreated();
//       _isInitialized = true;
//       await _iniciarMonitorConexion();
//       _iniciarSincronizacionAutomatica();
//       await _actualizarConteoPendientes();
//       print('✅ ReporteSyncService inicializado correctamente');
//     } catch (e) {
//       print('❌ Error inicializando ReporteSyncService: $e');
//     }
//   }
//
//   // ✅ NUEVO: Inicializar ApiService cuando hay token disponible
//   Future<void> initialize({String? accessToken}) async {
//     try {
//       if (accessToken != null && accessToken.isNotEmpty) {
//         _apiService = ApiService(accessToken: accessToken);
//         _apiServiceReady = true;
//         print('✅ ApiService inicializado con token en ReporteSyncService');
//       } else {
//         print('⚠️ Token de acceso no disponible - sincronización solo local');
//         _apiServiceReady = false;
//       }
//     } catch (e) {
//       print('❌ Error inicializando ApiService: $e');
//       _apiServiceReady = false;
//     }
//   }
//
//   Future<void> _iniciarMonitorConexion() async {
//     _connectivitySubscription = _connectivityService.connectivityStream.listen( // Usa el servicio inyectado
//           (result) async {
//         print('📡 Cambio de conectividad detectado: $result');
//         _offlineMode = result == ConnectivityResult.none;
//
//         if (!_offlineMode && _apiServiceReady) {
//           print('✅ Conexión disponible - iniciando sincronización automática');
//           await Future.delayed(const Duration(seconds: 2));
//           await sincronizarReportes(); // Usas el nombre de tu método
//         }
//       },
//     );
//   }
//
//   void _iniciarSincronizacionAutomatica(
//       {Duration interval = const Duration(seconds: 30)}) {
//     _autoSyncTimer?.cancel();
//     _autoSyncTimer = Timer.periodic(interval, (timer) {
//       // ✅ SOLO intentar si hay ApiService listo
//       if (_apiServiceReady && !_isSyncing) {
//         print('⏰ Timer: Disparando sincronización automática periódica...');
//         sincronizarReportes();
//       }
//     });
//   }
//
//   // Guardar reporte localmente o enviar si hay conexión
//   Future<Map<String, dynamic>> saveReporteGeolocalizacion({
//     required Map<String, dynamic> reporteData,
//     required Map<String, dynamic> despliegueData,
//   }) async {
//     final tieneInternet = await _verificarConexion();
//
//     print('═══════════════════════════════════════════════════════════');
//     print('🔤 PROCESANDO REPORTE DIARIO');
//     print('═══════════════════════════════════════════════════════════');
//     print('🌐 ¿Tiene internet?: $tieneInternet');
//     print('🌐 ¿ApiService listo?: $_apiServiceReady');
//
//     if (tieneInternet && _apiServiceReady) {
//       try {
//         await _enviarReporteYDespliegueOnline(reporteData, despliegueData);
//         return {
//           'success': true,
//           'message': 'Reporte enviado al servidor',
//           'saved_locally': false
//         };
//       } catch (e) {
//         print('⚠️ Falló el envío online, guardando localmente. Error: $e');
//         await _guardarReporteLocalmente(reporteData, despliegueData);
//         return {
//           'success': true,
//           'message': 'Falló el envío, reporte guardado localmente',
//           'saved_locally': true
//         };
//       }
//     } else {
//       print('🔌 Sin conexión o sin ApiService, guardando reporte localmente.');
//       await _guardarReporteLocalmente(reporteData, despliegueData);
//       return {
//         'success': true,
//         'message': 'Reporte guardado localmente',
//         'saved_locally': true
//       };
//     }
//   }
//
//   Future<void> _enviarReporteYDespliegueOnline(
//       Map<String, dynamic> reporteData,
//       Map<String, dynamic> despliegueData,
//       ) async {
//     if (!_apiServiceReady) {
//       throw Exception('ApiService no está listo');
//     }
//
//     final accessToken = await AuthService().getAccessToken();
//     if (accessToken == null || accessToken.isEmpty) {
//       throw Exception('No se pudo obtener token de autenticación');
//     }
//
//     await _enviarReporteDiario(reporteData, accessToken);
//
//     if (despliegueData['latitud'] != null && despliegueData['longitud'] != null) {
//       await _enviarDespliegueReporte(despliegueData, accessToken);
//     }
//   }
//
//   Future<void> _guardarReporteLocalmente(
//       Map<String, dynamic> reporteData,
//       Map<String, dynamic> despliegueData,
//       ) async {
//     if (!_isInitialized) {
//       throw Exception('Base de datos no inicializada');
//     }
//
//     try {
//       final db = await _databaseService.database;
//       await db.insert(
//         'reportes_pendientes',
//         {
//           'reporte_data': jsonEncode(reporteData),
//           'despliegue_data': jsonEncode(despliegueData),
//           'fecha_creacion': DateTime.now().toIso8601String(),
//           'sincronizado': 0,
//           'intentos': 0,
//         },
//         conflictAlgorithm: ConflictAlgorithm.replace,
//       );
//       print('✅ Reporte guardado localmente');
//       await _actualizarConteoPendientes();
//     } catch (e) {
//       print('❌ Error guardando reporte localmente: $e');
//       rethrow;
//     }
//   }
//
//   // Sincronización de reportes pendientes
//   Future<void> sincronizarReportes({ApiService? apiService}) async {
//     if (_isSyncing) {
//       print('⏳ Sincronización ya en progreso');
//       return;
//     }
//
//     // ✅ SI NO HAY ApiService listo, no intentar sincronizar
//     if (!_apiServiceReady && apiService == null) {
//       print('⚠️ ApiService no disponible, saltando sincronización');
//       return;
//     }
//
//     _isSyncing = true;
//     _syncStatusController.add(SyncStatus.syncing);
//
//     try {
//       final hasConnection = await _verificarConexion();
//       if (!hasConnection) {
//         print('❌ No hay conexión a internet');
//         _syncStatusController.add(SyncStatus.pending);
//         return;
//       }
//
//       final serviceToUse = apiService ?? ((_apiServiceReady) ? _apiService : null);
//       if (serviceToUse == null) {
//         print('⚠️ No hay ApiService disponible para sincronización');
//         _syncStatusController.add(SyncStatus.error);
//         return;
//       }
//
//       final db = await _databaseService.database;
//       final reportesPendientes = await db.query(
//         'reportes_pendientes',
//         where: 'sincronizado = ?',
//         whereArgs: [0],
//       );
//
//       if (reportesPendientes.isEmpty) {
//         print('✅ No hay reportes pendientes');
//         _syncStatusController.add(SyncStatus.synced);
//         return;
//       }
//
//       print('📄 Sincronizando ${reportesPendientes.length} reportes...');
//       int sincronizados = 0;
//       int total = reportesPendientes.length;
//
//       for (int i = 0; i < reportesPendientes.length; i++) {
//         final reporte = reportesPendientes[i];
//         final id = reporte['id'] as int?;
//         if (id == null) continue;
//
//         final success = await _enviarReportePendiente(reporte, serviceToUse);
//         if (success) {
//           sincronizados++;
//           await _marcarComoSincronizado(db, id);
//         } else {
//           await _incrementarIntentos(db, id);
//         }
//
//         _syncProgressController.add(SyncProgress(
//           actual: i + 1,
//           total: total,
//           porcentaje: ((i + 1) / total * 100).toInt(),
//         ));
//       }
//
//       await _actualizarConteoPendientes();
//       print('✅ Sincronización completada: $sincronizados/$total');
//       _syncStatusController.add(SyncStatus.synced);
//     } catch (e) {
//       print('❌ Error durante sincronización: $e');
//       _syncStatusController.add(SyncStatus.error);
//     } finally {
//       _isSyncing = false;
//     }
//   }
//
//   Future<bool> _enviarReportePendiente(
//       Map<String, dynamic> reportePendiente,
//       ApiService apiService,
//       ) async {
//     try {
//       final reporteData = jsonDecode(reportePendiente['reporte_data']);
//       final despliegueData = jsonDecode(reportePendiente['despliegue_data']);
//
//       final resultReporte = await apiService.enviarReporteDiario(reporteData);
//       if (!resultReporte['success']) {
//         print('❌ Error sincronizando reporte: ${resultReporte['message']}');
//         return false;
//       }
//
//       final resultDespliegue =
//       await apiService.enviarRegistroDespliegue(despliegueData);
//       if (!resultDespliegue) {
//         print('❌ Error sincronizando despliegue');
//         return false;
//       }
//
//       print('✅ Reporte sincronizado exitosamente');
//       return true;
//     } catch (e) {
//       print('❌ Error enviando reporte: $e');
//       return false;
//     }
//   }
//
//   Future<void> _enviarReporteDiario(
//       Map<String, dynamic> reporteData,
//       String accessToken,
//       ) async {
//     final url = '${Enviroment.apiUrlDev}reportesdiarios/';
//     final jsonReporte = {
//       'fecha_reporte': reporteData['fecha_reporte'],
//       'contador_inicial_c': reporteData['contador_inicial_c'],
//       'contador_final_c': reporteData['contador_final_c'],
//       'registro_c': reporteData['registro_c'],
//       'contador_inicial_r': reporteData['contador_inicial_r'],
//       'contador_final_r': reporteData['contador_final_r'],
//       'registro_r': reporteData['registro_r'],
//       'incidencias': reporteData['incidencias'] ?? '',
//       'observaciones': reporteData['observaciones'] ?? '',
//       'estado': reporteData['estado'] ?? 'ENVIO REPORTE',
//       'sincronizar': reporteData['sincronizar'] ?? true,
//       'operador': reporteData['operador'],
//       'estacion': reporteData['estacion'],
//       'centro_empadronamiento': reporteData['centro_empadronamiento'],
//       'observacionC': reporteData['observacionC'] ?? '',
//       'observacionR': reporteData['observacionR'] ?? '',
//       'saltosenC':
//       int.tryParse(reporteData['saltosenC']?.toString() ?? '0') ?? 0,
//       'saltosenR':
//       int.tryParse(reporteData['saltosenR']?.toString() ?? '0') ?? 0,
//       'fecha_registro': DateTime.now()
//           .toLocal()
//           .toIso8601String()
//           .replaceAll('Z', ''),
//     };
//
//     final response = await http
//         .post(
//       Uri.parse(url),
//       headers: {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//         'Authorization': 'Bearer $accessToken'
//       },
//       body: jsonEncode(jsonReporte),
//     )
//         .timeout(const Duration(seconds: 30));
//
//     if (response.statusCode != 200 && response.statusCode != 201) {
//       throw Exception('Error al enviar reporte: ${response.statusCode}');
//     }
//   }
//
//   Future<void> _enviarDespliegueReporte(
//       Map<String, dynamic> despliegueData,
//       String accessToken,
//       ) async {
//     final url = '${Enviroment.apiUrlDev}registrosdespliegue/';
//     final jsonDespliegue = {
//       'latitud': double.tryParse(despliegueData['latitud'].toString()) ?? 0,
//       'longitud': double.tryParse(despliegueData['longitud'].toString()) ?? 0,
//       'descripcion_reporte': null,
//       'estado': despliegueData['estado'] ?? 'REPORTE ENVIADO',
//       'sincronizar': true,
//       'observaciones': despliegueData['observaciones'],
//       'incidencias': despliegueData['incidencias'],
//       'fecha_hora': despliegueData['fecha_hora'],
//       'operador': despliegueData['operador'],
//     };
//
//     final response = await http
//         .post(
//       Uri.parse(url),
//       headers: {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//         'Authorization': 'Bearer $accessToken'
//       },
//       body: jsonEncode(jsonDespliegue),
//     )
//         .timeout(const Duration(seconds: 20));
//
//     if (response.statusCode != 200 && response.statusCode != 201) {
//       print('⚠️ Error enviando despliegue: ${response.statusCode}');
//     }
//   }
//
//   // Métodos auxiliares
//   Future<void> _marcarComoSincronizado(Database db, int id) async {
//     await db.update(
//       'reportes_pendientes',
//       {
//         'sincronizado': 1,
//         'ultima_tentativa': DateTime.now().toIso8601String()
//       },
//       where: 'id = ?',
//       whereArgs: [id],
//     );
//   }
//
//   Future<void> _incrementarIntentos(Database db, int id) async {
//     await db.rawUpdate(
//       'UPDATE reportes_pendientes SET intentos = intentos + 1, ultima_tentativa = ? WHERE id = ?',
//       [DateTime.now().toIso8601String(), id],
//     );
//   }
//
//   Future<void> _actualizarConteoPendientes() async {
//     try {
//       final count = await _contarReportesPendientes();
//       _pendingCountController.add(count);
//       print('📊 Reportes pendientes: $count');
//     } catch (e) {
//       print('❌ Error actualizando conteo: $e');
//     }
//   }
//
//   Future<int> _contarReportesPendientes() async {
//     if (!_isInitialized) return 0;
//     try {
//       final db = await _databaseService.database;
//       final result = await db.rawQuery(
//         'SELECT COUNT(*) as count FROM reportes_pendientes WHERE sincronizado = 0',
//       );
//       return (result.first['count'] as int?) ?? 0;
//     } catch (e) {
//       print('❌ Error contando reportes: $e');
//       return 0;
//     }
//   }
//
//   Future<bool> _verificarConexion() async {
//     try {
//
//       return await _connectivityService.hasInternetConnection();
//     } catch (e) {
//       return false;
//     }
//   }
//
//   // Métodos públicos
//   Future<SyncState> getSyncState() async {
//     try {
//       final pendientes = await _contarReportesPendientes();
//       return SyncState(
//         hasPendingSync: pendientes > 0,
//         pendingReports: pendientes,
//         pendingDeployments: 0,
//         offlineMode: _offlineMode,
//         isSyncing: _isSyncing,
//         success: true,
//       );
//     } catch (e) {
//       return SyncState(
//         hasPendingSync: false,
//         pendingReports: 0,
//         offlineMode: _offlineMode,
//         isSyncing: false,
//         success: false,
//       );
//     }
//   }
//
//   Future<SyncStats> getSyncStats() async {
//     if (!_isInitialized) {
//       return SyncStats(totalReportes: 0, sincronizados: 0, pendientes: 0);
//     }
//
//     try {
//       final db = await _databaseService.database;
//       final totalResult =
//       await db.rawQuery('SELECT COUNT(*) as count FROM reportes_pendientes');
//       final total = (totalResult.first['count'] as int?) ?? 0;
//
//       final sincronizadosResult = await db.rawQuery(
//         'SELECT COUNT(*) as count FROM reportes_pendientes WHERE sincronizado = 1',
//       );
//       final sincronizados = (sincronizadosResult.first['count'] as int?) ?? 0;
//
//       return SyncStats(
//         totalReportes: total,
//         sincronizados: sincronizados,
//         pendientes: total - sincronizados,
//       );
//     } catch (e) {
//       print('❌ Error obteniendo stats: $e');
//       return SyncStats(totalReportes: 0, sincronizados: 0, pendientes: 0);
//     }
//   }
//
//   Future<SyncResult> syncNow() async {
//     print('▶️ Iniciando sincronización manual');
//
//     if (!_apiServiceReady) {
//       return SyncResult(
//         success: false,
//         message: 'ApiService no está disponible. Inicia sesión primero.',
//       );
//     }
//
//     final pendientesAntes = await _contarReportesPendientes();
//     if (pendientesAntes == 0) {
//       return SyncResult(
//         success: true,
//         message: 'Sin reportes pendientes',
//       );
//     }
//
//     try {
//       await sincronizarReportes();
//       final pendientesDespues = await _contarReportesPendientes();
//       final sincronizados = pendientesAntes - pendientesDespues;
//
//       return SyncResult(
//         success: pendientesDespues == 0,
//         message: 'Sincronizados: $sincronizados',
//         syncedCount: sincronizados,
//       );
//     } catch (e) {
//       return SyncResult(
//         success: false,
//         message: 'Error: $e',
//       );
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getReportes() async {
//     if (!_isInitialized) return [];
//
//     try {
//       final db = await _databaseService.database;
//       final reportes = await db.query('reportes_pendientes');
//       return reportes
//           .map((r) {
//         final reporteData = jsonDecode(r['reporte_data'] as String);
//         reporteData['synced'] = (r['sincronizado'] == 1);
//         return reporteData as Map<String, dynamic>;
//       })
//           .toList();
//     } catch (e) {
//       print('❌ Error obteniendo reportes: $e');
//       return [];
//     }
//   }
//
//   Future<void> limpiarReportesSincronizados() async {
//     try {
//       final db = await _databaseService.database;
//       await db.delete('reportes_pendientes', where: 'sincronizado = ?', whereArgs: [1]);
//       await _actualizarConteoPendientes();
//       print('🧹 Reportes sincronizados limpiados');
//     } catch (e) {
//       print('❌ Error limpiando: $e');
//     }
//   }
//
//   @override
//   void dispose() {
//     _connectivitySubscription?.cancel();
//     _autoSyncTimer?.cancel();
//     _syncStatusController.close();
//     _pendingCountController.close();
//     _syncProgressController.close();
//     super.dispose();
//   }
//
//   // ✅ AGREGAR ESTE MÉTODO A TU ReporteSyncService
//
//   /// Detener la sincronización
//   void stopSync() {
//     print('🛑 Deteniendo sincronización...');
//     _syncTimer?.cancel();
//     _syncTimer = null;
//     print('✅ Sincronización detenida');
//   }
//
//   /// Limpiar recursos
//   void dispose() {
//     print('🧹 Limpiando ReporteSyncService...');
//     stopSync();
//     // Limpiar cualquier otro recurso
//     print('✅ ReporteSyncService limpio');
//   }
// }