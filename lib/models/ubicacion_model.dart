// models/ubicacion_model.dart - ACTUALIZADO
class UbicacionModel {
  final int? id;
  final int userId;
  final double latitud;
  final double longitud;
  final DateTime timestamp; // HORA REAL de captura
  final bool sincronizado;
  final String tipoUsuario;

  UbicacionModel({
    this.id,
    required this.userId,
    required this.latitud,
    required this.longitud,
    required this.timestamp, // ✅ Este debe ser la hora REAL de captura
    this.sincronizado = false,
    required this.tipoUsuario,
  });

  // NUEVO: Factory method para crear con hora exacta de captura
  factory UbicacionModel.fromPosition({
    required int userId,
    required double latitud,
    required double longitud,
    required String tipoUsuario,
    DateTime? timestamp, // Opcional, si no se provee usa DateTime.now()
  }) {
    return UbicacionModel(
      userId: userId,
      latitud: latitud,
      longitud: longitud,
      timestamp: timestamp ?? DateTime.now(), // Hora exacta de captura
      tipoUsuario: tipoUsuario,
      sincronizado: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'latitud': latitud,
      'longitud': longitud,
      'timestamp': timestamp.toIso8601String(), // ✅ Hora real
      'sincronizado': sincronizado ? 1 : 0,
      'tipoUsuario': tipoUsuario,
    };
  }

  Map<String, dynamic> toApiJson() {
    // MODIFICADO: Usar SOLO el timestamp de captura
    return {
      'operador': userId,
      'latitud': latitud.toString(),
      'longitud': longitud.toString(),
      'fecha': _formatearFechaHora(timestamp), // ✅ SIEMPRE usa timestamp de captura
      'tipo_usuario': tipoUsuario,
    };
  }

  // MEJORADO: Formatear fecha en formato ISO 8601 que es más estándar
  String _formatearFechaHora(DateTime fecha) {
    // Formato ISO 8601: "2024-01-15T14:30:25Z" (UTC)
    return fecha.toUtc().toIso8601String();
  }

  factory UbicacionModel.fromJson(Map<String, dynamic> json) {
    return UbicacionModel(
      id: json['id'],
      userId: json['userId'] is int ? json['userId'] : int.tryParse(json['userId'].toString()) ?? 0,
      latitud: json['latitud']?.toDouble() ?? 0.0,
      longitud: json['longitud']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']), // ✅ Se carga la hora real
      sincronizado: json['sincronizado'] == 1,
      tipoUsuario: json['tipoUsuario'],
    );
  }

  // NUEVO: Método para debugging
  void logUbicacion() {
    print('📍 UBICACIÓN - Hora Captura: $timestamp, Hora Actual: ${DateTime.now()}');
    print('📍 Diferencia: ${DateTime.now().difference(timestamp).inSeconds} segundos');
  }
}