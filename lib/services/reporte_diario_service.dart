// lib/services/reporte_diario_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/enviroment.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../models/reporte_diario_local.dart';
import '../models/reporte_diario_historial.dart';

class ReporteDiarioService {
  final AuthService _authService = AuthService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

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

  // Enviar reporte al servidor
  Future<Map<String, dynamic>> enviarReporteAlServidor(
      ReporteDiarioLocal reporte) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'No hay token de autenticación',
        };
      }

      final url = Uri.parse('${Enviroment.apiUrlDev}reportesdiarios/');
      print('📤 Enviando reporte a: $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(reporte.toApiJson()),
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
  Future<Map<String, dynamic>> guardarReporteLocal(
      ReporteDiarioLocal reporte) async {
    try {
      // Verificar si ya existe un reporte para esta fecha
      final existe = await existeReporteParaFecha(reporte.fechaReporte, reporte.idOperador);
      if (existe) {
        return {
          'success': false,
          'message': 'Ya existe un reporte para esta fecha',
        };
      }

      // Guardar en base de datos
      final id = await _dbHelper.insertReporteDiario(reporte);

      print('💾 Reporte guardado localmente con ID: $id');

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
  Future<Map<String, dynamic>> sincronizarReporte(ReporteDiarioLocal reporte) async {
    try {
      // Verificar conexión
      final tieneConexion = await verificarConexion();

      if (tieneConexion) {
        // Intentar enviar al servidor
        final resultado = await enviarReporteAlServidor(reporte);

        if (resultado['success'] == true) {
          // Si se envió exitosamente, actualizar el reporte local con el ID del servidor
          reporte.idServer = resultado['server_id'];
          reporte.marcarComoSincronizado(resultado['server_id']!, DateTime.now());

          // Guardar actualizado localmente
          if (reporte.id != null) {
            await _dbHelper.updateReporteDiario(reporte);
          } else {
            await _dbHelper.insertReporteDiario(reporte);
          }

          print('✅ Reporte sincronizado exitosamente con el servidor');

          return {
            'success': true,
            'message': 'Reporte enviado y guardado exitosamente',
            'server_id': resultado['server_id'],
            'saved_locally': false,
          };
        } else {
          // Si falló el servidor, guardar localmente como pendiente
          reporte.marcarComoPendiente();
          final resultadoLocal = await guardarReporteLocal(reporte);

          print('⚠️ Falló envío al servidor, guardando localmente');

          return {
            'success': resultadoLocal['success'],
            'message': resultadoLocal['message'],
            'saved_locally': true,
            'local_id': resultadoLocal['local_id'],
          };
        }
      } else {
        // Sin conexión, guardar localmente como pendiente
        reporte.marcarComoPendiente();
        final resultadoLocal = await guardarReporteLocal(reporte);

        print('📱 Sin conexión, guardando reporte localmente');

        return resultadoLocal;
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

  // Sincronizar reportes pendientes
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
          final resultado = await enviarReporteAlServidor(reporte);

          if (resultado['success'] == true) {
            // Marcar como sincronizado
            reporte.marcarComoSincronizado(resultado['server_id']!, DateTime.now());
            await _dbHelper.updateReporteDiario(reporte);

            sincronizadosExitosos++;
            print('✅ Reporte ${reporte.id} sincronizado');
          } else {
            // Marcar como fallido después de varios intentos
            if (reporte.estado == 'pendiente') {
              reporte.marcarComoFallido();
              await _dbHelper.updateReporteDiario(reporte);
            }
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

  // Obtener historial combinado (servidor + local)
  Future<List<ReporteDiarioHistorial>> obtenerHistorial() async {
    try {
      final userData = await _authService.getCurrentUser();
      final idOperador = userData?.operador?.idOperador;

      if (idOperador == null) {
        return [];
      }

      final tieneConexion = await verificarConexion();
      List<ReporteDiarioHistorial> historial = [];

      if (tieneConexion) {
        try {
          // Intentar obtener del servidor
          final reportesServidor = await _obtenerDesdeServidor(idOperador);

          // Obtener locales
          final reportesLocales = await _obtenerDesdeLocal(idOperador);

          // Combinar y eliminar duplicados (preferir servidor)
          final todosReportes = <ReporteDiarioHistorial>[];
          final idsProcesados = <int>{};

          // Agregar primero los del servidor
          for (var reporte in reportesServidor) {
            if (reporte.idServer != null) {
              idsProcesados.add(reporte.idServer!);
              todosReportes.add(reporte);
            }
          }

          // Agregar locales que no estén en servidor
          for (var reporte in reportesLocales) {
            if (reporte.idServer == null || !idsProcesados.contains(reporte.idServer)) {
              todosReportes.add(reporte);
            }
          }

          historial = todosReportes;
        } catch (e) {
          print('⚠️ Falló obtención del servidor, usando local: $e');
          historial = await _obtenerDesdeLocal(idOperador);
        }
      } else {
        // Sin conexión, usar solo local
        print('📱 Modo offline - usando base de datos local');
        historial = await _obtenerDesdeLocal(idOperador);
      }

      // Ordenar por fecha descendente
      historial.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));

      return historial;
    } catch (e) {
      print('❌ Error obteniendo historial: $e');
      return [];
    }
  }

  // Obtener desde servidor
  Future<List<ReporteDiarioHistorial>> _obtenerDesdeServidor(int idOperador) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) {
        return [];
      }

      final url = Uri.parse('${Enviroment.apiUrlDev}reportesdiarios/');
      print('📡 Obteniendo historial desde servidor: $url');

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
        final reportesOperador = data
            .where((json) => json['operador'] == idOperador)
            .map((json) => ReporteDiarioHistorial.fromJson(json))
            .toList();

        print('✅ Obtenidos ${reportesOperador.length} reportes del servidor');

        // Guardar en base de datos local para futuras consultas offline
        await _guardarReportesServidorEnLocal(reportesOperador);

        return reportesOperador;
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error obteniendo del servidor: $e');
      rethrow;
    }
  }

  // Guardar reportes del servidor en local
  Future<void> _guardarReportesServidorEnLocal(List<ReporteDiarioHistorial> reportes) async {
    try {
      for (var reporte in reportes) {
        if (reporte.idServer != null) {
          // Verificar si ya existe usando un método simplificado
          final existente = await _dbHelper.getReporteByFecha(reporte.fechaReporte, reporte.idOperador);

          if (existente == null) {
            // Convertir a ReporteDiarioLocal y guardar
            final reporteLocal = ReporteDiarioLocal(
              id: null,
              idServer: reporte.idServer,
              contadorInicialR: reporte.contadorInicialR,
              contadorFinalR: reporte.contadorFinalR,
              saltosenR: reporte.saltosenR,
              contadorR: reporte.contadorR,
              contadorInicialC: reporte.contadorInicialC,
              contadorFinalC: reporte.contadorFinalC,
              saltosenC: reporte.saltosenC,
              contadorC: reporte.contadorC,
              fechaReporte: reporte.fechaReporte,
              observaciones: reporte.observaciones,
              incidencias: reporte.incidencias,
              estado: 'sincronizado',
              idOperador: reporte.idOperador,
              estacionId: reporte.idEstacion,
              fechaCreacion: reporte.fechaCreacion,
              fechaSincronizacion: reporte.fechaSincronizacion,
              observacionC: reporte.observacionC,
              observacionR: reporte.observacionR,
              centroEmpadronamiento: reporte.centroEmpadronamiento,
            );

            await _dbHelper.insertReporteDiario(reporteLocal);
          }
        }
      }
      print('💾 Reportes del servidor guardados localmente');
    } catch (e) {
      print('❌ Error guardando reportes del servidor: $e');
    }
  }

  // Obtener desde local
  Future<List<ReporteDiarioHistorial>> _obtenerDesdeLocal(int idOperador) async {
    try {
      final reportesLocales = await _dbHelper.getReportesPorOperador(idOperador);

      return reportesLocales.map((reporteLocal) {
        return ReporteDiarioHistorial(
          id: reporteLocal.id,
          idServer: reporteLocal.idServer,
          fechaReporte: reporteLocal.fechaReporte,
          contadorInicialC: reporteLocal.contadorInicialC,
          contadorFinalC: reporteLocal.contadorFinalC,
          contadorC: reporteLocal.contadorC,
          contadorInicialR: reporteLocal.contadorInicialR,
          contadorFinalR: reporteLocal.contadorFinalR,
          contadorR: reporteLocal.contadorR,
          incidencias: reporteLocal.incidencias,
          observaciones: reporteLocal.observaciones,
          fechaCreacion: reporteLocal.fechaCreacion,
          fechaSincronizacion: reporteLocal.fechaSincronizacion,
          estadoSincronizacion: _parseEstadoSincronizacion(reporteLocal.estado),
          idOperador: reporteLocal.idOperador,
          idEstacion: reporteLocal.estacionId ?? 0,
          centroEmpadronamiento: reporteLocal.centroEmpadronamiento,
          observacionC: reporteLocal.observacionC,
          observacionR: reporteLocal.observacionR,
          saltosenC: reporteLocal.saltosenC,
          saltosenR: reporteLocal.saltosenR,
        );
      }).toList();
    } catch (e) {
      print('❌ Error obteniendo desde local: $e');
      return [];
    }
  }

  EstadoSincronizacion _parseEstadoSincronizacion(String estado) {
    switch (estado.toLowerCase()) {
      case 'sincronizado':
        return EstadoSincronizacion.sincronizado;
      case 'pendiente':
        return EstadoSincronizacion.pendiente;
      case 'fallido':
        return EstadoSincronizacion.fallido;
      default:
        return EstadoSincronizacion.pendiente;
    }
  }

  // Obtener estadísticas
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final userData = await _authService.getCurrentUser();
      final idOperador = userData?.operador?.idOperador;

      if (idOperador == null) {
        return {'pendientes': 0, 'sincronizados': 0, 'total': 0};
      }

      // Usar los métodos correctos del DatabaseHelper
      final totalResult = await _dbHelper.getTotalReportesPorOperador(idOperador);
      final pendientesResult = await _dbHelper.getReportesPendientesPorOperador(idOperador);
      final sincronizadosResult = await _dbHelper.getReportesSincronizadosPorOperador(idOperador);

      return {
        'pendientes': pendientesResult.length,
        'sincronizados': sincronizadosResult.length,
        'total': totalResult.length,
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {'pendientes': 0, 'sincronizados': 0, 'total': 0};
    }
  }

  // Verificar si ya existe un reporte para la fecha
  Future<bool> existeReporteParaFecha(String fecha, int idOperador) async {
    try {
      final reporte = await _dbHelper.getReporteByFecha(fecha, idOperador);
      return reporte != null;
    } catch (e) {
      print('❌ Error verificando existencia de reporte: $e');
      return false;
    }
  }

  // Crear ReporteDiarioLocal desde datos del formulario
  Future<ReporteDiarioLocal> crearReporteDesdeFormulario({
    required String fechaReporte,
    required String contadorInicialC,
    required String contadorFinalC,
    required int registroC,
    required String contadorInicialR,
    required String contadorFinalR,
    required int registroR,
    required String? incidencias,
    required String? observaciones,
    required int? centroEmpadronamiento,
    required String? observacionC,
    required String? observacionR,
    required int saltosenC,
    required int saltosenR,
  }) async {
    final userData = await _authService.getCurrentUser();
    final idOperador = userData?.operador?.idOperador;
    final idEstacion = userData?.operador?.idEstacion;
    final nroEstacion = userData?.operador?.nroEstacion?.toString();

    if (idOperador == null) {
      throw Exception('No se pudo obtener datos del operador');
    }

    return ReporteDiarioLocal(
      id: null,
      idServer: null,
      contadorInicialR: contadorInicialR,
      contadorFinalR: contadorFinalR,
      saltosenR: saltosenR,
      contadorR: registroR.toString(),
      contadorInicialC: contadorInicialC,
      contadorFinalC: contadorFinalC,
      saltosenC: saltosenC,
      contadorC: registroC.toString(),
      fechaReporte: fechaReporte,
      observaciones: observaciones,
      incidencias: incidencias,
      estado: 'pendiente',
      idOperador: idOperador,
      estacionId: idEstacion,
      nroEstacion: nroEstacion,
      fechaCreacion: DateTime.now(),
      observacionC: observacionC,
      observacionR: observacionR,
      centroEmpadronamiento: centroEmpadronamiento,
    );
  }

  // Método para convertir Map a ReporteDiarioLocal (para compatibilidad)
  ReporteDiarioLocal _mapToReporteDiarioLocal(Map<String, dynamic> map) {
    return ReporteDiarioLocal(
      id: map['id'] as int?,
      idServer: map['id_server'] as int?,
      contadorInicialR: map['contador_inicial_r'] as String? ?? '',
      contadorFinalR: map['contador_final_r'] as String? ?? '',
      saltosenR: map['saltosen_r'] as int? ?? 0,
      contadorR: map['contador_r'] as String? ?? '0',
      contadorInicialC: map['contador_inicial_c'] as String? ?? '',
      contadorFinalC: map['contador_final_c'] as String? ?? '',
      saltosenC: map['saltosen_c'] as int? ?? 0,
      contadorC: map['contador_c'] as String? ?? '0',
      fechaReporte: map['fecha_reporte'] as String? ?? '',
      observaciones: map['observaciones'] as String?,
      incidencias: map['incidencias'] as String?,
      estado: map['estado'] as String? ?? 'pendiente',
      idOperador: map['id_operador'] as int? ?? 0,
      estacionId: map['estacion_id'] as int?,
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'] as String)
          : DateTime.now(),
      fechaSincronizacion: map['fecha_sincronizacion'] != null
          ? DateTime.parse(map['fecha_sincronizacion'] as String)
          : null,
      observacionC: map['observacion_c'] as String?,
      observacionR: map['observacion_r'] as String?,
      centroEmpadronamiento: map['centro_empadronamiento'] as int?,
    );
  }
}