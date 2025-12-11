// lib/services/reporte_sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:manager_key/services/sync_indicator.dart' hide SyncState;
import '../config/enviroment.dart';
import '../database/database_helper.dart';
import '../models/reporte_diario_historial.dart';
import '../models/sync_models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../database/database_helper.dart';
import 'api_service.dart';

class ReporteSyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();

  // Streams para estado
  final StreamController<SyncStatus> _syncStatusController =
  StreamController<SyncStatus>.broadcast();
  final StreamController<int> _pendingCountController =
  StreamController<int>.broadcast();
  final StreamController<SyncProgress> _syncProgressController =
  StreamController<SyncProgress>.broadcast();

  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<int> get pendingCountStream => _pendingCountController.stream;
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

  // Variable para controlar si está sincronizando
  bool _isSyncing = false;

  // Constructor
  ReporteSyncService() {
    // Inicializar estado
    _syncStatusController.add(SyncStatus.synced);
    _actualizarContadorPendientes();
  }

  // Verificar conexión
  Future<bool> verificarConexion() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('Error verificando conexión: $e');
      return false;
    }
  }

  // Enviar reporte individual al servidor
  Future<Map<String, dynamic>> enviarReporteAlServidor(
      Map<String, dynamic> reporteData) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'No hay token de autenticación',
        };
      }

      // Obtener ID del operador
      final userData = await _authService.getCurrentUser();
      final idOperador = userData?.operador?.idOperador;

      if (idOperador == null) {
        return {
          'success': false,
          'message': 'No se pudo obtener ID del operador',
        };
      }

      // Asegurar que el reporte tenga el operador correcto
      reporteData['operador'] = idOperador;

      final url = Uri.parse('${Enviroment.apiUrlDev}reportesdiarios/');
      print('📤 Enviando reporte a: $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(reporteData),
      ).timeout(const Duration(seconds: 30));

      print('📥 Respuesta: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Reporte enviado exitosamente',
          'server_id': responseData['id'],
          'data': responseData,
        };
      } else {
        print('❌ Error del servidor: ${response.body}');
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ Error enviando reporte: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Guardar reporte localmente
  Future<Map<String, dynamic>> guardarReporteLocalmente(
      Map<String, dynamic> reporteData) async {
    try {
      final userData = await _authService.getCurrentUser();
      final idOperador = userData?.operador?.idOperador;
      final nroEstacion = userData?.operador?.nroEstacion;

      if (idOperador == null) {
        return {
          'success': false,
          'message': 'No se pudo obtener datos del operador',
        };
      }

      // Crear modelo local
      final reporteLocal = ReporteDiarioHistorial(
        id: null,
        idServer: null,
        fechaReporte:
        reporteData['fecha_reporte'] ?? DateTime.now().toIso8601String(),
        contadorInicialC: reporteData['contador_inicial_c'] ?? '',
        contadorFinalC: reporteData['contador_final_c'] ?? '',
        contadorC: (reporteData['registro_c'] ?? 0).toString(),
        contadorInicialR: reporteData['contador_inicial_r'] ?? '',
        contadorFinalR: reporteData['contador_final_r'] ?? '',
        contadorR: (reporteData['registro_r'] ?? 0).toString(),
        incidencias: reporteData['incidencias'],
        observaciones: reporteData['observaciones'],
        fechaCreacion: DateTime.now(),
        fechaSincronizacion: null,
        estadoSincronizacion: EstadoSincronizacion.pendiente,
        idOperador: idOperador,
        idEstacion: reporteData['estacion'] ?? 0,
        centroEmpadronamiento: reporteData['centro_empadronamiento'],
        observacionC: reporteData['observacionC'],
        observacionR: reporteData['observacionR'],
        saltosenC: reporteData['saltosenC'] ?? 0,
        saltosenR: reporteData['saltosenR'] ?? 0,
      );

      // Guardar en base de datos
      final db = await _dbHelper.database;
      final id = await db.insert(
        DatabaseHelper.tableReportes,
        reporteLocal.toLocalMap(),
      );

      print('💾 Reporte guardado localmente con ID: $id');

      // Actualizar contador
      await _actualizarContadorPendientes();

      return {
        'success': true,
        'message': 'Reporte guardado localmente',
        'local_id': id,
        'saved_locally': true,
      };
    } catch (e) {
      print('❌ Error guardando reporte localmente: $e');
      return {
        'success': false,
        'message': 'Error guardando localmente: ${e.toString()}',
        'saved_locally': false,
      };
    }
  }

  // Sincronizar reporte (intentar enviar al servidor, si falla guardar local)
  Future<Map<String, dynamic>> sincronizarReporte(
      Map<String, dynamic> reporteData) async {
    try {
      // Verificar conexión
      final tieneConexion = await verificarConexion();

      if (tieneConexion) {
        // Intentar enviar al servidor
        final resultado = await enviarReporteAlServidor(reporteData);

        if (resultado['success'] == true) {
          // Si se envió exitosamente, también guardar localmente con ID del servidor
          final userData = await _authService.getCurrentUser();
          final idOperador = userData?.operador?.idOperador;

          if (idOperador != null) {
            final reporteLocal = ReporteDiarioHistorial(
              id: null,
              idServer: resultado['server_id'],
              fechaReporte: reporteData['fecha_reporte'],
              contadorInicialC: reporteData['contador_inicial_c'],
              contadorFinalC: reporteData['contador_final_c'],
              contadorC: (reporteData['registro_c'] ?? 0).toString(),
              contadorInicialR: reporteData['contador_inicial_r'],
              contadorFinalR: reporteData['contador_final_r'],
              contadorR: (reporteData['registro_r'] ?? 0).toString(),
              incidencias: reporteData['incidencias'],
              observaciones: reporteData['observaciones'],
              fechaCreacion: DateTime.now(),
              fechaSincronizacion: DateTime.now(),
              estadoSincronizacion: EstadoSincronizacion.sincronizado,
              idOperador: idOperador,
              idEstacion: reporteData['estacion'] ?? 0,
              centroEmpadronamiento: reporteData['centro_empadronamiento'],
              observacionC: reporteData['observacionC'],
              observacionR: reporteData['observacionR'],
              saltosenC: reporteData['saltosenC'] ?? 0,
              saltosenR: reporteData['saltosenR'] ?? 0,
            );

            final db = await _dbHelper.database;
            await db.insert(
              DatabaseHelper.tableReportes,
              reporteLocal.toLocalMap(),
            );

            print('✅ Reporte sincronizado exitosamente con el servidor');
          }

          // Actualizar contador
          await _actualizarContadorPendientes();

          return {
            'success': true,
            'message': 'Reporte enviado y guardado exitosamente',
            'server_id': resultado['server_id'],
            'saved_locally': false,
          };
        } else {
          // Si falló el servidor, guardar localmente como pendiente
          print('⚠️ Falló envío al servidor, guardando localmente');
          return await guardarReporteLocalmente(reporteData);
        }
      } else {
        // Sin conexión, guardar localmente
        print('📱 Sin conexión, guardando reporte localmente');
        return await guardarReporteLocalmente(reporteData);
      }
    } catch (e) {
      print('❌ Error en sincronización: $e');
      return {
        'success': false,
        'message': 'Error en sincronización: ${e.toString()}',
        'saved_locally': false,
      };
    }
  }

  // MÉTODO NECESARIO PARA SYNCSTATUSPANEL
  Future<void> sincronizarReportes() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      _syncStatusController.add(SyncStatus.syncing);

      final tieneConexion = await verificarConexion();
      if (!tieneConexion) {
        _syncStatusController.add(SyncStatus.pending);
        _isSyncing = false;
        return;
      }

      // Obtener reportes pendientes
      final db = await _dbHelper.database;
      final pendientes = await db.query(
        DatabaseHelper.tableReportes,
        where: '${DatabaseHelper.columnEstado} = ?',
        whereArgs: ['pendiente'],
      );

      print('📊 Sincronizando ${pendientes.length} reportes pendientes');

      if (pendientes.isEmpty) {
        _syncStatusController.add(SyncStatus.synced);
        _isSyncing = false;
        return;
      }

      int sincronizadosExitosos = 0;
      int total = pendientes.length;

      // Actualizar progreso
      _syncProgressController.add(SyncProgress(
        actual: 0,
        total: total,
        porcentaje: 0,
      ));

      for (int i = 0; i < pendientes.length; i++) {
        try {
          final pendiente = pendientes[i];

          // Convertir a mapa para enviar
          final reporteData = {
            'fecha_reporte': pendiente[DatabaseHelper.columnFechaReporte],
            'contador_inicial_c': pendiente[DatabaseHelper.columnContadorInicialC],
            'contador_final_c': pendiente[DatabaseHelper.columnContadorFinalC],
            'registro_c': int.tryParse(pendiente[DatabaseHelper.columnContadorC] as String) ?? 0,
            'contador_inicial_r': pendiente[DatabaseHelper.columnContadorInicialR],
            'contador_final_r': pendiente[DatabaseHelper.columnContadorFinalR],
            'registro_r': int.tryParse(pendiente[DatabaseHelper.columnContadorR] as String) ?? 0,
            'incidencias': pendiente[DatabaseHelper.columnIncidencias],
            'observaciones': pendiente[DatabaseHelper.columnObservaciones],
            'operador': pendiente[DatabaseHelper.columnIdOperador],
            'estacion': pendiente[DatabaseHelper.columnEstacionId],
            'centro_empadronamiento': pendiente[DatabaseHelper.columnCentroEmpadronamiento],
            'observacionC': pendiente[DatabaseHelper.columnObservacionC],
            'observacionR': pendiente[DatabaseHelper.columnObservacionR],
            'saltosenC': pendiente[DatabaseHelper.columnSaltosenC] ?? 0,
            'saltosenR': pendiente[DatabaseHelper.columnSaltosenR] ?? 0,
          };

          final resultado = await enviarReporteAlServidor(reporteData);

          if (resultado['success'] == true) {
            // Marcar como sincronizado
            await db.update(
              DatabaseHelper.tableReportes,
              {
                DatabaseHelper.columnEstado: 'sincronizado',
                DatabaseHelper.columnIdServer: resultado['server_id'],
                DatabaseHelper.columnFechaSincronizacion: DateTime.now().toIso8601String(),
              },
              where: '${DatabaseHelper.columnId} = ?',
              whereArgs: [pendiente[DatabaseHelper.columnId]],
            );

            sincronizadosExitosos++;
          }

          // Actualizar progreso
          final porcentaje = ((i + 1) / total * 100).toInt();
          _syncProgressController.add(SyncProgress(
            actual: i + 1,
            total: total,
            porcentaje: porcentaje,
          ));

          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('❌ Error sincronizando reporte: $e');
        }
      }

      // Actualizar estado final
      if (sincronizadosExitosos == total) {
        _syncStatusController.add(SyncStatus.synced);
      } else if (sincronizadosExitosos > 0) {
        _syncStatusController.add(SyncStatus.synced);
      } else {
        _syncStatusController.add(SyncStatus.error);
      }

      // Actualizar contador de pendientes
      await _actualizarContadorPendientes();

    } catch (e) {
      print('❌ Error en sincronización general: $e');
      _syncStatusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  // Sincronizar reportes pendientes (método anterior mantenido para compatibilidad)
  Future<Map<String, dynamic>> sincronizarReportesPendientes() async {
    try {
      final tieneConexion = await verificarConexion();
      if (!tieneConexion) {
        return {
          'success': false,
          'message': 'No hay conexión a internet',
          'sincronizados': 0,
        };
      }

      // Obtener reportes pendientes
      final db = await _dbHelper.database;
      final pendientes = await db.query(
        DatabaseHelper.tableReportes,
        where: '${DatabaseHelper.columnEstado} = ?',
        whereArgs: ['pendiente'],
      );

      print('📊 Reportes pendientes para sincronizar: ${pendientes.length}');

      if (pendientes.isEmpty) {
        return {
          'success': true,
          'message': 'No hay reportes pendientes',
          'sincronizados': 0,
        };
      }

      int sincronizadosExitosos = 0;
      int sincronizadosFallidos = 0;

      for (var pendiente in pendientes) {
        try {
          // Convertir a mapa para enviar
          final reporteData = {
            'fecha_reporte': pendiente[DatabaseHelper.columnFechaReporte],
            'contador_inicial_c': pendiente[DatabaseHelper.columnContadorInicialC],
            'contador_final_c': pendiente[DatabaseHelper.columnContadorFinalC],
            'registro_c': int.tryParse(pendiente[DatabaseHelper.columnContadorC] as String) ?? 0,
            'contador_inicial_r': pendiente[DatabaseHelper.columnContadorInicialR],
            'contador_final_r': pendiente[DatabaseHelper.columnContadorFinalR],
            'registro_r': int.tryParse(pendiente[DatabaseHelper.columnContadorR] as String) ?? 0,
            'incidencias': pendiente[DatabaseHelper.columnIncidencias],
            'observaciones': pendiente[DatabaseHelper.columnObservaciones],
            'operador': pendiente[DatabaseHelper.columnIdOperador],
            'estacion': pendiente[DatabaseHelper.columnEstacionId],
            'centro_empadronamiento': pendiente[DatabaseHelper.columnCentroEmpadronamiento],
            'observacionC': pendiente[DatabaseHelper.columnObservacionC],
            'observacionR': pendiente[DatabaseHelper.columnObservacionR],
            'saltosenC': pendiente[DatabaseHelper.columnSaltosenC] ?? 0,
            'saltosenR': pendiente[DatabaseHelper.columnSaltosenR] ?? 0,
          };

          final resultado = await enviarReporteAlServidor(reporteData);

          if (resultado['success'] == true) {
            // Marcar como sincronizado
            await db.update(
              DatabaseHelper.tableReportes,
              {
                DatabaseHelper.columnEstado: 'sincronizado',
                DatabaseHelper.columnIdServer: resultado['server_id'],
                DatabaseHelper.columnFechaSincronizacion: DateTime.now().toIso8601String(),
              },
              where: '${DatabaseHelper.columnId} = ?',
              whereArgs: [pendiente[DatabaseHelper.columnId]],
            );

            sincronizadosExitosos++;
            print('✅ Reporte ${pendiente[DatabaseHelper.columnId]} sincronizado');
          } else {
            sincronizadosFallidos++;
            print('❌ Falló sincronización del reporte ${pendiente[DatabaseHelper.columnId]}');
          }
        } catch (e) {
          sincronizadosFallidos++;
          print('❌ Error sincronizando reporte: $e');
        }
      }

      return {
        'success': sincronizadosFallidos == 0,
        'message': sincronizadosFallidos == 0
            ? '✅ Todos los reportes sincronizados exitosamente'
            : '⚠️ Sincronización parcial: $sincronizadosExitosos exitosos, $sincronizadosFallidos fallidos',
        'sincronizados': sincronizadosExitosos,
        'fallidos': sincronizadosFallidos,
        'total': pendientes.length,
      };
    } catch (e) {
      print('❌ Error sincronizando reportes pendientes: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'sincronizados': 0,
        'fallidos': 0,
        'total': 0,
      };
    }
  }

  // Método auxiliar para actualizar contador de pendientes
  Future<void> _actualizarContadorPendientes() async {
    try {
      final userData = await _authService.getCurrentUser();
      final idOperador = userData?.operador?.idOperador;

      if (idOperador == null) {
        _pendingCountController.add(0);
        return;
      }

      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableReportes} ' +
            'WHERE ${DatabaseHelper.columnEstado} = ? AND ${DatabaseHelper.columnIdOperador} = ?',
        ['pendiente', idOperador],
      );

      final count = result.first['count'] as int? ?? 0;
      _pendingCountController.add(count);

      // También actualizar estado general basado en conexión y pendientes
      final tieneConexion = await verificarConexion();
      if (!tieneConexion && count > 0) {
        _syncStatusController.add(SyncStatus.pending);
      } else if (tieneConexion && count == 0) {
        _syncStatusController.add(SyncStatus.synced);
      }
    } catch (e) {
      print('❌ Error actualizando contador: $e');
      _pendingCountController.add(0);
    }
  }

  // Obtener estadísticas de reportes
  Future<Map<String, dynamic>> obtenerEstadisticasReportes() async {
    try {
      final userData = await _authService.getCurrentUser();
      final idOperador = userData?.operador?.idOperador;

      if (idOperador == null) {
        return {'pendientes': 0, 'sincronizados': 0, 'total': 0};
      }

      final db = await _dbHelper.database;

      // Total reportes del operador
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as total FROM ${DatabaseHelper.tableReportes} WHERE ${DatabaseHelper.columnIdOperador} = ?',
        [idOperador],
      );
      final total = totalResult.first['total'] as int? ?? 0;

      // Reportes pendientes
      final pendientesResult = await db.rawQuery(
        'SELECT COUNT(*) as pendientes FROM ${DatabaseHelper.tableReportes} WHERE ${DatabaseHelper.columnIdOperador} = ? AND ${DatabaseHelper.columnEstado} = ?',
        [idOperador, 'pendiente'],
      );
      final pendientes = pendientesResult.first['pendientes'] as int? ?? 0;

      // Reportes sincronizados
      final sincronizadosResult = await db.rawQuery(
        'SELECT COUNT(*) as sincronizados FROM ${DatabaseHelper.tableReportes} WHERE ${DatabaseHelper.columnIdOperador} = ? AND ${DatabaseHelper.columnEstado} = ?',
        [idOperador, 'sincronizado'],
      );
      final sincronizados = sincronizadosResult.first['sincronizados'] as int? ?? 0;

      return {
        'pendientes': pendientes,
        'sincronizados': sincronizados,
        'total': total,
        'porcentaje': total > 0 ? (sincronizados / total * 100).toStringAsFixed(1) : '0.0',
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {'pendientes': 0, 'sincronizados': 0, 'total': 0, 'porcentaje': '0.0'};
    }
  }

  // Eliminar reportes antiguos (más de 30 días sincronizados)
  Future<void> limpiarReportesAntiguos() async {
    try {
      final db = await _dbHelper.database;
      final fechaLimite = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String();

      await db.delete(
        DatabaseHelper.tableReportes,
        where:
        '${DatabaseHelper.columnFechaCreacion} < ? AND ${DatabaseHelper.columnEstado} = ?',
        whereArgs: [fechaLimite, 'sincronizado'],
      );

      print('🧹 Reportes antiguos limpiados');
    } catch (e) {
      print('❌ Error limpiando reportes antiguos: $e');
    }
  }

  // MÉTODO NECESARIO PARA SYNCSTATUSPANEL
  Future<SyncStats> getSyncStats() async {
    try {
      final stats = await obtenerEstadisticasReportes();

      return SyncStats(
        totalReportes: stats['total'] ?? 0,
        sincronizados: stats['sincronizados'] ?? 0,
        pendientes: stats['pendientes'] ?? 0,
      );
    } catch (e) {
      print('❌ Error obteniendo SyncStats: $e');
      return SyncStats(
        totalReportes: 0,
        sincronizados: 0,
        pendientes: 0,
      );
    }
  }

  // MÉTODO NECESARIO PARA SYNCSTATUSPANEL
  Future<void> limpiarReportesSincronizados() async {
    try {
      final db = await _dbHelper.database;

      // Contar cuántos vamos a eliminar
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableReportes} WHERE ${DatabaseHelper.columnEstado} = ?',
        ['sincronizado'],
      );
      final count = result.first['count'] as int? ?? 0;

      if (count == 0) {
        print('ℹ️ No hay reportes sincronizados para limpiar');
        return;
      }

      // Eliminar reportes sincronizados
      await db.delete(
        DatabaseHelper.tableReportes,
        where: '${DatabaseHelper.columnEstado} = ?',
        whereArgs: ['sincronizado'],
      );

      print('🧹 $count reportes sincronizados eliminados');

      // Actualizar contador
      await _actualizarContadorPendientes();

    } catch (e) {
      print('❌ Error limpiando reportes sincronizados: $e');
      rethrow;
    }
  }

  // Métodos adicionales (mantenidos para compatibilidad)
  Future<SyncState> getSyncState() async {
    try {
      final tieneConexion = await verificarConexion();
      final stats = await obtenerEstadisticasReportes();

      return SyncState(
        isSyncing: _isSyncing,
        offlineMode: !tieneConexion,
        hasPendingSync: (stats['pendientes'] ?? 0) > 0,
        pendingReports: stats['pendientes'] ?? 0,
        pendingDeployments: 0,
        lastSync: DateTime.now(),
      );
    } catch (e) {
      print('❌ Error obteniendo estado de sincronización: $e');
      return SyncState(
        isSyncing: false,
        offlineMode: true,
        hasPendingSync: false,
        pendingReports: 0,
        pendingDeployments: 0,
        lastSync: null,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getReportes() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.tableReportes,
      );
      return maps;
    } catch (e) {
      print('❌ Error obteniendo reportes: $e');
      return [];
    }
  }

  Future<SyncStatus> getCurrentSyncStatus() async {
    try {
      final tieneConexion = await verificarConexion();
      final stats = await obtenerEstadisticasReportes();
      final pendientes = stats['pendientes'] ?? 0;

      if (!tieneConexion) {
        return SyncStatus.pending;
      }

      if (_isSyncing) {
        return SyncStatus.syncing;
      }

      if (pendientes > 0) {
        return SyncStatus.error;
      }

      return SyncStatus.synced;
    } catch (e) {
      return SyncStatus.error;
    }
  }

  Future<SyncResult> syncNow() async {
    await sincronizarReportes();

    // Obtener estadísticas después de sincronizar
    final stats = await obtenerEstadisticasReportes();
    final pendientes = stats['pendientes'] ?? 0;

    if (pendientes == 0) {
      return SyncResult(
        success: true,
        message: '✅ Sincronización completada exitosamente',
        syncCount: stats['sincronizados'] ?? 0,
      );
    } else {
      return SyncResult(
        success: false,
        message: '⚠️ Sincronización parcial: ${pendientes} pendientes',
        syncCount: stats['sincronizados'] ?? 0,
      );
    }
  }

  Future<int> getPendingCount() async {
    final stats = await obtenerEstadisticasReportes();
    return stats['pendientes'] ?? 0;
  }

  // Método para cerrar streams
  void dispose() {
    _syncStatusController.close();
    _pendingCountController.close();
    _syncProgressController.close();
  }
}