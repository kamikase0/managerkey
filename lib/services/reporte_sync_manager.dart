// lib/services/reporte_sync_manager.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/enviroment.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../models/reporte_diario_local.dart';

class ReporteSyncManager {
  final AuthService _authService = AuthService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Verificar conexión a internet
  Future<bool> verificarConexion() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('❌ Error verificando conexión: $e');
      return false;
    }
  }

  /// Guardar reporte (intenta servidor primero, sino guarda local)
  Future<Map<String, dynamic>> guardarReporte(ReporteDiarioLocal reporte) async {
    try {
      final tieneConexion = await verificarConexion();

      if (tieneConexion) {
        // Intentar enviar al servidor
        print('🌐 Conexión disponible - Enviando al servidor...');
        final resultado = await _enviarAlServidor(reporte);

        if (resultado['success'] == true) {
          // ✅ Enviado exitosamente al servidor
          print('✅ Reporte enviado al servidor con ID: ${resultado['server_id']}');

          // Marcar como sincronizado y guardar localmente
          reporte.marcarComoSincronizado(
            resultado['server_id']!,
            DateTime.now(),
          );

          // Guardar en BD local
          await _dbHelper.insertReporte(reporte);
          print('💾 Reporte guardado localmente con estado: sincronizado');

          return {
            'success': true,
            'sincronizado': true,
            'message': 'Reporte enviado y guardado exitosamente',
            'server_id': resultado['server_id'],
          };
        } else {
          // ❌ Falló el envío al servidor - guardar como pendiente
          print('⚠️ Falló envío al servidor: ${resultado['message']}');
          return await _guardarComoPendiente(reporte);
        }
      } else {
        // 📱 Sin conexión - guardar como pendiente
        print('📱 Sin conexión - Guardando como pendiente');
        return await _guardarComoPendiente(reporte);
      }
    } catch (e) {
      print('❌ Error en guardarReporte: $e');
      return {
        'success': false,
        'sincronizado': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// Enviar reporte al servidor
  Future<Map<String, dynamic>> _enviarAlServidor(ReporteDiarioLocal reporte) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'No hay token de autenticación',
        };
      }

      final url = Uri.parse('${Enviroment.apiUrlDev}reportesdiarios/');
      final body = jsonEncode(reporte.toApiJson());

      print('🔔 Enviando POST → $url');
      print('🧾 Body: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      print('✅ Response status final: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Reporte enviado exitosamente',
          'server_id': responseData['id'],
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ Error enviando al servidor: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// Guardar reporte como pendiente en BD local
  Future<Map<String, dynamic>> _guardarComoPendiente(ReporteDiarioLocal reporte) async {
    try {
      reporte.marcarComoPendiente();
      final id = await _dbHelper.insertReporte(reporte);

      print('💾 Reporte guardado localmente como PENDIENTE con ID: $id');

      return {
        'success': true,
        'sincronizado': false,
        'message': 'Reporte guardado localmente. Se sincronizará cuando haya conexión.',
        'local_id': id,
      };
    } catch (e) {
      print('❌ Error guardando localmente: $e');
      return {
        'success': false,
        'sincronizado': false,
        'message': 'Error guardando localmente: ${e.toString()}',
      };
    }
  }

  /// Sincronizar reportes pendientes
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

      final pendientes = await _dbHelper.getReportesPendientes();
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

      for (var reporte in pendientes) {
        try {
          final resultado = await _enviarAlServidor(reporte);

          if (resultado['success'] == true) {
            reporte.marcarComoSincronizado(
              resultado['server_id']!,
              DateTime.now(),
            );
            await _dbHelper.updateReporte(reporte);
            sincronizadosExitosos++;
            print('✅ Reporte ${reporte.id} sincronizado');
          } else {
            sincronizadosFallidos++;
            print('❌ Falló sincronización del reporte ${reporte.id}');
          }
        } catch (e) {
          sincronizadosFallidos++;
          print('❌ Error sincronizando reporte: $e');
        }
      }

      return {
        'success': sincronizadosFallidos == 0,
        'message': sincronizadosFallidos == 0
            ? '✅ Todos los reportes sincronizados'
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
      };
    }
  }

  // En reporte_sync_manager.dart

  /// Descargar reportes desde la API y guardarlos localmente
  Future<void> descargarYGuardarReportesDesdeApi() async {
    try {
      final userData = await _authService.getCurrentUser();
      final idOperador = userData?.operador?.idOperador;

      if (idOperador == null) {
        throw Exception('No se pudo obtener el ID del operador');
      }

      final token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay token de autenticación');
      }

      final url = Uri.parse('${Enviroment.apiUrlDev}reportesdiarios/');
      print('📡 Descargando reportes desde: $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        // Filtrar solo los reportes del operador actual
        final reportesOperador = data.where((json) => json['operador'] == idOperador).toList();

        print('✅ Descargados ${reportesOperador.length} reportes del servidor');

        // Guardar cada reporte en la BD local
        for (var reporteJson in reportesOperador) {
          final reporte = ReporteDiarioLocal.fromApiMap(reporteJson);
          await _dbHelper.insertarOIgnorarReporte(reporte);
        }

        print('💾 Reportes guardados en BD local');
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error descargando reportes: $e');
      rethrow;
    }
  }

  /// Obtener todos los reportes del operador desde BD local
  Future<List<ReporteDiarioLocal>> obtenerReportes() async {
    try {
      final userData = await _authService.getCurrentUser();
      final idOperador = userData?.operador?.idOperador;

      if (idOperador == null) {
        return [];
      }

      return await _dbHelper.getReportesPorOperador(idOperador);
    } catch (e) {
      print('❌ Error obteniendo reportes locales: $e');
      return [];
    }
  }

  /// Obtener estadísticas de reportes
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final userData = await _authService.getCurrentUser();
      final idOperador = userData?.operador?.idOperador;

      if (idOperador == null) {
        return {'total': 0, 'sincronizados': 0, 'pendientes': 0};
      }

      return await _dbHelper.getEstadisticasPorOperador(idOperador);
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {'total': 0, 'sincronizados': 0, 'pendientes': 0};
    }
  }

}