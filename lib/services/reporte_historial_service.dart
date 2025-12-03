// lib/services/reporte_historial_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reporte_diario_historial.dart';
import '../config/enviroment.dart';
import 'auth_service.dart';

class ReporteHistorialService {
  final AuthService _authService = AuthService();

  Future<List<ReporteDiarioHistorial>> getHistorialReportes() async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final url = '${Enviroment.apiUrlDev}reportesdiarios/';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        return data.map((item) {
          return ReporteDiarioHistorial.fromJson(item);
        }).toList();
      } else {
        throw Exception('Error al obtener historial: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en getHistorialReportes: $e');
      rethrow;
    }
  }

  // Método alternativo para obtener desde base de datos local si tienes
  Future<List<ReporteDiarioHistorial>> getHistorialLocal() async {
    try {
      // Aquí puedes obtener datos de SQLite si los almacenas localmente
      return [];
    } catch (e) {
      print('❌ Error obteniendo historial local: $e');
      return [];
    }
  }
}