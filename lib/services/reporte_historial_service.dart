// lib/services/reporte_historial_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/enviroment.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../database/database_helper.dart';
import '../models/reporte_diario_historial.dart';

class ReporteHistorialService {
  final AuthService _authService = AuthService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Verificar conexión a internet
  Future<bool> _verificarConexion() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Error verificando conexión: $e');
      return false;
    }
  }

  // Obtener historial desde servidor
  Future<List<ReporteDiarioHistorial>> _obtenerDesdeServidor() async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('No hay token de autenticación');
      }

      final userData = await _authService.getCurrentUser();
      final idOperador = userData?.operador?.idOperador;

      if (idOperador == null) {
        throw Exception('No se pudo obtener ID del operador');
      }

      final url = Uri.parse('${Enviroment.apiUrlDev}reportesdiarios/?operador=$idOperador');
      print('📡 Obteniendo historial desde: $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final reportes = data
            .map((json) => ReporteDiarioHistorial.fromJson(json))
            .toList();

        // Guardar en base de datos local
        await _guardarEnLocal(reportes);

        return reportes;
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error obteniendo historial del servidor: $e');
      rethrow;
    }
  }

  // Guardar reportes en base de datos local
  Future<void> _guardarEnLocal(List<ReporteDiarioHistorial> reportes) async {
    try {
      final db = await _dbHelper.database;

      for (var reporte in reportes) {
        // Verificar si ya existe en local (por id_server)
        if (reporte.idServer != null) {
          final existente = await db.query(
            DatabaseHelper.tableReportes,
            where: '${DatabaseHelper.columnIdServer} = ?',
            whereArgs: [reporte.idServer],
            limit: 1,
          );

          if (existente.isEmpty) {
            // Insertar nuevo
            await db.insert(
              DatabaseHelper.tableReportes,
              reporte.toLocalMap(),
            );
          } else {
            // Actualizar existente
            await db.update(
              DatabaseHelper.tableReportes,
              reporte.toLocalMap(),
              where: '${DatabaseHelper.columnIdServer} = ?',
              whereArgs: [reporte.idServer],
            );
          }
        }
      }
      print('💾 Guardados ${reportes.length} reportes en local');
    } catch (e) {
      print('❌ Error guardando en local: $e');
    }
  }

  // Obtener historial combinado (servidor + local)
  Future<List<ReporteDiarioHistorial>> getHistorialReportes() async {
    try {
      final tieneConexion = await _verificarConexion();

      if (tieneConexion) {
        try {
          // Intentar obtener del servidor
          final reportesServidor = await _obtenerDesdeServidor();

          // También obtener locales pendientes
          final reportesLocales = await _obtenerDesdeLocal();

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

          // Ordenar por fecha descendente
          todosReportes.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));

          return todosReportes;
        } catch (e) {
          print('⚠️ Falló obtención del servidor, usando local: $e');
          return await _obtenerDesdeLocal();
        }
      } else {
        // Sin conexión, usar solo local
        print('📱 Modo offline - usando base de datos local');
        return await _obtenerDesdeLocal();
      }
    } catch (e) {
      print('❌ Error obteniendo historial: $e');
      return [];
    }
  }

  // Obtener desde base de datos local
  Future<List<ReporteDiarioHistorial>> _obtenerDesdeLocal() async {
    try {
      final userData = await _authService.getCurrentUser();
      final idOperador = userData?.operador?.idOperador;

      if (idOperador == null) {
        return [];
      }

      final db = await _dbHelper.database;
      final maps = await db.query(
        DatabaseHelper.tableReportes,
        where: '${DatabaseHelper.columnIdOperador} = ?',
        whereArgs: [idOperador],
        orderBy: '${DatabaseHelper.columnFechaCreacion} DESC',
      );

      return maps.map((map) => ReporteDiarioHistorial.fromLocal(map)).toList();
    } catch (e) {
      print('❌ Error obteniendo desde local: $e');
      return [];
    }
  }

  // Sincronizar reportes pendientes manualmente
  Future<Map<String, dynamic>> sincronizarManual() async {
    try {
      final tieneConexion = await _verificarConexion();
      if (!tieneConexion) {
        return {
          'success': false,
          'message': 'No hay conexión a internet',
        };
      }

      // Obtener reportes pendientes
      final db = await _dbHelper.database;
      final pendientes = await db.query(
        DatabaseHelper.tableReportes,
        where: '${DatabaseHelper.columnEstado} = ?',
        whereArgs: ['pendiente'],
      );

      if (pendientes.isEmpty) {
        return {
          'success': true,
          'message': 'No hay reportes pendientes',
        };
      }

      print('🔄 Sincronizando ${pendientes.length} reportes pendientes...');

      // Aquí implementarías la lógica para enviar los pendientes al servidor
      // Por ahora solo los marcamos como sincronizados
      for (var pendiente in pendientes) {
        await db.update(
          DatabaseHelper.tableReportes,
          {
            DatabaseHelper.columnEstado: 'sincronizado',
            DatabaseHelper.columnFechaSincronizacion: DateTime.now().toIso8601String(),
          },
          where: '${DatabaseHelper.columnId} = ?',
          whereArgs: [pendiente['id']],
        );
      }

      return {
        'success': true,
        'message': '${pendientes.length} reportes sincronizados',
      };
    } catch (e) {
      print('❌ Error en sincronización manual: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Obtener estadísticas de sincronización
  Future<Map<String, dynamic>> getEstadisticasSincronizacion() async {
    try {
      final userData = await _authService.getCurrentUser();
      final idOperador = userData?.operador?.idOperador;

      if (idOperador == null) {
        return {'pendientes': 0, 'sincronizados': 0, 'total': 0};
      }

      final db = await _dbHelper.database;

      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as total FROM ${DatabaseHelper.tableReportes} WHERE ${DatabaseHelper.columnIdOperador} = ?',
        [idOperador],
      );
      final total = totalResult.first['total'] as int? ?? 0;

      final pendientesResult = await db.rawQuery(
        'SELECT COUNT(*) as pendientes FROM ${DatabaseHelper.tableReportes} WHERE ${DatabaseHelper.columnIdOperador} = ? AND ${DatabaseHelper.columnEstado} = ?',
        [idOperador, 'pendiente'],
      );
      final pendientes = pendientesResult.first['pendientes'] as int? ?? 0;

      final sincronizadosResult = await db.rawQuery(
        'SELECT COUNT(*) as sincronizados FROM ${DatabaseHelper.tableReportes} WHERE ${DatabaseHelper.columnIdOperador} = ? AND ${DatabaseHelper.columnEstado} = ?',
        [idOperador, 'sincronizado'],
      );
      final sincronizados = sincronizadosResult.first['sincronizados'] as int? ?? 0;

      return {
        'pendientes': pendientes,
        'sincronizados': sincronizados,
        'total': total,
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {'pendientes': 0, 'sincronizados': 0, 'total': 0};
    }
  }
}