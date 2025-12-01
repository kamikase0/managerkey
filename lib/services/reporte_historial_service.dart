// lib/services/reporte_historial_service.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/reporte_diario_historial.dart';

import 'api_service.dart';
import 'auth_service.dart';
import 'database_service.dart'; // Tu servicio de base de datos local

class ReporteHistorialService {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  /// Método principal para obtener el historial de reportes.
  /// Decide si obtenerlos de la API (online) o de la BD local (offline).
  Future<List<ReporteDiarioHistorial>> getHistorialReportes() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    final tieneInternet = connectivityResult != ConnectivityResult.none;

    if (tieneInternet) {
      // CASO ONLINE: Obtener de la API
      print('🌐 Modo Online: Obteniendo historial desde la API.');
      return _getReportesFromApi();
    } else {
      // CASO OFFLINE: Obtener de la base de datos local
      print('💾 Modo Offline: Obteniendo reportes locales no sincronizados.');
      return _getReportesFromDb();
    }
  }

  /// Obtiene los reportes del servidor a través de la API.
  Future<List<ReporteDiarioHistorial>> _getReportesFromApi() async {
    try {
      final user = await _authService.getCurrentUser();
      final accessToken = await _authService.getAccessToken();

      if (user == null || accessToken == null) {
        throw Exception('Usuario no autenticado o token no disponible.');
      }

      final apiService = ApiService(accessToken: accessToken);
      // Asume que tienes un endpoint en tu ApiService para esto
      final List<dynamic> jsonData = await apiService.getReportesDiariosOperador(user.operador!.idOperador);

      return jsonData.map((json) => ReporteDiarioHistorial.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error al obtener reportes de la API: $e');
      throw Exception('No se pudo cargar el historial desde el servidor.');
    }
  }

  /// Obtiene los reportes no sincronizados de la base de datos SQLite.
  Future<List<ReporteDiarioHistorial>> _getReportesFromDb() async {
    try {
      // Asume que tienes un método en tu DatabaseService para esto
      final List<Map<String, dynamic>> maps = await _databaseService.getReportesDiariosNoSincronizados();

      return maps.map((map) => ReporteDiarioHistorial.fromDb(map)).toList();
    } catch (e) {
      print('❌ Error al obtener reportes de la BD local: $e');
      throw Exception('No se pudo cargar el historial local.');
    }
  }
}
