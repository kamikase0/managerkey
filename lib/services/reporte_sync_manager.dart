// lib/services/reporte_sync_manager.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:manager_key/database/database_helper.dart';
import 'package:manager_key/models/reporte_diario_local.dart';
import 'package:manager_key/services/api_service.dart';
import 'package:manager_key/services/auth_service.dart';

class ReporteSyncManager {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();

  Future<bool> tieneConexionInternet() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('Error verificando conexión: $e');
      return false;
    }
  }

  // Obtener reportes (inteligente según conexión)
  Future<List<ReporteDiarioLocal>> obtenerReportes() async {
    final tieneConexion = await tieneConexionInternet();
    final idOperador = await _authService.getIdOperador();

    if (idOperador == null) {
      return [];
    }

    if (tieneConexion) {
      // Caso 1: Con internet - obtener del servidor
      return await _obtenerDesdeServidorYActualizarLocal(idOperador);
    } else {
      // Caso 2: Sin internet - obtener solo de base local
      return await _dbHelper.getReportesPorOperador(idOperador);
    }
  }

// En ReporteSyncManager.dart - CORREGIR MÉTODO _obtenerDesdeServidorYActualizarLocal:
  Future<List<ReporteDiarioLocal>> _obtenerDesdeServidorYActualizarLocal(int idOperador) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) return [];

      final apiService = ApiService(accessToken: token);
      final reportesServidor = await apiService.obtenerReportesPorOperador(idOperador);

      // Convertir cada reporte del servidor a ReporteDiarioLocal
      final reportesLocales = <ReporteDiarioLocal>[];

      for (var reporte in reportesServidor) {
        try {
          final reporteLocal = ReporteDiarioLocal(
            idServer: reporte['id'],
            contadorInicialR: reporte['contador_inicial_r'] ?? '',
            contadorFinalR: reporte['contador_final_r'] ?? '',
            saltosenR: (reporte['saltosenR'] ?? 0) as int,
            contadorR: (reporte['registro_r'] ?? 0).toString(),
            contadorInicialC: reporte['contador_inicial_c'] ?? '',
            contadorFinalC: reporte['contador_final_c'] ?? '',
            saltosenC: (reporte['saltosenC'] ?? 0) as int,
            contadorC: (reporte['registro_c'] ?? 0).toString(),
            fechaReporte: reporte['fecha_reporte'] ?? '',
            observaciones: reporte['observaciones'],
            incidencias: reporte['incidencias'],
            estado: 'sincronizado',
            idOperador: idOperador,
            estacionId: (reporte['estacion'] ?? 0) as int,
            fechaCreacion: DateTime.parse(reporte['fecha_registro'] ?? DateTime.now().toIso8601String()),
            fechaSincronizacion: DateTime.now(),
            centroEmpadronamiento: reporte['centro_empadronamiento'] != null
                ? (reporte['centro_empadronamiento'] as int)
                : null,
            sincronizar: true,
          );

          // Verificar si ya existe
          final existe = await _dbHelper.existeReporteParaFecha(
              reporteLocal.fechaReporte,
              reporteLocal.idOperador
          );

          if (!existe) {
            await _dbHelper.insertReporte(reporteLocal);
          }

          reportesLocales.add(reporteLocal);
        } catch (e) {
          print('❌ Error convirtiendo reporte: $e');
        }
      }

      return reportesLocales;

    } catch (e) {
      print('❌ Error obteniendo del servidor: $e');
      return [];
    }
  }

  // Guardar nuevo reporte (inteligente según conexión)
  Future<Map<String, dynamic>> guardarReporte(ReporteDiarioLocal reporte) async {
    final tieneConexion = await tieneConexionInternet();

    if (tieneConexion) {
      // Caso 1: Con internet - intentar enviar al servidor
      try {
        final token = await _authService.getAccessToken();
        if (token == null) {
          throw Exception('No hay token disponible');
        }

        final apiService = ApiService(accessToken: token);
        final resultado = await apiService.enviarReporteDiario(reporte.toApiJson());

        if (resultado['success'] == true) {
          // Guardar como sincronizado
          reporte.idServer = resultado['id'];
          reporte.estado = 'sincronizado';
          reporte.fechaSincronizacion = DateTime.now();

          final id = await _dbHelper.insertReporte(reporte);

          return {
            'success': true,
            'message': 'Reporte enviado exitosamente',
            'server_id': resultado['id'],
            'local_id': id,
            'sincronizado': true,
          };
        } else {
          throw Exception('Error del servidor: ${resultado['message']}');
        }
      } catch (e) {
        // Si falla el servidor, guardar como pendiente
        reporte.estado = 'pendiente';
        final id = await _dbHelper.insertReporte(reporte);

        return {
          'success': true,
          'message': 'Reporte guardado localmente (se sincronizará después)',
          'local_id': id,
          'sincronizado': false,
          'error': e.toString(),
        };
      }
    } else {
      // Caso 2: Sin internet - guardar como pendiente
      reporte.estado = 'pendiente';
      final id = await _dbHelper.insertReporte(reporte);

      return {
        'success': true,
        'message': 'Reporte guardado localmente (modo offline)',
        'local_id': id,
        'sincronizado': false,
      };
    }
  }

  // Sincronizar reportes pendientes
  Future<Map<String, dynamic>> sincronizarReportesPendientes() async {
    try {
      final tieneConexion = await tieneConexionInternet();
      if (!tieneConexion) {
        return {
          'success': false,
          'message': 'No hay conexión a internet',
        };
      }

      final token = await _authService.getAccessToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No hay token de autenticación',
        };
      }

      final pendientes = await _dbHelper.getReportesPendientes();

      if (pendientes.isEmpty) {
        return {
          'success': true,
          'message': 'No hay reportes pendientes',
        };
      }

      print('🔄 Sincronizando ${pendientes.length} reportes pendientes...');

      final apiService = ApiService(accessToken: token);
      int exitosos = 0;
      int fallidos = 0;

      for (var reporte in pendientes) {
        try {
          final resultado = await apiService.enviarReporteDiario(reporte.toApiJson());

          if (resultado['success'] == true) {
            // Marcar como sincronizado
            reporte.idServer = resultado['id'];
            reporte.estado = 'sincronizado';
            reporte.fechaSincronizacion = DateTime.now();

            await _dbHelper.updateReporte(reporte);
            exitosos++;
            print('✅ Reporte ${reporte.id} sincronizado');
          } else {
            reporte.estado = 'fallido';
            await _dbHelper.updateReporte(reporte);
            fallidos++;
            print('❌ Reporte ${reporte.id} falló');
          }
        } catch (e) {
          reporte.estado = 'fallido';
          await _dbHelper.updateReporte(reporte);
          fallidos++;
          print('❌ Error sincronizando reporte ${reporte.id}: $e');
        }
      }

      return {
        'success': fallidos == 0,
        'message': 'Sincronización completada: $exitosos exitosos, $fallidos fallidos',
        'exitosos': exitosos,
        'fallidos': fallidos,
        'total': pendientes.length,
      };

    } catch (e) {
      print('❌ Error en sincronización: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Obtener estadísticas
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final idOperador = await _authService.getIdOperador();

    if (idOperador == null) {
      return {
        'total': 0,
        'sincronizados': 0,
        'pendientes': 0,
        'fallidos': 0,
      };
    }

    return await _dbHelper.getEstadisticasPorOperador(idOperador);
  }
}