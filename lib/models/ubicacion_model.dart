// models/ubicacion_model.dart
import 'dart:convert';

class UbicacionModel {
  final int? id;
  final int userId;
  final double latitud;
  final double longitud;
  final DateTime timestamp;
  final String tipoUsuario;
  final int? sincronizado;
  final String? fechaSincronizacion;

  UbicacionModel({
    this.id,
    required this.userId,
    required this.latitud,
    required this.longitud,
    required this.timestamp,
    required this.tipoUsuario,
    this.sincronizado = 0,
    this.fechaSincronizacion,
  });

  // Factory method para crear desde Position
  factory UbicacionModel.fromPosition({
    required int userId,
    required double latitud,
    required double longitud,
    required String tipoUsuario,
    required DateTime timestamp,
  }) {
    return UbicacionModel(
      userId: userId,
      latitud: latitud,
      longitud: longitud,
      timestamp: timestamp,
      tipoUsuario: tipoUsuario,
      sincronizado: 0,
    );
  }

  // Convertir a Map para DatabaseService
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'latitud': latitud,
      'longitud': longitud,
      'timestamp': timestamp.toIso8601String(),
      'tipo_usuario': tipoUsuario,
      'sincronizado': sincronizado ?? 0,
      'fecha_sincronizacion': fechaSincronizacion,
    };
  }

  // Para API (campos camelCase)
  Map<String, dynamic> toApiMap() {
    return {
      'user_id': userId,
      'latitud': latitud,
      'longitud': longitud,
      'timestamp': timestamp.toIso8601String(),
      'tipo_usuario': tipoUsuario,
    };
  }

  String toApiJson() => json.encode(toApiMap());

  // Método de log para debug
  void logUbicacion() {
    print('📍 Ubicación Model Debug:');
    print('  - ID: $id');
    print('  - User ID: $userId');
    print('  - Latitud: $latitud');
    print('  - Longitud: $longitud');
    print('  - Timestamp: $timestamp');
    print('  - Tipo Usuario: $tipoUsuario');
    print('  - Sincronizado: $sincronizado');
  }
}