import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../../config/enviroment.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart'; // Asegúrate de que este import sea correcto

// --- ENUMS Y CLASES DE MODELO PARA EL SERVICIO ---

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

// --- SERVICIO DE SINCRONIZACIÓN DE REPORTES ---

class ReporteSyncService {
  static final ReporteSyncService _instance = ReporteSyncService._internal();

  factory ReporteSyncService() => _instance;

  ReporteSyncService._internal();

  // --- VARIABLES DE ESTADO Y CONTROLADORES ---

  late Database _db;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;

  final StreamController<SyncStatus> _syncStatusController = StreamController<SyncStatus>.broadcast();
  final StreamController<int> _pendingCountController = StreamController<int>.broadcast();
  final StreamController<SyncProgress> _syncProgressController = StreamController<SyncProgress>.broadcast();

  bool _isInitialized = false;
  bool _isSyncing = false;
  Timer? _autoSyncTimer;
  ApiService? _apiService;
  bool _offlineMode = false;

  // --- STREAMS PÚBLICOS ---

  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<int> get pendingCountStream => _pendingCountController.stream;
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

  // --- MÉTODOS DE INICIALIZACIÓN Y CONFIGURACIÓN ---

  Future<void> initialize({String? accessToken}) async {
    try {
      if (accessToken != null) {
        _apiService = ApiService(accessToken: accessToken);
        print('✅ ApiService inicializado con token en ReporteSyncService');
      }
    } catch (e) {
      print('⚠️ Error inicializando ApiService en ReporteSyncService: $e');
    }
  }

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

    // Asumimos que la tabla reportes_diarios ya existe desde DatabaseService
    // Si no es así, debes crearla aquí o en DatabaseService.

    _isInitialized = true;
    await _iniciarMonitorConexion();
    _iniciarSincronizacionAutomatica();
    print('✅ ReporteSyncService inicializado correctamente');
  }

  Future<void> _iniciarMonitorConexion() async {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
          (result) async {
        print('📡 Cambio de conectividad detectado: $result');
        _offlineMode = result != ConnectivityResult.none;

        if (!_offlineMode) {
          print('✅ Conexión disponible - iniciando sincronización automática');
          await Future.delayed(const Duration(seconds: 2));
          await sincronizarReportes(apiService: _apiService);
        }
      },
    );
  }

  void _iniciarSincronizacionAutomatica({Duration interval = const Duration(minutes: 15)}) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(interval, (timer) {
      print('⏰ Timer: Disparando sincronización automática periódica...');
      sincronizarReportes(apiService: _apiService);
    });
  }

  // --- LÓGICA PRINCIPAL DE GUARDADO Y ENVÍO ---

  Future<Map<String, dynamic>> saveReporteGeolocalizacion({
    required Map<String, dynamic> reporteData,
    required Map<String, dynamic> despliegueData,
  }) async {
    final tieneInternet = await _verificarConexion();

    print('═══════════════════════════════════════════════════════════');
    print('📤 PROCESANDO REPORTE DIARIO');
    print('═══════════════════════════════════════════════════════════');
    print('🌐 ¿Tiene internet?: $tieneInternet');
    print('📋 Datos del reporte: ${jsonEncode(reporteData)}');
    print('📍 Datos de despliegue: ${jsonEncode(despliegueData)}');

    if (tieneInternet) {
      try {
        await _enviarReporteYDespliegueOnline(reporteData, despliegueData);
        return {'success': true, 'message': 'Reporte enviado al servidor', 'saved_locally': false};
      } catch (e) {
        print('⚠️ Falló el envío online, guardando localmente. Error: $e');
        await _guardarReporteLocalmente(reporteData, despliegueData);
        return {'success': true, 'message': 'Falló el envío, reporte guardado localmente', 'saved_locally': true};
      }
    } else {
      print('🔌 Sin conexión, guardando reporte localmente.');
      await _guardarReporteLocalmente(reporteData, despliegueData);
      return {'success': true, 'message': 'Sin conexión, reporte guardado localmente', 'saved_locally': true};
    }
  }

  Future<void> _enviarReporteYDespliegueOnline(
      Map<String, dynamic> reporteData,
      Map<String, dynamic> despliegueData,
      ) async {
    final accessToken = await AuthService().getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('No se pudo obtener token de autenticación');
    }

    // 1. Enviar el reporte diario
    await _enviarReporteDiario(reporteData, accessToken);

    // 2. Enviar el registro de despliegue asociado
    if (despliegueData['latitud'] != null && despliegueData['longitud'] != null) {
      await _enviarDespliegueReporte(despliegueData, accessToken);
    }
  }

  Future<void> _guardarReporteLocalmente(
      Map<String, dynamic> reporteData,
      Map<String, dynamic> despliegueData,
      ) async {
    if (!_isInitialized) {
      throw Exception('La base de datos no está inicializada para guardar localmente.');
    }

    // Guardar en la tabla de reportes pendientes
    await _db.insert(
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
    print('✅ Reporte y despliegue guardados en la tabla `reportes_pendientes`');
    await _actualizarConteoPendientes();
  }

  // --- LÓGICA DE SINCRONIZACIÓN DE PENDIENTES ---

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
        print('❌ No hay conexión a internet para sincronizar.');
        _syncStatusController.add(SyncStatus.pending);
        return;
      }

      final serviceToUse = apiService ?? _apiService;
      if (serviceToUse == null) {
        print('⚠️ No hay ApiService disponible para la sincronización.');
        _syncStatusController.add(SyncStatus.error);
        return;
      }

      final reportesPendientes = await _db.query('reportes_pendientes', where: 'sincronizado = ?', whereArgs: [0]);
      if (reportesPendientes.isEmpty) {
        print('✅ No hay reportes pendientes para sincronizar.');
        _syncStatusController.add(SyncStatus.synced);
        return;
      }

      print('🔄 Sincronizando ${reportesPendientes.length} reportes...');
      int sincronizados = 0;
      int total = reportesPendientes.length;

      for (int i = 0; i < reportesPendientes.length; i++) {
        final reporte = reportesPendientes[i];
        final id = reporte['id'] as int?;
        if (id == null) continue;

        final success = await _enviarReportePendiente(reporte, serviceToUse);
        if (success) {
          sincronizados++;
          await _marcarComoSincronizado(id);
        } else {
          await _incrementarIntentos(id);
        }
        _syncProgressController.add(SyncProgress(actual: i + 1, total: total, porcentaje: ((i + 1) / total * 100).toInt()));
      }

      await _actualizarConteoPendientes();
      print('✅ Sincronización completada: $sincronizados/$total');
      _syncStatusController.add(SyncStatus.synced);
    } catch (e) {
      print('❌ Error durante la sincronización: $e');
      _syncStatusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _enviarReportePendiente(Map<String, dynamic> reportePendiente, ApiService apiService) async {
    try {
      final reporteData = jsonDecode(reportePendiente['reporte_data']);
      final despliegueData = jsonDecode(reportePendiente['despliegue_data']);

      final resultReporte = await apiService.enviarReporteDiario(reporteData);
      if (!resultReporte['success']) {
        print('❌ Error sincronizando reporte diario: ${resultReporte['message']}');
        return false;
      }

      final resultDespliegue = await apiService.enviarRegistroDespliegue(despliegueData);
      if (!resultDespliegue) {
        print('❌ Error sincronizando registro de despliegue.');
        return false; // Opcional: podrías considerarlo un éxito parcial si el reporte se envió.
      }

      print('✅ Reporte pendiente enviado exitosamente.');
      return true;
    } catch (e) {
      print('❌ Error fatal al enviar reporte pendiente: $e');
      return false;
    }
  }

  // --- MÉTODOS HELPERS PARA ENVÍO HTTP ---

  Future<void> _enviarReporteDiario(Map<String, dynamic> reporteData, String accessToken) async {
    final url = '${Enviroment.apiUrlDev}reportesdiarios/';
    final jsonReporte = {
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
      'observacionC': reporteData['observacionC'] ?? '',
      'observacionR': reporteData['observacionR'] ?? '',
      'saltosenC': int.tryParse(reporteData['saltosenC']?.toString() ?? '0') ?? 0,
      'saltosenR': int.tryParse(reporteData['saltosenR']?.toString() ?? '0') ?? 0,
      'fecha_registro': DateTime.now().toLocal().toIso8601String().replaceAll('Z', ''),
    };

    print('📦 JSON Reporte para API: $jsonReporte');
    final response = await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $accessToken'}, body: jsonEncode(jsonReporte)).timeout(const Duration(seconds: 30));

    print('📥 ReporteDiario Status: ${response.statusCode}, Body: ${response.body}');
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al enviar reporte diario: ${response.statusCode}');
    }
    print('✅ Reporte diario enviado exitosamente al servidor.');
  }

  Future<void> _enviarDespliegueReporte(Map<String, dynamic> despliegueData, String accessToken) async {
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

    print('📦 JSON Despliegue para API: $jsonDespliegue');
    final response = await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $accessToken'}, body: jsonEncode(jsonDespliegue)).timeout(const Duration(seconds: 20));

    print('📥 DespliegueReporte Status: ${response.statusCode}, Body: ${response.body}');
    if (response.statusCode != 200 && response.statusCode != 201) {
      // No lanzamos excepción aquí para no impedir el guardado local, solo advertimos.
      print('⚠️ Error enviando despliegue asociado: ${response.statusCode}');
    } else {
      print('✅ Despliegue asociado enviado exitosamente.');
    }
  }

  // --- MÉTODOS DE MANEJO DE BD LOCAL ---

  Future<void> _marcarComoSincronizado(int id) async {
    await _db.update('reportes_pendientes', {'sincronizado': 1, 'ultima_tentativa': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _incrementarIntentos(int id) async {
    await _db.rawUpdate('UPDATE reportes_pendientes SET intentos = intentos + 1, ultima_tentativa = ? WHERE id = ?', [DateTime.now().toIso8601String(), id]);
  }

  Future<void> _actualizarConteoPendientes() async {
    final count = await _contarReportesPendientes();
    _pendingCountController.add(count);
    print('📊 Reportes pendientes actualizados: $count');
  }

  Future<int> _contarReportesPendientes() async {
    if (!_isInitialized) return 0;
    final result = await _db.rawQuery('SELECT COUNT(*) as count FROM reportes_pendientes WHERE sincronizado = 0');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getReportes() async {
    // Este método ahora debería leer de `reportes_pendientes` y decodificar el JSON
    if (!_isInitialized) return [];

    final reportesPendientes = await _db.query('reportes_pendientes');

    return reportesPendientes.map((dbRow) {
      final reporteData = jsonDecode(dbRow['reporte_data'] as String);
      reporteData['synced'] = (dbRow['sincronizado'] == 1); // Añadir estado de sincronización
      reporteData['id_local'] = dbRow['id']; // Añadir ID local para posible manejo en UI
      return reporteData as Map<String, dynamic>;
    }).toList();
  }

  Future<void> limpiarReportesSincronizados() async {
    final count = await _db.delete('reportes_pendientes', where: 'sincronizado = ?', whereArgs: [1]);
    await _actualizarConteoPendientes();
    print('🧹 $count reportes sincronizados han sido limpiados de la base de datos local.');
  }

  // --- HELPERS Y DISPOSE ---

  Future<bool> _verificarConexion() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // Pega este método dentro de la clase ReporteSyncService

  /// ✅ NUEVO: Obtener estado de sincronización actual
  Future<SyncState> getSyncState() async {
    try {
      // Cuenta los reportes que están marcados como no sincronizados (sincronizado = 0)
      final pendientes = await _contarReportesPendientes();

      // Aquí podrías agregar la lógica para contar despliegues si los manejas por separado
      final desplieguesPendientes = 0; // Placeholder, ajústalo si es necesario

      // Devuelve un objeto SyncState con toda la información
      return SyncState(
        hasPendingSync: pendientes > 0,
        pendingReports: pendientes,
        pendingDeployments: desplieguesPendientes,
        offlineMode: _offlineMode, // Usa la variable interna que ya monitorea la conexión
        isSyncing: _isSyncing,     // Usa la variable interna que controla si hay una sincronización en progreso
        success: true,
      );
    } catch (e) {
      print('❌ Error obteniendo el estado de sincronización: $e');
      // En caso de error, devuelve un estado por defecto que no bloquee la UI
      return SyncState(
        hasPendingSync: false,
        pendingReports: 0,
        pendingDeployments: 0,
        offlineMode: _offlineMode,
        isSyncing: false,
        success: false, // Indica que hubo un problema al obtener el estado
      );
    }
  }

  // Pega este método dentro de la clase ReporteSyncService

  /// ✅ NUEVO: Obtener estadísticas de sincronización
  Future<SyncStats> getSyncStats() async {
    if (!_isInitialized) {
      print('⚠️ DB no inicializada, devolviendo estadísticas vacías.');
      return SyncStats(totalReportes: 0, sincronizados: 0, pendientes: 0);
    }

    try {
      // Consulta para contar el total de reportes en la tabla de pendientes
      final totalResult = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM reportes_pendientes',
      );
      final total = (totalResult.first['count'] as int?) ?? 0;

      // Consulta para contar solo los reportes ya sincronizados
      final sincronizadosResult = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM reportes_pendientes WHERE sincronizado = 1',
      );
      final sincronizados = (sincronizadosResult.first['count'] as int?) ?? 0;

      // Los pendientes son el total menos los sincronizados
      final pendientes = total - sincronizados;

      return SyncStats(
        totalReportes: total,
        sincronizados: sincronizados,
        pendientes: pendientes,
      );
    } catch (e) {
      print('❌ Error obteniendo estadísticas de sincronización: $e');
      // Devuelve un estado seguro en caso de error
      return SyncStats(
        totalReportes: 0,
        sincronizados: 0,
        pendientes: 0,
      );
    }
  }

  // Pega este método dentro de la clase ReporteSyncService

  /// ✅ NUEVO: Método para iniciar una sincronización manual desde la UI
  Future<SyncResult> syncNow() async {
    print('▶️ Iniciando sincronización manual...');

    // 1. Verificar si el servicio está listo
    if (!_isInitialized) {
      return SyncResult(
        success: false,
        message: 'El servicio de sincronización no está inicializado.',
      );
    }

    // 2. Verificar si hay conexión a internet
    final hasConnection = await _verificarConexion();
    if (!hasConnection) {
      return SyncResult(
        success: false,
        message: 'No hay conexión a internet para sincronizar.',
      );
    }

    // 3. Verificar si el ApiService (con el token) está disponible
    if (_apiService == null) {
      return SyncResult(
        success: false,
        message: 'Token de sesión no disponible. Por favor, reinicia la app.',
      );
    }

    // 4. Contar cuántos reportes hay pendientes ANTES de sincronizar
    final pendientesAntes = await _contarReportesPendientes();
    if (pendientesAntes == 0) {
      return SyncResult(
        success: true,
        message: '¡Todo está al día! No hay datos pendientes.',
      );
    }

    try {
      // 5. Ejecutar la lógica de sincronización principal
      await sincronizarReportes(apiService: _apiService);

      // 6. Verificar cuántos reportes quedaron pendientes DESPUÉS de sincronizar
      final pendientesDespues = await _contarReportesPendientes();
      final sincronizados = pendientesAntes - pendientesDespues;

      if (pendientesDespues == 0) {
        return SyncResult(
          success: true,
          message: '¡Sincronización completada! Se enviaron $sincronizados reportes.',
          syncedCount: sincronizados,
        );
      } else {
        return SyncResult(
          success: false,
          message: 'Sincronización parcial. Quedan $pendientesDespues reportes pendientes.',
          syncedCount: sincronizados,
          failedCount: pendientesDespues,
        );
      }
    } catch (e) {
      print('❌ Error fatal durante la sincronización manual: $e');
      return SyncResult(
        success: false,
        message: 'Ocurrió un error inesperado durante la sincronización.',
      );
    }
  }




  void dispose() {
    _connectivitySubscription?.cancel();
    _autoSyncTimer?.cancel();
    _syncStatusController.close();
    _pendingCountController.close();
    _syncProgressController.close();
  }
}
