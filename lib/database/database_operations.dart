// lib/database/database_operations.dart
import 'package:manager_key/database/database_helper.dart';
import 'package:manager_key/models/reporte_diario_local.dart';

class DatabaseOperations {
  static final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Inicializar la base de datos
  static Future<void> initDatabase() async {
    try {
      await _dbHelper.database;
      print('✅ Base de datos inicializada correctamente');
    } catch (e) {
      print('❌ Error inicializando base de datos: $e');
      rethrow;
    }
  }

  /// Insertar reporte
  static Future<int> insertReporte(ReporteDiarioLocal reporte) async {
    try {
      if (reporte.idOperador == 0) {
        throw Exception('id_operador es requerido para guardar el reporte');
      }

      final id = await _dbHelper.insertReporte(reporte);
      print('✅ Reporte insertado con ID: $id');
      return id;
    } catch (e) {
      print('❌ Error insertando reporte: $e');
      rethrow;
    }
  }

  /// Obtener reportes por operador
  static Future<List<ReporteDiarioLocal>> getReportesPorOperador(int idOperador) async {
    try {
      final reportes = await _dbHelper.getReportesPorOperador(idOperador);
      print('✅ Obtenidos ${reportes.length} reportes para operador $idOperador');
      return reportes;
    } catch (e) {
      print('❌ Error obteniendo reportes: $e');
      return [];
    }
  }

  /// Obtener reportes pendientes
  static Future<List<ReporteDiarioLocal>> getReportesPendientes() async {
    try {
      final reportes = await _dbHelper.getReportesPendientes();
      print('✅ Obtenidos ${reportes.length} reportes pendientes');
      return reportes;
    } catch (e) {
      print('❌ Error obteniendo reportes pendientes: $e');
      return [];
    }
  }

  /// Actualizar reporte
  static Future<bool> updateReporte(ReporteDiarioLocal reporte) async {
    try {
      final rows = await _dbHelper.updateReporte(reporte);
      print('✅ Reporte actualizado, filas afectadas: $rows');
      return rows > 0;
    } catch (e) {
      print('❌ Error actualizando reporte: $e');
      return false;
    }
  }

  /// ✅ CORREGIDO: Marcar como sincronizado (usando updateReporte)
  static Future<bool> marcarComoSincronizado(int id, int serverId) async {
    try {
      // Primero obtener el reporte por operador (necesitas saber el operador)
      // Como no tenemos el método directo, usamos updateReporte con el objeto modificado
      // Este método ahora requiere el objeto completo, no solo IDs

      print('⚠️ marcarComoSincronizado requiere el objeto completo. Usa updateReporte directamente.');
      return false;
    } catch (e) {
      print('❌ Error marcando como sincronizado: $e');
      return false;
    }
  }

  /// Obtener estadísticas
  static Future<Map<String, dynamic>> getEstadisticas(int idOperador) async {
    try {
      final stats = await _dbHelper.getEstadisticasPorOperador(idOperador);
      print('✅ Estadísticas obtenidas para operador $idOperador');
      return stats;
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {
        'total': 0,
        'sincronizados': 0,
        'pendientes': 0,
        'fallidos': 0,
      };
    }
  }

  /// ✅ CORREGIDO: Verificar existencia de reporte
  static Future<bool> existeReporte(String fecha, int idOperador) async {
    try {
      // Usamos el método que existe en DatabaseHelper
      final reportes = await _dbHelper.getReportesPorOperador(idOperador);
      final existe = reportes.any((r) => r.fechaReporte == fecha);
      print('✅ Verificación de reporte: $existe para $fecha');
      return existe;
    } catch (e) {
      print('❌ Error verificando reporte: $e');
      return false;
    }
  }

/// ✅ REMOVIDO: clearDatabase (método de desarrollo, no necesario en producción)

/// ✅ REMOVIDO: closeDatabase (SQLite maneja esto automáticamente)
}