// services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/salida_ruta_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = 'https://tu-api.com/api'; // Cambiar por tu URL real

  Future<bool> enviarSalidaRuta(SalidaRuta salida) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/salidas-ruta'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'fecha_hora': salida.fechaHora.toIso8601String(),
          'latitud': salida.latitud,
          'longitud': salida.longitud,
          'descripcion': salida.descripcion,
          'observaciones': salida.observaciones,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error enviando a API: $e');
      return false;
    }
  }
}