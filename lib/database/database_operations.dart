import 'package:manager_key/database/database_helper.dart';
import 'package:manager_key/models/reporte_diario_local.dart';

class DatabaseOperations {
  // CORREGIDO: Usar el factory constructor en lugar de .instance
  static final DatabaseHelper _dbHelper = DatabaseHelper(); // <-- CORRECCIÓN AQUÍ

  // O también puedes usar el getter si lo agregaste:
  // static final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Método para inicializar la base de datos
  static Future<void> initDatabase() async {
    try {
      // Solo obtener la instancia de la base de datos para forzar inicialización
      await _dbHelper.database;
      print('✅ Base de datos inicializada correctamente');
    } catch (e) {
      print('❌ Error inicializando base de datos: $e');
      rethrow;
    }
  }

  // Insertar reporte
  static Future<int> insertReporte(ReporteDiarioLocal reporte) async {
    try {
      // Validar que id_operador esté presente
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


// En DatabaseOperations.dart - CORREGIR EL MÉTODO:
  static Future<List<ReporteDiarioLocal>> getReportesPorOperador(int idOperador) async {
    try {
      final reportes = await _dbHelper.getReportesPorOperador(idOperador);
      print('✅ Obtenidos ${reportes.length} reportes para operador $idOperador');
      return reportes; // Esto ya debería ser List<ReporteDiarioLocal>
    } catch (e) {
      print('❌ Error obteniendo reportes: $e');
      return [];
    }
  }
  // Obtener reportes pendientes
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

  // Actualizar reporte
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

  // Marcar como sincronizado
  static Future<bool> marcarComoSincronizado(int id, int serverId) async {
    try {
      final rows = await _dbHelper.marcarComoSincronizado(id, serverId);
      print('✅ Reporte $id marcado como sincronizado con serverId: $serverId');
      return rows > 0;
    } catch (e) {
      print('❌ Error marcando como sincronizado: $e');
      return false;
    }
  }

  // Obtener estadísticas
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
        'porcentajeSincronizado': '0.0',
      };
    }
  }

  // Verificar existencia de reporte
  static Future<bool> existeReporte(String fecha, int idOperador) async {
    try {
      final existe = await _dbHelper.existeReporteParaFecha(fecha, idOperador);
      print('✅ Verificación de reporte: $existe para $fecha');
      return existe;
    } catch (e) {
      print('❌ Error verificando reporte: $e');
      return false;
    }
  }

  // Método para limpiar base de datos (solo desarrollo)
  static Future<void> clearDatabase() async {
    try {
      await _dbHelper.clearDatabase();
      print('✅ Base de datos limpiada');
    } catch (e) {
      print('❌ Error limpiando base de datos: $e');
    }
  }

  // Cerrar conexión
  static Future<void> closeDatabase() async {
    try {
      await _dbHelper.close();
      print('✅ Conexión a base de datos cerrada');
    } catch (e) {
      print('❌ Error cerrando base de datos: $e');
    }
  }
}