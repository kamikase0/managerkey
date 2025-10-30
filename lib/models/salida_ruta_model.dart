class SalidaRuta {
  final int? id;
  final DateTime fechaHora;
  final double latitud;
  final double longitud;
  final String descripcion;
  final String observaciones;
  final bool enviado;
  final DateTime? fechaEnvio;

  SalidaRuta({
    this.id,
    required this.fechaHora,
    required this.latitud,
    required this.longitud,
    required this.descripcion,
    required this.observaciones,
    this.enviado = false,
    this.fechaEnvio,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha_hora': fechaHora.toIso8601String(),
      'latitud': latitud,
      'longitud': longitud,
      'descripcion': descripcion,
      'observaciones': observaciones,
      'enviado': enviado ? 1 : 0,
      'fecha_envio': fechaEnvio?.toIso8601String(),
    };
  }

  factory SalidaRuta.fromMap(Map<String, dynamic> map) {
    return SalidaRuta(
      id: map['id'],
      fechaHora: DateTime.parse(map['fecha_hora']),
      latitud: map['latitud'],
      longitud: map['longitud'],
      descripcion: map['descripcion'],
      observaciones: map['observaciones'],
      enviado: map['enviado'] == 1,
      fechaEnvio: map['fecha_envio'] != null ? DateTime.parse(map['fecha_envio']) : null,
    );
  }
}